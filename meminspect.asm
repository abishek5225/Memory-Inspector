default rel

section .data
    number dq 12345678 ;this creates memory variable| dq-> define quadword 
    text db "Hello", 0 ;bd-> definebytes. This stores characters in memory

section .text
    global _start

_start:

    ; Load address of number into register
    mov rax, number

    ; Value at address
    mov rbx, [number] ;the bracket [] indicates go to the memory location and read the values

    ; Exit program
    mov rax, 60
    xor rdi, rdi
    syscall
