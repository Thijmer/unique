; ---------------------------------------------------------------------------------
; Written by: Thijmen Voskuilen
;
; This file:
;  - Contains a perror function, which, given an error number and a string,
;    prints the error like the perror function in the C standard library would.
;  - The goal of this function isn't to support all errnos, but rather just the
;    ones needed in the context of this program.
; ---------------------------------------------------------------------------------

%include "src/strtools.asm"

section .text

; Print error message to stderr.
;
; Parameters:
;  - The message to print (in rdi) (can be NULL)
;  - The error number (in rsi)
;
; Clobbered registers:
;  - rax
;  - rsi
;  - rdi
;  - rdx
;  - r8
;  - r9
;
; Return:
;  - Nothing
;
; Possible errors that can occur:
;  - EACCES
;  - EISDIR
;  - ENFILE (miss niet afhandelen)
;  - ENOENT
;  - ENOMEM (miss niet afhandelen)
;  - ENOTDIR
; TODO: Add support for more error messages, the O_CREAT option can generate some that aren't included here.
perror:
    ; Register usage:
    ;  - rax, rdx: for syscalls
    ;  - rsi: custom message
    ;  - rdx: custom message len
    ;  - r8: First errno, then the perror message
    ;  - r9: The perror message length
    
    ; Create new stack frame
    push rbp
    mov rbp, rsp

    ; Determine strlen of the custom message.
    push rsi ; clobbered by strlen, so save beforehand
    call strlen
    pop rsi

    mov r8, rsi ; temporarily use r8 to store errno
    ; Move the custom message stuff to the documented registers
    mov rsi, rdi
    mov rdx, rax

    ; Determine which error message to print
	cmp r8, EACCES
	jz .eaccess
	cmp r8, EISDIR
	jz .eisdir
	cmp r8, ENOENT
	jz .enoent
	cmp r8, ENOTDIR
	jz .enotdir
	jmp .else

	; Set pointer and len in order to print the right error message
.eaccess:
	mov r8, error_messages.eaccess
	mov r9, error_messages.eisdir - error_messages.eaccess
	jmp .final
.eisdir:
	mov r8, error_messages.eisdir
	mov r9, error_messages.enoent - error_messages.eisdir
	jmp .final
.enoent:
	mov r8, error_messages.enoent
	mov r9, error_messages.enotdir - error_messages.enoent
	jmp .final
.enotdir:
	mov r8, error_messages.enotdir
	mov r9, error_messages.else - error_messages.enotdir
	jmp .final
.else:
	mov r8, error_messages.else
	mov r9, error_messages.end - error_messages.else
	jmp .final
.final:
    ; Print the custom message
	mov rax, SYS_WRITE
	mov rdi, STDERR
	syscall

    ; Print the message from the errno
    mov rsi, r8
    mov rdx, r9
	mov rax, SYS_WRITE
	mov rdi, STDERR
	syscall

	; Move out of stack frame
	pop rbp
	ret

static error_messages
error_messages:
.eaccess:
	db ": Permission denied", 10
.eisdir:
	db ": Is a directory", 10
.enoent:
	db ": No such file or directory", 10
.enotdir:
	db ": Not a directory", 10
.else:
	db ": Unforseen error", 10
.end:
