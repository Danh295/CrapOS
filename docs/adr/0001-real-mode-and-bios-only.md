# CrapOS stays in real mode and uses BIOS for all I/O

CrapOS runs in 16-bit real mode for its whole life and does every piece of I/O through BIOS interrupts (`int 0x10`, `0x13`, `0x16`, `0x19`, `0x1A`). Protected mode, a C kernel and a cross-compiler are permanently out of scope.

**Considered options:** switching to 32-bit protected mode (needs a GDT, our own drivers, and usually a C toolchain), or leaving protected mode as a stretch goal.

**Why:** the project exists to understand every line, and BIOS services keep the whole OS small enough to read in one sitting. Leaving the door open invites "one more feature needs a mode switch" scope creep, and BIOS calls stop working once the CPU leaves real mode.

**Consequences:** the OS is limited to 1 MB of addressable memory and the BIOS's slow, blocking drivers. Any future idea that needs protected mode is a different project, not a CrapOS feature.
