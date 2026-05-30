# Memory Inspector — Learn Assembly by Looking at RAM

This program shows you what data actually looks like inside your computer's
memory. It's like `hexdump -C` but written in x86-64 assembly from scratch.

```
=== MEMORY INSPECTOR ===
Learn x86-64 Assembly by Visualizing RAM

Format: [ADDRESS] | [HEX BYTES] | [ASCII]
-----------------------------------------------

--- 'number' (8 bytes) ---
0x0000000000402000 | 01 EF CD AB 78 56 34 12  | ....xV4.
```

---

## How to Build and Run

```bash
nasm -f elf64 meminspect.asm -o meminspect.o     # assemble
ld meminspect.o -o meminspect                     # link
./meminspect                                      # run
```

You need `nasm` installed. On Debian/Ubuntu: `sudo apt install nasm`.

---

## What Even IS Assembly?

Assembly is the **lowest human-readable programming language**. Each
instruction maps directly to one CPU operation. There's no "if" or "for"
like in Python or C — you have to move data around manually using
**registers** and **memory**.

Every line in the `.text` section is an instruction the CPU runs.

---

## What is Memory?

Imagine RAM as a **gigantic row of numbered mailboxes**:

```
Address:  0  1  2  3  4  5  6  7  8  9  ...
         ┌──┬──┬──┬──┬──┬──┬──┬──┬──┬──┐
Value:   │48│65│6C│6C│6F│21│00│BE│BA│FE│...
         └──┴──┴──┴──┴──┴──┴──┴──┴──┴──┘
```

- Each mailbox holds **1 byte** (a number from 0-255)
- Every byte has a unique **address** (its position)
- A "variable" is just a **name for an address**. When you write
  `greeting db "Hello!", 0`, the label `greeting` becomes the address
  where the bytes `48 65 6C 6C 6F 21 00` are stored.

### Sections of Memory

| Section  | Contents |
|----------|----------|
| `.data`  | Pre-set values (numbers, strings you define) |
| `.bss`   | Reserved space for temporary data |
| `.text`  | Your code (instructions the CPU runs) |

All three live in the same RAM. The program dumps `.data` so you can
see exactly where your variables are and what values they contain.

---

## What are Registers?

Registers are **super-fast storage inside the CPU** (not in RAM). Think
of them as your **scratchpad** — you load data from memory into
registers, work on it, then store it back.

Common 64-bit registers: `rax`, `rbx`, `rcx`, `rdx`, `rsi`, `rdi`,
`r8`, `r9` ... `r15`

You can access smaller parts of them:
- `rax` = full 64 bits (8 bytes)
- `eax` = lower 32 bits (4 bytes)
- `ax`  = lower 16 bits (2 bytes)
- `al`  = lower 8 bits (1 byte) — the "a" stands for "accumulator"

### The Linux Calling Convention

When calling a function (or a syscall, see below), arguments go in
specific registers:
- `rdi` = 1st argument
- `rsi` = 2nd argument
- `rdx` = 3rd argument
- `rcx` = 4th argument (but `r10` is used for syscalls, see why below)
- `r8`  = 5th argument
- `r9`  = 6th argument

---

## What are Syscalls?

You can't directly print to the screen — the OS controls hardware.
**Syscalls** let your program ask the Linux kernel to do things for
you.

```asm
mov rax, 1        ; syscall number: 1 = write
mov rdi, 1        ; 1st arg: file descriptor (1 = stdout)
mov rsi, buf      ; 2nd arg: pointer to data to write
mov rdx, 10       ; 3rd arg: how many bytes to write
syscall           ; hand control to the kernel
```

For **exit**:
```asm
mov rax, 60       ; syscall number: 60 = exit
xor rdi, rdi      ; 1st arg: exit code (0 = success)
syscall
```

**IMPORTANT**: `syscall` **destroys** `rcx` and `r11` (it saves RIP in
rcx internally). This is why `putchar` has to save `rcx` on the stack
before calling `syscall` — or else any loop using `rcx` as a counter
will break!

---

## How This Program Works

### The `.data` Section — Our Test Data

```asm
number   dq 0x12345678ABCDEF01   ; 8 bytes
another  dq 0xDEADBEEFCAFEBABE   ; 8 bytes, sits right after
greeting db "Hello!", 0          ; 7 bytes (6 chars + null)
rawbytes db 0x41, 42, 0xFF, ...  ; 6 raw bytes
padding  times 4 db 0xCC        ; 4 bytes of 0xCC
```

Labels (`number`, `greeting`, etc.) are the **addresses** where these
values start in RAM. When we dump `number`, we're reading 8 bytes
starting at that address.

### The `.text` Section — Our Code

**`_start`** — the entry point (like `main()` in C). It calls `puts`
to print labels, then calls `hexdump` for each variable to show its
memory.

**`puts`** — prints a string by:
1. Counting bytes until it finds `0` (the null terminator)
2. Calling `write(1, string, count)`

**`puthexbyte`** — prints one byte as 2 hex digits + space:
1. Takes the byte (e.g., `0xAB`)
2. Shifts right by 4 to get the **high nibble** (`0xA`)
3. Masks with `0x0F` to get the **low nibble** (`0xB`)
4. Uses each nibble as an index into `"0123456789ABCDEF"`
5. Writes the 3 characters: e.g., `"AB "`

**`putaddr`** — prints a 64-bit address as `0xXXXXXXXXXXXXXXXX` by
rotating 4 bits at a time and converting each to a hex character.

