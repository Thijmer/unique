; ---------------------------------------------------------------------------------
; Written by: Thijmen Voskuilen
;
; This file:
;  - Implements a hash set and functions to work with it.
;  - This is a separate-chaining hash set (open addressing is more difficult and I'm
;    already programming in assembly).
;  - The data stored in the hash set is strings.
;  - In order to keep things simple, this hashset doesn't resize itself when over-saturated.
;  - Also in order to keep things simple, the hash set isn't object oriented, so it can
;    be stored in the .data section. This program only needs one hashset anyway!
; ---------------------------------------------------------------------------------

%include "src/os_consts.mac"

struc HashSet
    ; The actual table. It consists of pointers to EntryNodes.
    .table  resq  (1 << table_capacity_pwr)
endstruc

struc EntryNode
    ; A pointer to the next item in the linked list. Can be null if this is the end node.
    .next   resq 1

    ; The (null-terminated) string value of this entry. Only 1 byte is reserved here,
    ; but more room should be allocated for the node to store strings with actual content.
    .val    resb 1
endstruc

section .text

; Hash the given string.
;
; Parameters:
;  - The string to hash (rdi)
;
; Return:
;  - The hash (eax)
;
; Clobbered registers:
;  - rax, rcx, rdi
;
; The algotirhm used:
;  - https://gist.github.com/sgsfak/9ba382a0049f6ee885f68621ae86079b
;  - specifically, h31_hash
static hash
hash:
    xor rax, rax ; Start with hash = 0
    xor ecx, ecx ; Make bits of ecx 0 already, this is necessary for adding cl to eax.
.loop:
    mov cl, byte [rdi] ; Load the current char
    cmp cl, 0 ; Return if the end of the string is reached.
    jz .ret

    ; hash = 31 * hash + curr_char;
    imul eax, 31
    add eax, ecx

    inc rdi
    jmp .loop
.ret:
    ret


; Calculate the index of a certain item in the hash set.
;
; Parameters:
;  - The string to get the index of (rdi)
;
; Return:
;  - The index (eax)
;
; Clobbered registers:
;  - rax, rcx, rdi
static index_of
index_of:
    call hash ; compute hash
    and eax, (0xff_ff_ff_ff >> (32 - table_capacity_pwr)) ; Modulo to get index
    ret


; Look whether the hash set contains the given item.
;
; Parameters:
;  - The string to look up (rdi). This function copies it so it
;    doesn't need to have a long lifetime.
;
; Return:
;  - Answer (rax):
;    - 1 if the hashset already contained this item.
;    - 0 otherwise.
;  - Linked list tail next pointer pointer (rdx) (only valid if answer = 0):
;    - This is to prevent having to hash the text and walk the linked
;      list twice in hs_insert.
;
; Invariants to keep in mind:
;  - The input string pointer should be null-terminated, and should not be a NULL pointer.
; 
; Clobbered registers:
;  - rax, rcx, rdi, rsi, r8, r9, rdx
hs_contains:
    enter 16, 0
    mov [rbp - 16], rdi ; backup the string location.
    call index_of ; Determine index of string in hash table.

    ; Store address of corresponding hash table entry in r9.
    mov r9, rax ; offset = index * 8 (bc a pointer is 8 bits wide)
    shl r9, 3 ; `<< 3` is the same as `* 8` but faster.
    add r9, global_hash_set + HashSet.table
    mov rdx, r9 ; Store this location in rdx.

.loop:
    ; Extract address and perform null test.
    mov r9, qword [r9] ; Move the pointer to the EntryNode into r9
    test r9, r9 ; if the pointer is null, go to not found.
    jz .not_found

    ; Look whether the node contains the string we're looking for.
    mov qword [rbp - 8], r9 ; Backup r9
    mov rdi, qword [rbp - 16] ; Retrieve string location from stack.
    mov rsi, r9 ; Store pointer to the text in the node in rsi.
    add rsi, EntryNode.val
    call streq ; Call streq to check string equality.
    mov r9, qword [rbp - 8] ; Restore r9

    ; If strings are equal, return found.
    test rax, rax
    jnz .found

    ; Otherwise, continue at next node in linked list.
    add r9, EntryNode.next ; Make r9 point to the next pointer in this node.
    mov rdx, r9 ; Store next pointer pointer in rdx.
    jmp .loop

.found:
    mov rax, 1 ; set answer to 1: found!
    jmp .cleanup
.not_found:
    mov rax, 0 ; Set answer to 0: Not found :(
.cleanup:
    leave
    ret


; Try to insert a string into the hash table.
;
; Parameters:
;  - The string to insert (rdi). This function copies it so it
;    doesn't need to have a long lifetime.
;
; Return (rax):
;  - 1 if the hashset already contained this item.
;  - 0 otherwise.
;
; Invariants to keep in mind:
;  - The input string pointer should be null-terminated, and should not be a NULL pointer.
;
; Clobbered registers:
;  - rax, rcx, rdi, rsi, r8, r9, rdx
hs_insert:
    enter 24, 0
    mov [rbp - 8], rdi ; backup the string location.

    ; Look whether the hash set already contains this item.
    call hs_contains ; Since the args here are the same as hs_contains, we can just call directly.
    test rax, rax ; If it returned non-zero, the hashset already contains this item. Return is
                  ; also the same as hs_contains (for rax).
    jnz .already_contains
    mov [rbp - 16], rdx ; Backup linked list tail next ptr ptr

    ; Init new node step 1: Get string len.
    mov rdi, [rbp - 8] ; Restore string location
    call strlen ; Get string len
    mov rdi, rax ; Move the result to rdi, as this will hold the memory to reserve for the node.
    mov [rbp - 24], rax ; Also put a copy on the stack, for use with strncpy.

    ; Init new node step 2: Allocate memory
    add rdi, EntryNode%+_size ; Add size needed for other stuff in the node (including the terminating null).
    call malloc ; Allocate the actual memory

    ; Init new node step 3: Initialize values
    mov qword [rax + EntryNode.next], 0 ; Make sure the end is a null pointer.
    mov rdi, rax ; Store val ptr in rdi for strncpy
    add rdi, EntryNode.val
    mov rsi, [rbp - 8] ; Move source string to rsi for strncpy.
    mov rdx, [rbp - 24] ; Move the strlen from r8 to rdx for strncpy
    call strncpy

    ; Init new node step 4: Add to linked list
    mov rdx, [rbp - 16] ; Restore linked list tail next ptr ptr
    mov [rdx], rax ; Make linked list end point to this new node.

    mov rax, 0 ; Set rax to reflect the item not being found.

.already_contains:
.cleanup:
    leave
    ret



section .data
static global_hash_set
global_hash_set:
    istruc HashSet
        ; Initialize the table with zeroes.
        at  HashSet.table, times (1 << table_capacity_pwr) dq 0
    iend
