; specify 'origin' of starting address to 0x7c00 (tells assembler where code is to be loaded)
; 0x7C00 is the hardcoded convention and addressfor the first sector of the bootable device to be loaded into memory
org 0x7C00

; tell assembler to emit 16 bit code
; x86 should be backwards compatible with 8086 architectures, so must start with 16 bits */
bits 16

start:
    jmp main ; ensures that main is still the entry point


; prints a string to the screen
; Params:
;   - ds:si points to string
; 
puts:
    ;save registeers we will modify
    push si
    push ax

.loop:
    lodsb      ; loads the next character in al
    or al, al  ; verify if the next cahracter is null?
    jz .done

.done:
    pop ax
    pop si

main:

    ; setup data segments
    mov ax, 0       ; can't write to ds/es directly
    mov ds, ax
    mov es, ax

    ; setup stack
    mov ss, ax
    mov sp, 0x7C00  ; stack grows downwards from where memory loads in, so start from beginning of operating system

    hlt ; stops CPU from executing (can be resumed with an interrupt)

.halt:
    jmp .halt ; jumpts to .halt unconditionally to form infinite loop if CPU starts again (can also juse use 'jmp $')

; fill rest of the 512 bytes with 00 and fill last 2 bytes with boot sector convention
times 510-($-$$) db 0
db 0x55, 0xaa

