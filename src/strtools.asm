; ---------------------------------------------------------------------------------
; Written by: Thijmen Voskuilen
;
; This file:
;  - Contains some functions that make it easier to work with strings.
; ---------------------------------------------------------------------------------

section .text

; Count the number of bytes starting from the given pointer, until the null character is reached.
; This results in the string length.
;
; Parameters:
;  - The string to calculate the length of (in rdi)
;
; Return:
;  - The string length (in rax)
;
; Clobbered registes:
;  - rax
;  - rsi (sil)
strlen:
    ; Registers:
    ;  - rax: The string length until now
    ;  - rdi: The current index in the string
    mov rax, 0 ; Start with length 0
.loop:
    mov sil, byte [rdi + rax] ; Load next character
    cmp sil, 0
    jz .end
    inc rax
    jmp .loop
.end:
    ret


; Copy non-null bytes from the string pointed to by src into the array pointed to by dst.
; If the source has too few non-null bytes to fill the destination, pad the destination with trailing null bytes.
; If the destination buffer, limited by dsize, isn't large enough to hold the copy, the resulting character sequence is truncated.
;
; Parameters:
;  - dst: The destination array. (in rdi)
;  - src: The source string. (in rsi)
;  - dsize: The capacity of dst. (in rdx)
;
; Clobbered registers:
;  - r8
;  - r9
strncpy:
    ; Registers:
    ; - r8: index i
    ; - r9b: current character value
    ; - rdi: dst
    ; - rsi: src
    ; - rdx: dsize
    xor r8, r8 ; let i=0
.loop:
    ; Copy src to dst, until a null byte is detected or dst is full.
    cmp r8, rdx ; Return when i >= dsize
    jge .end
    mov r9b, byte [rsi + r8] ; Get the character at this position
    cmp r9b, 0 ; Break to fill_remaining when null byte is reached
    jz .fill_remaining

    mov [rdi + r8], byte r9b ; Copy the actual bytes

    inc r8 ; Increment counter and loop
    jmp .loop

.fill_remaining:
    ; Fill remaining capacity of dst with null characters.
    cmp r8, rdx ; Return when i >= dsize
    jge .end

    mov [rdi + r8], byte 0 ; Write null bytes

    inc r8
    jmp .fill_remaining

.end:
    ret

; Look whether string a and b are the same.
;
; Parameters:
;  - a: The first string (char *, non-null, null terminated) (in rdi)
;  - b: The second string (char *, non-null, null terminated) (in rsi)
;
; Return:
;  - 1 if the strings are equal, 0 if they're not. (rax)
;
; Clobbered registers:
;  - rdi, rsi, r8, r9
streq:
    ; Find char values of strings.
    mov r8b, byte [rdi]
    mov r9b, byte [rsi]

    ; Return if they're not equal.
    cmp r8b, r9b
    jnz .neq

    ; Equal but and zero (end of string): Done, equal.
    test r8b, r8b
    jz .eq

    ; Equal but not zero: Continue looking at next char.
    inc rdi
    inc rsi
    jmp streq

.neq:
    xor rax, rax
    ret
.eq:
    mov rax, 1
    ret
