#!/usr/bin/env python3
"""Boot tests for CrapOS: run the floppy image in headless QEMU and check the screen.

usage: tests/boot_tests.py [image] [-k substring] [--list]

How it works: each scenario starts its own QEMU with a QMP control socket. In BIOS
text mode the screen is memory (80x25 cells from physical 0xB8000, char + attribute),
so we read it with QMP `pmemsave` and decode the characters. Keys go in with QMP
`send-key`. We never sleep for a fixed time: we poll the screen until the expected
text shows up, or fail with the last screen after a timeout.

Exit codes: 0 all passed, 1 a test failed, 2 environment problem (no QEMU, no image).
Python 3 standard library only. See docs/research/qemu-boot-testing.md for why.
"""
import json
import os
import re
import shutil
import socket
import subprocess
import sys
import tempfile
import time
from pathlib import Path

QEMU = "qemu-system-i386"
ROOT = Path(__file__).resolve().parent.parent
VGA_ADDR = 0xB8000
VGA_BYTES = 80 * 25 * 2
BANNER = "CrapOS 0.1"
PROMPT = "crap>"
KEY_GAP = 0.06      # seconds between keys; must exceed HOLD_MS
HOLD_MS = 30        # how long QEMU holds each key down


class Fail(Exception):
    pass


class EnvError(Exception):
    pass


def prompt_count(screen):
    return sum(1 for line in screen.splitlines() if line.startswith(PROMPT))


class Vm:
    """One QEMU process under QMP control."""

    def __init__(self, args):
        self.tmp = tempfile.mkdtemp(prefix="crapos-test-")
        sock_path = os.path.join(self.tmp, "qmp.sock")
        self.err = open(os.path.join(self.tmp, "qemu.stderr"), "w+")
        self.proc = subprocess.Popen(
            [QEMU, "-display", "none", "-qmp", f"unix:{sock_path},server=on,wait=off"] + args,
            stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=self.err)
        self.sock = self._connect(sock_path)
        self.f = self.sock.makefile("rw", encoding="utf-8")
        self.f.readline()                       # QMP greeting
        self.qmp("qmp_capabilities")

    def _connect(self, path):
        deadline = time.time() + 10
        while time.time() < deadline:
            if self.proc.poll() is not None:
                raise Fail("QEMU exited at startup:\n" + self._stderr())
            try:
                s = socket.socket(socket.AF_UNIX)
                s.settimeout(10)
                s.connect(path)
                return s
            except OSError:
                s.close()
                time.sleep(0.05)
        raise Fail("could not connect to QEMU's QMP socket")

    def _stderr(self):
        self.err.flush()
        self.err.seek(0)
        return self.err.read().strip()

    def qmp(self, command, **arguments):
        msg = {"execute": command}
        if arguments:
            msg["arguments"] = arguments
        try:
            self.f.write(json.dumps(msg) + "\n")
            self.f.flush()
            while True:                          # skip async events until our reply
                line = self.f.readline()
                if not line:
                    raise Fail(f"QEMU closed the QMP connection during {command}")
                reply = json.loads(line)
                if "return" in reply:
                    return reply["return"]
                if "error" in reply:
                    raise Fail(f"QMP {command} failed: {reply['error']}")
        except (socket.timeout, OSError) as e:
            raise Fail(f"QMP {command} failed: {e}")

    def close(self):
        try:
            self.qmp("quit")
        except Exception:
            pass
        try:
            self.proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.proc.kill()
            self.proc.wait()
        try:
            self.sock.close()
        except OSError:
            pass
        self.err.close()
        shutil.rmtree(self.tmp, ignore_errors=True)

    # ---- screen -------------------------------------------------------------

    def screen(self):
        path = os.path.join(self.tmp, "vga.bin")
        self.qmp("pmemsave", val=VGA_ADDR, size=VGA_BYTES, filename=path)
        with open(path, "rb") as f:
            chars = f.read()[0::2]               # every other byte is a character
        lines = [chars[i:i + 80].decode("cp437").replace("\x00", " ").rstrip()
                 for i in range(0, 80 * 25, 80)]
        while lines and not lines[-1]:
            lines.pop()
        return "\n".join(lines)

    def wait_until(self, predicate, what, timeout=10):
        deadline = time.time() + timeout
        while True:
            screen = self.screen()
            if predicate(screen):
                return screen
            if time.time() > deadline:
                raise Fail(f"timed out after {timeout}s waiting for {what}\n"
                           f"--- screen ---\n{screen}\n--------------")
            time.sleep(0.1)

    def expect(self, text, timeout=10):
        return self.wait_until(lambda s: text in s, repr(text), timeout)

    def assert_absent(self, text):
        screen = self.screen()
        if text in screen:
            raise Fail(f"{text!r} should not be on screen\n--- screen ---\n{screen}\n--------------")

    # ---- keyboard -----------------------------------------------------------

    def type(self, text):
        for ch in text:
            key = {" ": "spc", "\n": "ret", "\b": "backspace"}.get(ch, ch)
            self.qmp("send-key", keys=[{"type": "qcode", "data": key}], **{"hold-time": HOLD_MS})
            time.sleep(KEY_GAP)

    def command(self, text, timeout=10):
        """Type a line and wait for the shell to print its next prompt."""
        before = prompt_count(self.screen())
        self.type(text + "\n")
        screen = self.wait_until(lambda s: prompt_count(s) == before + 1,
                                 f"a new prompt after {text!r}", timeout)
        # A command that falls through into the next one can restart the whole OS
        # (and still look like "output plus a prompt"), so insist the boot banner
        # is on screen exactly once: no restart, no unexpected clear.
        if screen.count(BANNER) != 1:
            raise Fail(f"after {text!r} the banner appears {screen.count(BANNER)} times "
                       f"(shell restarted or screen cleared?)\n{screen}")
        return screen

    def boot(self, timeout=15):
        return self.wait_until(lambda s: BANNER in s and PROMPT in s, "the banner and prompt", timeout)


