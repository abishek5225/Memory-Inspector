; Memory Inspector - Dumps .data section in hex+ASCII format
; Build: nasm -f elf64 meminspect.asm -o meminspect.o && ld meminspect.o -o meminspect
; Run:   ./meminspect

default rel

section .data
    number   dq 0x12345678ABCDEF01   ; 8 bytes
    another  dq 0xDEADBEEFCAFEBABE   ; 8 bytes, right after 'number'
    greeting db "Hello!", 0          ; 7 bytes (string + null)
    rawbytes db 0x41, 42, 0xFF, 0x00, 0xAA, 77  ; 6 raw bytes
    padding  times 4 db 0xCC        ; 4 bytes of 0xCC

    title_txt   db "=== MEMORY INSPECTOR ===", 10
                db "Learn x86-64 Assembly by Visualizing RAM", 10, 10, 0
    header_txt  db "Format: [ADDRESS] | [HEX BYTES] | [ASCII]", 10
                db "-----------------------------------------------", 10, 0
    lbl_number   db 10, "--- 'number' (8 bytes, value: 0x12345678ABCDEF01) ---", 10, 0
    lbl_another  db 10, "--- 'another' (8 bytes, value: 0xDEADBEEFCAFEBABE) ---", 10, 0
    lbl_greeting db 10, "--- 'greeting' (string: Hello!) ---", 10, 0
    lbl_rawbytes db 10, "--- 'rawbytes' (6 bytes: hex & decimal mix) ---", 10, 0
    lbl_padding  db 10, "--- 'padding' (4 bytes of 0xCC fill) ---", 10, 0
    lbl_alldata  db 10, "--- FULL .data SECTION (sequential layout) ---", 10, 0
    hexchars   db "0123456789ABCDEF"  ; lookup table for hex conversion
    end_data:                         ; marks end of .data section

section .bss
    hexbuf      resb 3               ; buffer for "XX "
    charbuf     resb 1               ; buffer for 1 char

section .text
    global _start

; Program starts here
_start:
    lea rdi, [rel title_txt]         ; load address of title string
    call puts
    lea rdi, [rel header_txt]
    call puts

    ; Dump each variable individually
    lea rdi, [rel lbl_number]
    call puts
    lea rdi, [rel number]
    mov rsi, 8                       ; 8 bytes
    call hexdump

    lea rdi, [rel lbl_another]
    call puts
    lea rdi, [rel another]
    mov rsi, 8
    call hexdump

    lea rdi, [rel lbl_greeting]
    call puts
    lea rdi, [rel greeting]
    mov rsi, 7                       ; 7 bytes ("Hello!" + null)
    call hexdump

    lea rdi, [rel lbl_rawbytes]
    call puts
    lea rdi, [rel rawbytes]
    mov rsi, 6
    call hexdump

    lea rdi, [rel lbl_padding]
    call puts
    lea rdi, [rel padding]
    mov rsi, 4
    call hexdump

    ; Dump everything from 'number' to end of .data
    lea rdi, [rel lbl_alldata]
    call puts
    lea rdi, [rel number]
    mov rsi, end_data - number       ; total .data size
    call hexdump

    ; Exit
    mov rax, 60                      ; syscall: exit
    xor rdi, rdi                     ; exit code 0
    syscall

; Print null-terminated string
; rdi = string pointer
puts:
    push rdi
    xor rcx, rcx                     ; counter = 0
.count_loop:
    cmp byte [rdi + rcx], 0          ; reached null?
    je .write_it
    inc rcx
    jmp .count_loop
.write_it:
    mov rax, 1                       ; syscall: write
    mov rsi, rdi                     ; buffer
    mov rdx, rcx                     ; length
    mov rdi, 1                       ; stdout
    syscall
    pop rdi
    ret

