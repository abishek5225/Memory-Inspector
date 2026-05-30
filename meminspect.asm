; Memory Inspector - shows what data looks like in RAM
; Build: nasm -f elf64 meminspect.asm -o meminspect.o && ld meminspect.o -o meminspect
; Run:   ./meminspect

default rel

section .data
    num1     dq 0x12345678ABCDEF01
    num2     dq 0xDEADBEEFCAFEBABE
    str1     db "Hello!", 0
    raw      db 0x41, 42, 0xFF, 0x00, 0xAA, 77
    pad      times 4 db 0xCC

    msg_title db "=== Memory Inspector ===", 10, 0
    msg_num   db "--- num1 ---", 10, 0
    msg_num2  db "--- num2 ---", 10, 0
    msg_str   db "--- str1 ---", 10, 0
    msg_raw   db "--- raw ---", 10, 0
    msg_pad   db "--- pad ---", 10, 0
    msg_full  db "--- full .data ---", 10, 0

    hexchars db "0123456789ABCDEF"
    end_data:

section .bss
    outb     resb 1

section .text
    global _start

_start:
    lea rdi, [rel msg_title]
    call print_str

    lea rdi, [rel msg_num]
    call print_str
    lea rsi, [rel num1]
    mov rcx, 8
    call dump_bytes

    lea rdi, [rel msg_num2]
    call print_str
    lea rsi, [rel num2]
    mov rcx, 8
    call dump_bytes

    lea rdi, [rel msg_str]
    call print_str
    lea rsi, [rel str1]
    mov rcx, 7
    call dump_bytes

    lea rdi, [rel msg_raw]
    call print_str
    lea rsi, [rel raw]
    mov rcx, 6
    call dump_bytes

    lea rdi, [rel msg_pad]
    call print_str
    lea rsi, [rel pad]
    mov rcx, 4
    call dump_bytes

    lea rdi, [rel msg_full]
    call print_str
    lea rsi, [rel num1]
    mov rcx, end_data - num1
    call dump_bytes

    mov rax, 60
    xor rdi, rdi
    syscall

; print 1 character (dil) to stdout
emit:
    mov [rel outb], dil
    push rax
    push rcx
    push rdi
    push rsi
    push rdx
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel outb]
    mov rdx, 1
    syscall
    pop rdx
    pop rsi
    pop rdi
    pop rcx
    pop rax
    ret

; print null-terminated string at rdi
print_str:
    push rcx
    push rdi
    push rsi
    push rdx
    push rax
    xor rcx, rcx
.l:
    cmp byte [rdi + rcx], 0
    je .go
    inc rcx
    jmp .l
.go:
    mov rax, 1
    mov rsi, rdi
    mov rdx, rcx
    mov rdi, 1
    syscall
    pop rax
    pop rdx
    pop rsi
    pop rdi
    pop rcx
    ret

; print byte in al as 2 hex digits
print_hex_byte:
    push rax
    push rbx

    mov ah, al

    shr al, 4
    and al, 0x0F
    lea rbx, [rel hexchars]
    xlatb
    mov dil, al
    call emit

    mov al, ah
    and al, 0x0F
    lea rbx, [rel hexchars]
    xlatb
    mov dil, al
    call emit

    pop rbx
    pop rax
    ret

; print address in rdi as 16 hex digits
print_addr:
    push r8
    push rcx
    push rax
    push rbx
    push rdi

    mov r8, rdi
    mov rcx, 16
.l:
    mov rax, r8
    shr rax, 60
    and al, 0x0F
    lea rbx, [rel hexchars]
    xlatb
    mov dil, al
    call emit
    shl r8, 4
    dec rcx
    jnz .l

    pop rdi
    pop rbx
    pop rax
    pop rcx
    pop r8
    ret

; dump rcx bytes at rsi in hex+ascii format
; each row: ADDR | HEX BYTES | ASCII
dump_bytes:
    push rsi
    push rcx
    push r8
    push r9

    mov r8, rsi
    mov r9, rcx

.row:
    cmp r9, 0
    jle .end

    mov rdi, r8
    call print_addr

    mov dil, ' '
    call emit
    mov dil, '|'
    call emit
    mov dil, ' '
    call emit

    xor rdx, rdx

.hx:
    cmp rdx, 8
    je .hx_done
    cmp rdx, r9
    jge .hx_pad

    mov al, [r8 + rdx]
    call print_hex_byte
    mov dil, ' '
    call emit

    inc rdx
    jmp .hx

.hx_pad:
    mov dil, ' '
    call emit
    mov dil, ' '
    call emit
    mov dil, ' '
    call emit
    inc rdx
    cmp rdx, 8
    jl .hx_pad

.hx_done:
    mov dil, ' '
    call emit
    mov dil, '|'
    call emit
    mov dil, ' '
    call emit

    xor rdx, rdx

.as:
    cmp rdx, 8
    je .as_done
    cmp rdx, r9
    jge .as_pad

    mov dil, [r8 + rdx]
    cmp dil, 0x20
    jl .dot
    cmp dil, 0x7E
    jg .dot
    call emit
    inc rdx
    jmp .as
.dot:
    mov dil, '.'
    call emit
    inc rdx
    jmp .as

.as_pad:
    mov dil, ' '
    call emit
    inc rdx
    cmp rdx, 8
    jl .as_pad

.as_done:
    mov dil, 10
    call emit

    sub r9, 8
    jle .end
    add r8, 8
    jmp .row

.end:
    pop r9
    pop r8
    pop rcx
    pop rsi
    ret
