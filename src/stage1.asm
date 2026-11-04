; CrapOS stage 1: the 512-byte boot sector.
; The BIOS loads this sector at physical 0x7C00 and jumps to it in 16-bit real mode.
; It loads stage 2 (4 sectors, starting at disk sector 2) to 0x7E00 and jumps there.
org 0x7C00
bits 16

%define ENDL 0x0D, 0x0A

; Execution starts at byte 0 of the sector, so jump over the helper routine to main.
; Everything (code and data) must fit in this one sector, before the 55 AA signature.
jmp main

; puts: print the null-terminated string at ds:si via BIOS teletype (int 0x10, AH=0x0E).
; Preserves si, ax, bx.
puts:
    push si
    push ax
    push bx
.loop:
    lodsb                ; AL = [DS:SI], then SI++
    or al, al
    jz .done             ; null terminator: finished
    mov ah, 0x0E
    mov bh, 0            ; video page 0
    int 0x10
    jmp .loop
.done:
    pop bx
    pop ax
    pop si
    ret

main:
    ; The BIOS leaves the boot drive number in DL. Save it before anything can clobber it.
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov [boot_drive], dl

    ; Stack grows downward from just below this code.
    mov ss, ax
    mov sp, 0x7C00
    cld

    mov di, 3            ; attempts. Floppies are flaky, so retry, resetting the controller between
.retry:
    mov ah, 0x02         ; int 0x13 AH=02h: read sectors
    mov al, 4            ; sector count (stage 2 is 4 sectors = 2048 bytes)
    mov ch, 0            ; cylinder 0
    mov cl, 2            ; sector 2 (CHS sectors start at 1; sector 1 is this boot sector)
    mov dh, 0            ; head 0
    mov dl, [boot_drive]
    mov bx, 0x7E00       ; ES:BX = destination, right after this sector
    int 0x13
    jnc .loaded          ; carry clear = success

    xor ah, ah           ; AH=00h: reset the disk system
    mov dl, [boot_drive]
    int 0x13
    dec di
    jnz .retry

    mov si, msg_fail
    call puts
.halt:
    hlt
    jmp .halt

.loaded:
    mov dl, [boot_drive] ; hand the boot drive on to stage 2
    jmp 0x0000:0x7E00

boot_drive: db 0
msg_fail:   db 'disk read failed', ENDL, 0

; pad to 510 bytes and add the boot signature the BIOS looks for
times 510 - ($ - $$) db 0
db 0x55, 0xAA
