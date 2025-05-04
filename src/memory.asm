; ---------------------------------------------------------------------------------
; Written by: Thijmen Voskuilen
;
; This file:
;  - Implements extremely simple dynamic memory allocating functionality.
;  - It only implements allocating memory, not freeing it.
;  - This is not a problem in the context of this program, because the hash table
;    will only grow as new lines are being read in and new items are being added.
;  - It makes use of the sys_brk system call, increasing the program break in order
;    to allocate memory.
;  - It doesn't allocate this memory using one syscall for each allocation, but
;    does so in large increments, reducing the amount of syscalls necessary.
;    These increments can be configured in config.mac.
; ---------------------------------------------------------------------------------

%include "src/os_consts.mac"
%include "src/config.mac"

; FUNCTIONS
section .text

; Initialize the memory allocation system.
;
; Parameters: None
; Return: Nothing
;
; Clobbered registers:
;  - rax, rdi
heap_initialize:
    ; Determine current program break by using the syscall but letting it fail.
    mov rax, SYS_BRK ; brk system call
    xor rdi, rdi ; set the brk to 0 to let it fail
    syscall ; Syscall. Now, rax holds the current break.

    ; Initialize the global vars that keep track of heap usage.
    mov qword [heap_data.curr_prgbrk], rax
    mov qword [heap_data.usg_top], rax
    ret
    
; Allocate memory on the heap
;
; Parameters:
;  - size (rdi): The amount of bytes to allocate
;
; Return:
;  - A pointer to the allocated memory (rax)
;
; Clobbered registers:
;  - r8
;  - rax
;  - rdx
;  - rdi
malloc:
    ; Register usage:
    ;  - r8: Used to store available memory, later for number of blocks to allocate,
    ;        the amount of bytes to allocate and the new progbrk address.

    ; Create stack frame
    push rbp
    mov rbp, rsp

    ; Calculate the current available capacity
    mov r8, qword [heap_data.curr_prgbrk]
    sub r8, qword [heap_data.usg_top]
    push rdi ; Backup the size.

    ; If enough memory is available, don't allocate additional memory but just return.
    cmp rdi, r8
    jle .release

    ; Otherwise, allocate this additional memory.
    ; This part calculates: new_progbrk_location = old_progbrk_location + (size / progbrk_increment + 1) * progbrk_increment
    mov r8, rdi ; move size to r8
    shr r8, progbrk_increment_pwr ; Divide using bitshifts bc its fast.
    inc r8 ; Because division is rounded down and we want to round up, add 1.
    shl r8, progbrk_increment_pwr ; Convert to the actual number of bytes to allocate.
    add r8, qword [heap_data.curr_prgbrk] ; Add current progbrk to get the address of the new progbrk.
    mov qword [heap_data.curr_prgbrk], r8 ; Store the new program break.

    ; Make the system call to extend the program break.
    mov rax, SYS_BRK
    mov rdi, r8 ; new program break
    syscall ; perform the syscall

    ; Release if the allocation was successful.
    cmp rax, r8
    jz .release

    ; Exit with an error code if it wasn't.
    mov rax, SYS_EXIT
    mov rdi, EXIT_MEM
    syscall


.release:
    ; Update usg_top and give the memory to the user.
    pop rdi ; Retrieve the size.
    mov rax, qword [heap_data.usg_top] ; The previous usg_top should be returned.
    add qword [heap_data.usg_top], rdi ; Update usg_top to include newly allocated memory.
    leave
    ret

    


; STATIC VARIABLES
section .data
static memory_data
heap_data:
; Pointer to the current program break
.curr_prgbrk:
    dq 0
; Pointer to the start of the next heap part to be returned.
.usg_top:
    dq 0