# ---- machine configurations ----------------------------------------------------

def floppy(image, machine="pc"):
    return ["-machine", machine, "-drive", f"file={image},format=raw,if=floppy", "-boot", "a"]


def ide(image):
    return ["-machine", "pc", "-drive", f"file={image},format=raw,if=ide", "-boot", "c"]


def ide_read_error(image, sector=1):
    # blkdebug fails reads of one sector. This works for IDE but NOT for floppy:
    # QEMU's floppy controller swallows read errors and returns zeros.
    drive = (f"if=ide,format=raw,rerror=report,file.driver=blkdebug,file.image.filename={image},"
             f"file.inject-error.0.event=read_aio,file.inject-error.0.sector={sector}")
    return ["-machine", "pc", "-drive", drive, "-boot", "c"]


def crap_lines():
    """The lines the `crap` command can print, read from the stage 2 source."""
    source = (ROOT / "src" / "stage2.asm").read_text()
    lines = re.findall(r"^crap_\d+:\s*db\s*'([^']*)'", source, re.MULTILINE)
    if not lines:
        raise EnvError("could not find any crap_N lines in src/stage2.asm")
    return set(lines)


# ---- scenarios -----------------------------------------------------------------

def t_smoke(vm):
    vm.boot()


def t_help(vm):
    vm.boot()
    screen = vm.command("help")
    for expected in ("Commands:", "help    - this list", "reboot  - restart",
                     "clear   - wipe", "crap    - say"):
        if expected not in screen:
            raise Fail(f"help output is missing {expected!r}\n{screen}")


def t_unknown_and_empty(vm):
    vm.boot()
    vm.command("")                               # empty line: just a new prompt
    vm.assert_absent("not a command")
    screen = vm.command("x")
    if "not a command" not in screen:
        raise Fail(f"unknown command gave no complaint\n{screen}")


def t_backspace(vm):
    vm.boot()
    vm.command("hex\blp")                        # h e x <bs> l p  ->  "help"
    vm.expect("Commands:")
    vm.type("\b\b\b")                            # backspace on an empty line
    screen = vm.screen()
    if screen.splitlines()[-1] != PROMPT:
        raise Fail(f"backspace on an empty line damaged the prompt:\n{screen}")
    vm.command("help")                           # shell still fine


def t_overflow(vm):
    vm.boot()
    vm.type("a" * 70)                            # buffer holds 63; the rest are dropped
    screen = vm.wait_until(lambda s: "a" * 63 in s, "63 echoed characters")
    time.sleep(0.5)                              # let any (wrong) extra keys arrive
    screen = vm.screen()
    last = screen.splitlines()[-1]
    if last != "crap> " + "a" * 63:
        raise Fail(f"expected exactly 63 characters echoed, got:\n{last!r}")
    vm.type("\n")
    vm.wait_until(lambda s: "not a command" in s and prompt_count(s) == 2, "the unknown-command reply")
    vm.command("help")                           # still alive after the overflow


