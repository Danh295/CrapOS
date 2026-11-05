# Testing a real-mode boot sector under QEMU: research notes

Researched 2026-11-05 against primary sources (QEMU source on gitlab.com/qemu-project/qemu, other projects' own repos and CI configs). Local checks ran on QEMU 11.1.3, macOS. "Verified" means checked in the source or by running it; "inferred" means reasoned from source but not run.

## QEMU mechanisms

| Topic | Finding | Source | Status |
|---|---|---|---|
| QMP vs HMP | Scripts should use QMP. `human-monitor-command` is documented as "a stop-gap... highly discouraged... command names, arguments and responses can change or be removed at any time". | `qapi/misc.json` | Verified |
| QMP basics | `-qmp unix:PATH,server=on,wait=off`. Starts in capabilities mode: send `qmp_capabilities` first. | `qemu-options.hx`, `docs/interop/qmp-spec.rst` | Verified |
| Input | `send-key` takes `{"keys":[{"type":"qcode","data":"h"}]}`, default hold 100 ms. | `qapi/ui.json` | Verified |
| Reading the screen | `pmemsave` with `val=753664` (0xB8000), `size=4000`, `filename` dumps the VGA text buffer (char, attribute pairs). | `qapi/machine.json` | Verified, and run |
| Exit code from the guest | `isa-debug-exit`: a write to its port exits QEMU with `(val << 1) \| 1`. Not combinable with `-no-shutdown`. Needs guest code, so CrapOS doesn't use it. | `hw/misc/debugexit.c`, `system/runstate.c` | Verified in source |
| Serial / debugcon | `-serial file:` and `-device isa-debugcon,iobase=0xe9,chardev=...` give an output stream without scraping VGA. Needs guest code, so not used. | `qemu-options.hx`, `hw/char/debugcon.c` | Verified in source |
| Waiting without sleeps | QEMU's own tests read the console until a pattern matches (`wait_for_console_pattern`), with a failure pattern and a timeout. | `tests/functional/qemu_test/cmd.py` | Verified |
| Floppy fault injection | **Does not work.** On a failed read the floppy controller zero-fills the buffer and reports success. Injecting at sector 1: stage 1 jumped into zeros and hung. A 512-byte image hung silently; a 1024-byte image still reached the shell. | `hw/block/fdc.c`, ran it | Verified |
| IDE fault injection | **Works.** `-boot c -drive if=ide,format=raw,rerror=report,file.driver=blkdebug,file.image.filename=IMG,file.inject-error.0.event=read_aio,file.inject-error.0.sector=1` made stage 1 print `disk read failed`. | `qapi/block-core.json`, `block/blkdebug.c`, ran it | Verified |
| Machine types | `-machine isapc`, `pc` and `q35` all booted to the prompt from a floppy. QEMU ships SeaBIOS (rel-1.17.0 observed). | ran it | Verified |
| Deterministic ticks | `-icount shift=N,sleep=off` plus `-rtc base=...,clock=vm` should make the `int 0x1A` tick count repeatable. | `qemu-options.hx`, SeaBIOS `src/clock.c` | Inferred, not run |

## How other projects test boot code

- **Limine** reads VGA text memory at `0xB8000` and decodes it to text, plus QMP `screendump`. It waits for regex patterns with a scaled timeout, and SIGKILLs QEMU after a 20 s grace. https://raw.githubusercontent.com/limine-bootloader/limine/trunk/checks/harness/screen.py (also `qemu.py`, `api.py`)
- **GRUB** (`grub-shell`) uses `-nographic -serial file:/dev/stdout`, wraps the run in `timeout -s KILL`, and ends the VM with a guest `halt`. https://sources.debian.org/src/grub2/2.02%2Bdfsg1-20/tests/util/grub-shell.in
- **QEMU functional tests** assert on the guest serial console; default timeout 90 s. https://www.qemu.org/docs/master/devel/testing/functional.html
- **phil-opp (Writing an OS in Rust)** uses `isa-debug-exit` (exit code 33 means pass), `-serial stdio`, `-display none`. https://os.phil-opp.com/testing/
- **SerenityOS CI** boots a self-test mode, shuts down, then greps the disk image for `Failed: 0`. https://raw.githubusercontent.com/SerenityOS/serenity/master/.github/workflows/serenity-template.yml
- **hermit-os CI** installs `qemu-system-x86` with apt on ubuntu runners. https://raw.githubusercontent.com/hermit-os/kernel/main/.github/workflows/ci.yml
- **MikeOS** (a real-mode OS) is tested by hand only. https://mikeos.sourceforge.net/handbook-sysdev.html
- **GitHub-hosted Linux runners** can expose KVM, but a real-mode OS runs fine under QEMU's software CPU (TCG). https://github.blog/changelog/2024-04-02-github-actions-hardware-accelerated-android-virtualization-now-available/
- **Bochs** can run headless (`display_library: nogui`, `port_e9_hack`), but no primary source says it is more accurate than QEMU, and it has no documented auto-exit. https://bochs.sourceforge.io/doc/docbook/user/bochsrc.html

## What CrapOS does with this

Poll the VGA text buffer through QMP until a pattern appears (or time out), inject keys with `send-key`, one scripted QEMU boot per scenario. Disk failure is tested through IDE + `blkdebug`, with an un-injected IDE boot as the negative control. Smoke boots on `pc`, `isapc`, `q35`.

Not done, on purpose: `isa-debug-exit`/`debugcon` (needs guest changes), Bochs, real hardware, deterministic ticks, and a "fail once then retry succeeds" test (SeaBIOS might retry IDE reads itself, so it could pass without exercising our retry loop).

## Unverified

- That Ubuntu's `qemu-system-x86` package provides the `qemu-system-i386` binary.
- That an out-of-geometry floppy read would fail (a possible floppy failure trigger).
- That `-icount`/`-rtc` makes `int 0x1A` ticks repeatable in practice.
