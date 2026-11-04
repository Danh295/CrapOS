# CrapOS Resources

## Knowledge

- [Wikipedia: Real mode](https://en.wikipedia.org/wiki/Real_mode)
  20-bit segmented addressing, the 1 MB limit, no memory protection. Use for: addressing arithmetic, why real mode feels cramped.
- [Wikipedia: BIOS interrupt call](https://en.wikipedia.org/wiki/BIOS_interrupt_call)
  How `int` + `AH` calls firmware services, and the table of interrupt numbers. Use for: "what is int 0x10/0x13/0x16".
- [Wikipedia: Booting](https://en.wikipedia.org/wiki/Booting)
  Boot sector loaded at linear 0x7C00, the `AA55h` signature, first-stage vs second-stage loaders. Use for: why a second stage exists.
- [Ralf Brown's Interrupt List: Int 10/AH=0Eh](https://mirror.cs.msu.ru/oldlinux.org/Linux.old/docs/interrupts/int-html/rb-0106.htm)
  Register-level spec for teletype output. This is a third-party mirror of an old release. Use for: exact register inputs of a BIOS call.
- [Ralf Brown's Interrupt List: Int 13/AH=02h](https://mirror.cs.msu.ru/oldlinux.org/Linux.old/docs/interrupts/int-html/rb-0607.htm)
  Read-sectors call, with the advice to retry floppy reads three times. Use for: the disk-loading lesson.
- [Ralf Brown's Interrupt List: Int 16/AH=00h](https://mirror.cs.msu.ru/oldlinux.org/Linux.old/docs/interrupts/int-html/rb-1754.htm)
  Wait-for-keystroke call; returns scan code in AH and ASCII in AL. Use for: the shell lesson.
- [OSDev Wiki](https://wiki.osdev.org/) (Real Mode, BIOS, Boot Sequence, Bootloader pages)
  The canonical hobby-OS reference. It blocked automated fetching, so no claim in a lesson is cited to it yet. Open it in a browser and use it to cross-check.
- [nanobyte-dev/nanobyte_os](https://github.com/nanobyte-dev/nanobyte_os) (code for the "Building an OS" video series)
  A worked example of a NASM bootloader and kernel. Not yet checked line by line against this repo. Use for: seeing how another author structures the same steps.

## Wisdom (Communities)

- [OSDev Forums](https://forum.osdev.org/)
  Long-running hobby OS community. Not yet vetted for moderation quality. Use for: getting code reviewed by people who have written real boot code.

## Gaps

- The value of `DL` at boot (boot drive number) is not yet verified against a source I could read. Needed before the `int 0x13` lesson.
- No primary source yet for floppy geometry (CHS) and how to compute it. Needed for the second-stage loading lesson.
