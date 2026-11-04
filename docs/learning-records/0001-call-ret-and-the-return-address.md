# call pushes a return address; only ret uses it

The learner first believed `call` pushes the argument registers and that the `pop`s consume the return address. After the stack diagram and the `IP` walkthrough, they added `ret` to `puts` themselves and it fixed the loop (verified in QEMU: `ESP=0x7C00`, `EIP` parked at the halt loop).

**Evidence:** a working `ret` in `src/main.asm`. They still haven't restated, unprompted, why `ret` is needed. Re-check later by asking what happens if `push`es and `pop`s are unbalanced.

**Implications:** safe to build on `call`/`ret` and the stack for the `int 0x13` helper. Also picked address `0x7E00` for the second stage, but with only one of three eliminations justified (boot-sector overlap).
