; specify 'origin' of starting address to 0x7c00 (tells assembler where code is to be loaded)
; 0x7C00 is the hardcoded convention and addressfor the first sector of the bootable device to be loaded into memory (this is only REQUIRED for bootloader devices)
org 0x7C00

; tell assembler to emit 16 bit code
; x86 should be backwards compatible with 8086 architectures, so must start with 16 bits
bits 16

%define ENDL 0x0D, 0x0A

; a flat binary (-f bin) has no sections to load separately: the BIOS reads the
; first 512 bytes and runs from byte 0, so code and data must share that one sector.
; (NASM's 'section .data/.text' laid the data out AFTER the padding and the 55 AA
; signature, i.e. outside the sector the BIOS loads.)
jmp main ; execution starts at byte 0, so skip over puts to reach main


; Prints a string to the screen
; Params:
;   - ds:si points to string
; TODO: 
; - need to fully understand al, ah and index registers
; - test program more with VirtualBox
puts:
    ; save registers in stack
    push si
    push ax
    push bx    ; bh is overwritten below (video page), so preserve the caller's bx
.loop:
    lodsb      ; loads the byte from DS:SI into AL register, then increments SI
    or al, al  ; check if next character is null
    jz .done   ; jumps to .done if next character is null (leave the loop)

    ; call bios interrupt
    mov ah, 0x0e
    mov bh, 0
    int 0x10

    jmp .loop
.done:
    ; restore registers (reverse order of the pushes)
    pop bx
    pop ax
    pop si
    ret

main:

    ; setup data segments
    mov ax, 0   ; accumulator
    mov ds, ax  ; data segment
    mov es, ax  ; extra segment

    ; setup stack
    mov ss, ax  ; stack segment register
    mov sp, 0x7C00  ; stack grows downwards from where memory loads in, so start from beginning of operating system

    ; print msg
    mov si, msg_hello
    call puts

    hlt ; stops CPU from executing (can be resumed with an interrupt)

.halt:
    jmp .halt ; jumpts to .halt unconditionally to form infinite loop if CPU starts again (can also juse use 'jmp $')

msg_hello: db 'Hello world!', ENDL, 0x00

; fill rest of the 512 bytes with 00 and fill last 2 bytes with boot sector convention
times 510-($-$$) db 0
db 0x55, 0xaa
