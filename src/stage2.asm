; CrapOS stage 2: a tiny shell. Loaded at 0x7E00 by stage 1 (4 sectors = 2048 bytes max).
; All I/O goes through BIOS interrupts: int 0x10 (video), 0x16 (keyboard), 0x1A (timer), 0x19 (reboot).
org 0x7E00
bits 16

%define ENDL 0x0D, 0x0A
%define LINE_MAX 63              ; buffer is 64 bytes: 63 characters + the null terminator

start:
    cld                          ; lodsb counts upward
    mov si, msg_banner
    call puts

shell:
    mov si, msg_prompt
    call puts
    mov bx, buf
    call readline                ; buf = typed line, null-terminated
    cmp byte [buf], 0
    je shell                     ; empty line: just prompt again

    mov bx, commands             ; walk the table of (name pointer, handler) pairs
.next:
    mov di, [bx]
    test di, di
    jz .unknown                  ; end of table: no such command
    mov si, buf
    call strcmp
    je .run
    add bx, 4
    jmp .next
.run:
    call [bx + 2]
    jmp shell
.unknown:
    mov si, msg_unknown
    call puts
    jmp shell

; ---------------------------------------------------------------- commands

cmd_help:
    mov si, msg_help
    call puts
    ret

cmd_reboot:
    mov si, msg_reboot
    call puts
    int 0x19                     ; BIOS: restart the boot process
    jmp $                        ; not reached

cmd_clear:
    mov ax, 0x0003               ; set 80x25 text mode again, which clears the screen
    int 0x10
    ret

cmd_crap:
    xor ah, ah
    int 0x1A                     ; CX:DX = BIOS timer ticks since midnight (18.2 per second)
    mov ax, dx
    xor dx, dx
    mov cx, CRAP_COUNT
    div cx                       ; DX = ticks mod number of lines
    shl dx, 1                    ; table entries are 2 bytes
    mov bx, dx
    mov si, [crap_table + bx]
    call puts
    ret

; ---------------------------------------------------------------- routines

; putc: print the character in AL (teletype). Preserves all registers.
putc:
    push ax
    push bx
    mov ah, 0x0E
    xor bh, bh                   ; video page 0
    mov bl, 7                    ; light grey (only used in graphics modes)
    int 0x10
    pop bx
    pop ax
    ret

; puts: print the null-terminated string at ds:si. Preserves registers.
puts:
    push si
    push ax
.loop:
    lodsb
    test al, al
    jz .done
    call putc
    jmp .loop
.done:
    pop ax
    pop si
    ret

; readline: read a line from the keyboard into the buffer at bx (null-terminated).
; Printable keys are echoed and stored, up to LINE_MAX. Backspace erases. Enter ends.
readline:
    push ax
    push cx
    push si
    xor cx, cx                   ; cx = characters typed so far
.key:
    xor ah, ah
    int 0x16                     ; wait for a key; AL = ASCII
    cmp al, 0x0D
    je .enter
    cmp al, 0x08
    je .back
    cmp al, 0x20
    jb .key                      ; ignore other control keys
    cmp al, 0x7E
    ja .key
    cmp cx, LINE_MAX
    jae .key                     ; buffer full: drop the key
    mov si, cx
    mov [bx + si], al
    inc cx
    call putc
    jmp .key
.back:
    test cx, cx
    jz .key                      ; nothing to erase
    dec cx
    mov al, 0x08                 ; cursor left, overwrite with a space, cursor left again
    call putc
    mov al, ' '
    call putc
    mov al, 0x08
    call putc
    jmp .key
.enter:
    mov si, cx
    mov byte [bx + si], 0
    mov al, 0x0D
    call putc
    mov al, 0x0A
    call putc
    pop si
    pop cx
    pop ax
    ret

; strcmp: compare the null-terminated strings at ds:si and ds:di. ZF=1 if equal.
strcmp:
    push si
    push di
    push ax
.loop:
    mov al, [si]
    cmp al, [di]
    jne .done                    ; differ: ZF=0
    inc si
    inc di
    test al, al                  ; both ended together: ZF=1
    jnz .loop
.done:
    pop ax                       ; pop does not touch the flags
    pop di
    pop si
    ret

; ---------------------------------------------------------------- data

msg_banner:  db 'CrapOS 0.1 - a crappy little OS', ENDL
             db "type 'help' if you dare.", ENDL, 0
msg_prompt:  db 'crap> ', 0
msg_unknown: db "that's not a command. nice try, genius.", ENDL, 0
msg_reboot:  db 'rebooting. try not to miss me.', ENDL, 0
msg_help:    db 'Commands:', ENDL
             db '  help    - this list', ENDL
             db '  reboot  - restart the machine', ENDL
             db '  clear   - wipe the screen', ENDL
             db '  crap    - say something unhelpful', ENDL, 0

name_help:   db 'help', 0
name_reboot: db 'reboot', 0
name_clear:  db 'clear', 0
name_crap:   db 'crap', 0

commands:
    dw name_help,   cmd_help
    dw name_reboot, cmd_reboot
    dw name_clear,  cmd_clear
    dw name_crap,   cmd_crap
    dw 0, 0                      ; end of table

crap_0: db '[crap] this OS runs on 2 KB and sheer stubbornness.', ENDL, 0
crap_1: db '[crap] have you tried turning it off and on? (try: reboot)', ENDL, 0
crap_2: db '[crap] segmentation fault is not a bug. it is real mode.', ENDL, 0
crap_3: db '[crap] 640 KB ought to be enough for anybody.', ENDL, 0
crap_4: db '[crap] i would call this a kernel but nobody is that cruel.', ENDL, 0

crap_table: dw crap_0, crap_1, crap_2, crap_3, crap_4
CRAP_COUNT equ ($ - crap_table) / 2

buf: times LINE_MAX + 1 db 0

; pad to exactly 4 sectors; the assembler errors out if stage 2 outgrows them
times 2048 - ($ - $$) db 0