; Print byte as "XX "
; dil = byte
puthexbyte:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi

    mov al, dil                      ; get byte
    shr al, 4                        ; high nibble
    and al, 0x0F
    lea rbx, [rel hexchars]
    xlatb                            ; convert to hex char
    mov [rel hexbuf], al

    mov al, dil                      ; get byte again
    and al, 0x0F                     ; low nibble
    lea rbx, [rel hexchars]
    xlatb
    mov [rel hexbuf + 1], al

    mov byte [rel hexbuf + 2], ' '   ; trailing space

    mov rax, 1
    mov rdi, 1
    lea rsi, [rel hexbuf]
    mov rdx, 3
    syscall

    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; Print single character
; dil = character
putchar:
    push rax
    push rcx                         ; syscall destroys rcx!
    push rdi
    push rsi
    push rdx

    mov [rel charbuf], dil
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel charbuf]
    mov rdx, 1
    syscall

    pop rdx
    pop rsi
    pop rdi
    pop rcx
    pop rax
    ret

; Print 64-bit value as "0xXXXXXXXXXXXXXXXX"
; rdi = value
putaddr:
    push rax
    push rbx
    push rcx
    push rdi
    push rsi
    push rdx
    push r8

    mov r8, rdi                      ; save address
    mov dil, '0'                     ; print "0x"
    call putchar
    mov dil, 'x'
    call putchar

    mov rcx, 16                      ; 16 hex digits
.digit_loop:
    rol r8, 4                        ; top nibble → bottom
    mov al, r8b
    and al, 0x0F
    lea rbx, [rel hexchars]
    xlatb
    mov dil, al
    call putchar
    dec rcx
    jnz .digit_loop

    pop r8
    pop rdx
    pop rsi
    pop rdi
    pop rcx
    pop rbx
    pop rax
    ret

; Dump memory in hex+ASCII format (8 bytes per row)
; rdi = start address, rsi = byte count
hexdump:
    push rbx
    push rcx
    push rdi
    push rsi
    push r8
    push r9
    push r10

    mov r8, rdi                      ; current address
    mov r9, rsi                      ; bytes remaining

.row_loop:
    cmp r9, 0
    jle .done

    mov rdi, r8                      ; print address
    call putaddr

    mov dil, ' '                     ; print " | "
    call putchar
    mov dil, '|'
    call putchar
    mov dil, ' '
    call putchar

    xor rbx, rbx                     ; column = 0
.hex_loop:
    cmp rbx, 8
    je .hex_done
    cmp rbx, r9                      ; more bytes left?
    jge .hex_pad

    mov dil, byte [r8 + rbx]         ; load byte
    call puthexbyte
    inc rbx
    jmp .hex_loop

.hex_pad:                            ; pad with spaces
    mov dil, ' '
    call putchar
    mov dil, ' '
    call putchar
    mov dil, ' '
    call putchar
    inc rbx
    cmp rbx, 8
    jl .hex_pad

.hex_done:
    mov dil, ' '                     ; print " | "
    call putchar
    mov dil, '|'
    call putchar
    mov dil, ' '
    call putchar

    xor rbx, rbx                     ; column = 0
.ascii_loop:
    cmp rbx, 8
    je .ascii_done
    cmp rbx, r9
    jge .ascii_pad

    mov dil, byte [r8 + rbx]         ; load byte
    cmp dil, 0x20                    ; printable ASCII?
    jl .ascii_dot
    cmp dil, 0x7E
    jg .ascii_dot
    jmp .ascii_print
.ascii_dot:
    mov dil, '.'
.ascii_print:
    call putchar
    inc rbx
    jmp .ascii_loop

.ascii_pad:
    mov dil, ' '
    call putchar
    inc rbx
    cmp rbx, 8
    jl .ascii_pad

.ascii_done:
    mov dil, 10                      ; newline
    call putchar

    sub r9, 8                        ; 8 bytes done
    jle .done
    add r8, 8                        ; next row
    jmp .row_loop

.done:
    pop r10
    pop r9
    pop r8
    pop rsi
    pop rdi
    pop rcx
    pop rbx
    ret
