; ---------------------------------------------------------------------------------
; Written by: Thijmen Voskuilen
;
; This program:
;  - Opens a file to read lines from (first argument), otherwise stdin.
;  - Opens a file to write output to (second argument), otherwise stdout.
;  - Reads lines from the input file.
;  - Stores each line in a global hash set, in order to keep track of lines previously found.
;  - Only prints a line from the input file if this is the first time it is found.
; ---------------------------------------------------------------------------------

%include "src/os_consts.mac"
%include "src/config.mac"
%include "src/errors.asm"
%include "src/hash_set.asm"
%include "src/memory.asm"

global _start
section .text

; Try to open the file with the given filename using the given flags,
; exit with an error message if something goes wrong.
;
; Parameters:
;  - Filename (char *): rdi
;  - Flags (int): rsi
;
; Return:
;  - The file descriptor (rax) (on success)
try_open_file:
    ; Run open syscall. Its arguments are:
    ;  - pathname (rdi) (from function args)
    ;  - flags (rsi) (from function args)
    ;  - mode (rdx)
    mov rax, SYS_OPEN
    mov rdx, MODE_CREATE
    syscall

    ; Check return value
    cmp rax, 0
    jg .ok

.err:
    ; An error occured. Print the error and exit.
    ; Register layout:
    ;  - rax: syscall return ret
    ;  - rdi: filename
    ;  - rsi: errno

    ; errno = -ret
    mov rsi, rax ; errno = ret
    neg rsi ; errno = -errno

    call perror

    ; Exit
    mov rax, SYS_EXIT
    mov rdi, EXIT_ERR
    syscall

.ok:
    ; File opened with success. Return.
    ret

; The mainloop of the program, reading lines from the input file, checking with
; the hashmap, and writing to the output file.
;
; Parameters:
;  - Input FD (rdi)
;  - Output FD (rsi)
;
; Return:
;  - None
mainloop:
    ; Register usage:
    ;  - r12: String end ptr
    ;  - r13: newline search index ptr
    ;  - r14: input fd
    ;  - r15: output fd
    enter read_bufsize, 0 ; Create new stack frame
    ; Put file descriptors in a safe place.
    ; r14 and r15 are supposed to be callee-saved, but they aren't used in _start and
    ; because they aren't used anywhere else, I figured it wasn't necessary.
    mov r14, rdi ; input fd
    mov r15, rsi ; output fd

    mov r13, rsp ; The begin of the buffer (where we begin searching for newlines) is the end of the stack frame.
    mov r12, r13 ; At the start, the string will be empty.

.find_newline:
    cmp r13, rbp ; If we get to the stack base, we need additional memory.
    jz .more_memory
    cmp r13, r12 ; If we reach the end of the string, read more from stdin.
    jz .more_data

    mov al, byte [r13] ; Load current char to al.
    cmp al, 10 ; If it is a newline, do hash set and print stuff.
    jz .newline_found

    inc r13
    jmp .find_newline

.more_memory:
    ; Allocate more memory on the stack to write to.
    mov rdx, rbp ; Store current stack size as dsize for strncpy
    sub rdx, rsp
    mov rsi, rsp ; Set old stack top as source for strncpy.
    sub rsp, read_bufsize ; Allocate additional memory on stack.
    mov rdi, rsp ; Set new stack top as dst for strncpy.
    call strncpy ; Copy text to new location.
    sub r12, read_bufsize ; string has moved, so update string end.
    sub r13, read_bufsize ; string has moved, so also update newline search index ptr.
    jmp .find_newline

.more_data:
    ; Read additional characters from the input file.
    mov rax, SYS_READ ; We're going to make a read system call.
    mov rdx, rbp ; Calculate free room in buffer and store in rdx for read syscall.
    sub rdx, r12 ;    .. This is because we want to try to fill the whole buffer if possible.
    mov rsi, r12 ; Tell the syscall to continue reading from current string end.
    mov rdi, r14 ; Read from the given file.
    syscall
    add r12, rax ; Update string end.

    ; Return if EOF was encountered.
    test rax, rax
    jz .end

    jmp .find_newline

.newline_found:
    mov byte [r13], 0 ; tokenize by replacing the newline with a null character.

    ; Insert into hash set
    mov rdi, rsp ; Set string to insert from.
    call hs_insert ; Insert into hash set.
    
    ; If this is the first time we see this line, printm it.
    test rax, rax
    jz .print_new_string

    jmp .cleanup_last_string
    
.print_new_string:
    mov byte [r13], 10 ; Make the last character a newline again, because we want to include the newline in our output.
    mov rax, SYS_WRITE ; We're going to make a write system call.
    mov rdi, r15 ; Set the output FD
    mov rsi, rsp ; Buffer start is stack top
    mov rdx, r13 ; len = end - start
    sub rdx, rsp
    inc rdx ; Also include the newline.
    syscall

.cleanup_last_string:
    ; Update buffer & stack frame to not include the already-handled line.
    inc r13 ; Skip the newline character.
    mov rsp, r13 ; Move stack top to after the already-handled line.
    jmp .find_newline

.end:
    leave
    ret

; Print usage info and exit.
usage:
    ; Print usage
    mov rax, SYS_WRITE
    mov rdi, STDOUT
    mov rsi, help_strs.message
    mov rdx, help_strs.end - help_strs.message
    syscall

    ; Exit
    mov rax, SYS_EXIT
    mov rdi, EXIT_OK
    syscall


_start:
    ; Register usage:
    ;  - rdi: argv[i]
    ;  - r8: input fd
    ;  - r9: output fd
    ;  - r10: argc

    ; = Initialize the heap
    call heap_initialize

    ; = Setup defaults and get argc.
    mov r8, STDIN ; read from stdin unless otherwise specified
    mov r9, STDOUT ; write to stdout unless otherwise specified
    pop r10 ; argc
    pop rdi ; ignore argv[0] (program name)

    ; = load input file if given
    cmp r10, 2 ; skip if this parameter isn't set.
    jl .files_set

    ; Check if this argument is --help 
    mov rdi, qword [rsp] ; get argv[1]
    push r8
    push r9
    mov rsi, help_strs.cmd
    call streq
    test rax, rax
    jnz usage
    pop r8
    pop r9

    pop rdi ; get argv[1]
    mov rsi, FLAGS_READ
    call try_open_file
    mov r8, rax

    ; = load output file if given
    cmp r10, 3 ; skip if this parameter isn't set.
    jl .files_set
    pop rdi ; get argv[1]
    mov rsi, FLAGS_WRITE
    call try_open_file
    mov r9, rax

.files_set:
    push r8
    push r9
    mov rdi, r8
    mov rsi, r9
    call mainloop
    pop r8
    pop r9

.cleanup_inp:
    ; Close the input fd if it's a file and not stdin.
    cmp r8, STDIN
    jz .exit
    mov rax, SYS_CLOSE
    mov rdi, r8
    syscall

.cleanup_out:
    ; Close the output fd if it's a file and not stdout.
    cmp r9, STDOUT
    jz .exit
    mov rax, SYS_CLOSE
    mov rdi, r9
    syscall

.exit:
    mov rax, SYS_EXIT
    mov rdi, EXIT_OK
    syscall

help_strs:
.cmd:
    db "--help", 0
.message:
    incbin "usage.txt"
.end:
