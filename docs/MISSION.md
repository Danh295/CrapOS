# Mission: Finish CrapOS (16-bit real-mode OS with a second stage)

## Why
Understand every line. Take a half-finished boot sector and turn it into a small, silly, distinctive OS the user can honestly explain line by line. Understanding and silliness matter more than polish.

## Success looks like
- CrapOS boots in QEMU from `make`, with no known bugs in the stage 1 and stage 2 sources.
- The boot sector loads stage 2 from disk (4 sectors, starting at disk sector 2, read to `0x7E00`) using BIOS `int 0x13`, then jumps to it.
- Stage 2 reads keystrokes (`int 0x16`) into a 64-byte line buffer, with backspace and Enter, and runs exactly four commands:
  - `help`: lists the commands.
  - `reboot`: restarts via `int 0x19`.
  - `crap`: prints a silly line from a small table, picked with the BIOS tick count (`int 0x1A`).
  - `clear`: clears the screen by resetting the video mode (`int 0x10`).
- The user can explain every line of the code and say why each design decision was made.

Anything beyond those four commands is a stretch goal.

## Constraints
- Short, tightly scoped lessons delivered as the OS is built.
- The user wants to be forced to make decisions, then be corrected when wrong. Teaching style is recorded in `NOTES.md`.
- No deadline stated. Stays in 16-bit real mode, assembled with NASM, tested in QEMU.
- Build layout: `stage1.bin` (exactly 512 bytes) and `stage2.bin` (padded to 4 sectors) are concatenated and padded to a 1440k floppy image.

## Out of scope
- Protected mode, a C kernel and cross-compilers. This is permanent; see `adr/0001-real-mode-and-bios-only.md`.
- Real filesystems (FAT, etc.).
- VirtualBox and real-hardware testing.