def t_clear(vm):
    vm.boot()
    vm.type("clear\n")
    screen = vm.wait_until(lambda s: BANNER not in s and PROMPT in s, "a cleared screen with a prompt")
    if screen.strip() != PROMPT:
        raise Fail(f"expected only a prompt after clear, got:\n{screen}")


def t_crap(vm):
    allowed = crap_lines()
    vm.boot()
    seen = []
    for _ in range(8):
        vm.type("clear\n")
        vm.wait_until(lambda s: BANNER not in s and prompt_count(s) == 1, "a cleared screen")
        vm.type("crap\n")
        screen = vm.wait_until(lambda s: prompt_count(s) == 2 and "[crap] " in s, "crap output")
        printed = [l for l in screen.splitlines() if l.startswith("[crap] ")]
        if len(printed) != 1 or printed[0] not in allowed:
            raise Fail(f"crap printed something not in the table: {printed!r}\n{screen}")
        seen.append(printed[0])
    print(f"      ({len(set(seen))} distinct lines in 8 runs)")


def t_reboot(vm):
    vm.boot()
    vm.type("reboot\n")
    vm.wait_until(lambda s: s.count(BANNER) == 2 and s.rfind(PROMPT) > s.rfind(BANNER),
                  "a second banner and prompt after reboot", 20)
    vm.expect("rebooting")


def t_disk_failure(vm):
    vm.expect("disk read failed", timeout=30)
    time.sleep(1)                                # stage 1 must have halted, not carried on
    screen = vm.screen()
    if BANNER in screen or PROMPT in screen:
        raise Fail(f"stage 2 ran despite the failed read:\n{screen}")


def scenarios(image):
    return [
        ("smoke: pc, floppy",           floppy(image),                t_smoke),
        ("smoke: isapc, floppy",        floppy(image, "isapc"),       t_smoke),
        ("smoke: q35, floppy",          floppy(image, "q35"),         t_smoke),
        ("smoke: IDE disk (boot drive 0x80)", ide(image),             t_smoke),
        ("help lists every command",    floppy(image),                t_help),
        ("unknown and empty commands",  floppy(image),                t_unknown_and_empty),
        ("backspace editing",           floppy(image),                t_backspace),
        ("64-byte buffer overflow",     floppy(image),                t_overflow),
        ("clear wipes the screen",      floppy(image),                t_clear),
        ("crap prints only table lines", floppy(image),               t_crap),
        ("reboot restarts the boot",    floppy(image),                t_reboot),
        ("disk read failure (IDE+blkdebug)", ide_read_error(image),   t_disk_failure),
    ]


def main(argv):
    image = ROOT / "build" / "crapos.img"
    pattern = None
    list_only = False
    args = list(argv)
    while args:
        a = args.pop(0)
        if a == "-k":
            pattern = args.pop(0)
        elif a == "--list":
            list_only = True
        else:
            image = Path(a)
    image = image.resolve()

    if list_only:
        for name, _, _ in scenarios(image):
            print(name)
        return 0
    if shutil.which(QEMU) is None:
        print(f"error: {QEMU} not found (brew install qemu / apt install qemu-system-x86)", file=sys.stderr)
        return 2
    if not image.is_file():
        print(f"error: image not found: {image} (run make)", file=sys.stderr)
        return 2

    failures = 0
    ran = 0
    for name, qemu_args, test in scenarios(image):
        if pattern and pattern not in name:
            continue
        ran += 1
        start = time.time()
        vm = None
        try:
            vm = Vm(qemu_args)
            test(vm)
            print(f"PASS  {name}  ({time.time() - start:.1f}s)")
        except Fail as e:
            failures += 1
            print(f"FAIL  {name}  ({time.time() - start:.1f}s)\n      " + str(e).replace("\n", "\n      "))
        except EnvError as e:
            print(f"error: {e}", file=sys.stderr)
            return 2
        finally:
            if vm is not None:
                vm.close()
    print(f"\n{ran - failures}/{ran} passed")
    return 1 if failures or ran == 0 else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