**`hexdump`** — the main worker. Prints one row at a time:
```
0xADDRESS | XX XX XX XX XX XX XX XX | .......?
```
- Shows address, 8 hex bytes (padded with spaces for last row),
  ASCII representation (`.` for non-printable)

---

## Understanding the Output

### Example 1: The `number` Variable

```
0x0000000000402000 | 01 EF CD AB 78 56 34 12  | ....xV4.
```

The source says `dq 0x12345678ABCDEF01` but in memory we see:
```
01 EF CD AB 78 56 34 12
```

This is **little-endian** byte order. x86 CPUs store the **least
significant byte first**. The value `0x12345678ABCDEF01` is stored
as bytes starting from the right:

```
Value:  12 34 56 78 AB CD EF 01
Memory: 01 EF CD AB 78 56 34 12
         ↑                        least significant byte first!
```

### Example 2: The `greeting` String

```
0x0000000000402010 | 48 65 6C 6C 6F 21 00     | Hello!. 
```

Each character is one byte using its **ASCII code**:
```
Char:  H    e    l    l    o    !    (null)
Hex:   48   65   6C   6C   6F   21   00
```

The `00` byte is the **null terminator** — it marks the end of the
string so `puts` knows where to stop.

### Example 3: Variables Sit Back-to-Back

```
0x0000000000402000 | 01 EF CD AB 78 56 34 12  | ....xV4.    ← number (8 bytes)
0x0000000000402008 | BE BA FE CA EF BE AD DE  | ........    ← another (8 bytes)
0x0000000000402010 | 48 65 6C 6C 6F 21 00 41  | Hello!.A    ← greeting starts here
0x0000000000402018 | 2A FF 00 AA 4D CC CC CC  | *...M..     ← rawbytes + padding
```

Notice `another` starts at address `0x402008` — that's `number`'s
address + 8 bytes. And `greeting` starts at `0x402010` — `another`'s
address + 8 bytes. **No gaps!** Each variable follows the previous one
immediately.

---

## Common Instructions Used in This Program

| Instruction | Meaning |
|-------------|---------|
| `mov X, Y` | Copy Y into X |
| `lea X, [addr]` | Load the address into X (not the value!) |
| `add X, Y` | X = X + Y |
| `sub X, Y` | X = X - Y |
| `and X, Y` | X = X & Y (bitwise AND) |
| `shr X, N` | Shift X right by N bits |
| `rol X, N` | Rotate X left by N bits (bits wrap around) |
| `cmp X, Y` | Compare X with Y (sets flags) |
| `je label` | Jump to label if equal |
| `jne label` | Jump if not equal |
| `jl / jg` | Jump if less / greater |
| `jle / jge` | Jump if less-or-equal / greater-or-equal |
| `jmp label` | Jump always (unconditional) |
| `call label` | Call a subroutine (like a function) |
| `ret` | Return from subroutine |
| `inc X` | X = X + 1 |
| `dec X` | X = X - 1 |
| `xor X, Y` | X = X ^ Y (often used to zero: `xor rax,rax` = 0) |
| `xlatb` | `AL = byte at [RBX + AL]` — table lookup |
| `push X` | Save X on the stack |
| `pop X` | Restore X from the stack |

### [Brackets] = Memory Access

```asm
mov rax, number      ; rax = ADDRESS of 'number' (like &number in C)
mov rax, [number]    ; rax = VALUE at 'number' (8 bytes) (like *ptr)
mov al, [number]     ; al  = first byte at 'number' (1 byte)
```

---

## How to Experiment

Try changing the test data and see what happens:

```asm
number   dq 0xCAFEBABE            ; smaller value — notice only 4 bytes change
greeting db "Hi!", 0               ; shorter string
```

Add your own variables:

```asm
mydata   db 0x11, 0x22, 0x33, 0x44
mystring db "Wow, assembly!", 0
```

Then add a dump call in `_start`:
```asm
lea rdi, [rel mystring]            ; address
mov rsi, 14                        ; length
call hexdump
```

---

## Why Did We Get an Infinite Loop?

The original version of `putchar` did NOT save `rcx`:

```asm
putchar:
    push rax
    push rdi
    push rsi
    push rdx
    mov [rel charbuf], dil
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel charbuf]
    mov rdx, 1
    syscall                  ; ← this DESTROYS rcx!
    pop rdx
    pop rsi
    pop rdi
    pop rax
    ret
```

`syscall` stores the return address in `rcx` (and flags in `r11`).
When `putaddr` used `rcx` as a loop counter (16 hex digits), every
call to `putchar` → `syscall` would reset `rcx`, and the loop would
never finish.

Fix: save `rcx` before `syscall`, restore it after.

---

## Key Takeaways

1. **Memory is a giant array of bytes** — every variable is just a
   name for an address.

2. **Labels are addresses** — `number dq 5` means the label `number`
   = the address where value 5 is stored.

3. **x86 is little-endian** — multi-byte values are stored with the
   smallest byte first. `0x1234` becomes `34 12` in memory.

4. **Registers are your scratchpad** — everything you do happens in
   registers. You load from memory, process, then store back.

5. **Syscalls talk to the OS** — use `syscall` with the right number
   in `rax` and arguments in `rdi`, `rsi`, `rdx`.

6. **`syscall` destroys `rcx` and `r11`** — always save them first!

7. **Push/pop to save registers** — the stack is your notepad for
   temporary storage.
