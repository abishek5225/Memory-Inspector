section .data
    number dq 12345678
    text db "Hello", 0

section .text
    global _start

_start:

    ; Load address of number into register
    mov rax, number

    ; Value at address
    mov rbx, [number]

    ; Exit program
    mov rax, 60
    xor rdi, rdi
    syscall
