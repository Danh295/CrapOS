# Teaching notes

## How this learner wants to be taught
- Tightly scoped lessons that run alongside the build, explaining what we're doing.
- Grill style: make them decide what to build and why, then be critical of their answers and give feedback on the reasoning, not just the outcome. Do not be agreeable. If an answer has no concrete reason ("probably", "sounds cool"), say so.
- Don't fix their bugs for them. Let them predict, run it, and find the problem.
- Observe before teaching. Build and boot in QEMU, then teach what actually happened.

## Environment facts
- `nasm` and `qemu-system-i386` are at `/opt/homebrew/bin`. `make` builds `build/main_floppy.img`.
- `wiki.osdev.org` blocks the fetch tool (Cloudflare), so claims from it can't be verified here. The user's browser can open it.
- Screenshot a headless boot with `-display none -monitor stdio` and the monitor command `screendump`. The result is PPM.

## Open items
- MISSION.md "Why" is still a draft.
