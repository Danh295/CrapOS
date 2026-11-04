# CrapOS

A crappy little operating system in 16-bit x86 assembly. It boots from a floppy image through legacy BIOS, loads a second stage from disk, and drops you into a tiny shell.

```
CrapOS 0.1 - a crappy little OS
type 'help' if you dare.
crap> help
Commands:
  help    - this list
  reboot  - restart the machine
  clear   - wipe the screen
  crap    - say something unhelpful
crap> crap
[crap] 640 KB ought to be enough for anybody.
crap> x
that's not a command. nice try, genius.
crap>
```

(A typical session, with the text taken from QEMU's VGA text buffer. `crap` picks a line from the timer, so yours will differ.)

## How it works

- **Stage 1** (`src/stage1.asm`): the 512-byte boot sector. The BIOS loads it at `0x7C00`. It sets up the segments and stack, remembers the boot drive from `DL`, and reads 4 sectors from disk (`int 0x13`, with retries) to `0x7E00`, then jumps there.
- **Stage 2** (`src/stage2.asm`): the shell, at `0x7E00`, up to 2 KB. It reads keys with `int 0x16` into a 64-byte line buffer (with backspace), looks the line up in a command table, and runs it. The `crap` command picks its line from the BIOS tick counter (`int 0x1A`).
- Everything goes through BIOS interrupts, in real mode, for good. See [docs/adr/0001-real-mode-and-bios-only.md](docs/adr/0001-real-mode-and-bios-only.md).

## Build and run

Needs [NASM](https://www.nasm.us/) and [QEMU](https://www.qemu.org/) (`brew install nasm qemu` on macOS).

```
make          # build build/crapos.img (a 1.44 MB floppy image)
make run      # boot it in a QEMU window
make check    # boot headless, type some commands, assert what shows up on screen
make clean
```

You can also write `build/crapos.img` to a floppy or load it in VirtualBox as a floppy disk; I've only tested it in QEMU.

## Layout

```
src/stage1.asm   boot sector: loads stage 2 from disk
src/stage2.asm   the shell and its commands
scripts/boot-check.sh   headless QEMU boot test (reads the VGA text buffer)
docs/adr/        architecture decision records
```
