#!/usr/bin/env bash
# Boot a floppy image headless in QEMU, dump the screen text, and check it.
#
# usage: scripts/boot-check.sh <image> <expected text>...
#   exits 0 if every expected string appears on screen, 1 otherwise.
#   BOOT_WAIT=<seconds> changes how long we let the VM run before looking (default 3).
#
# How it works: in BIOS text mode the screen IS memory. 80x25 cells starting at
# physical 0xB8000, 2 bytes per cell (character byte, then attribute byte).
# So we ask QEMU's monitor to save that RAM to a file and read the characters back.
set -euo pipefail

if [ "$#" -lt 2 ]; then
    echo "usage: $0 <image> <expected text>..." >&2
    exit 2
fi
image=$1; shift

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# Send monitor commands on stdin: wait for the BIOS + our code to run, dump, quit.
{
    sleep "${BOOT_WAIT:-3}"
    # The filename is quoted on purpose: unquoted, the monitor's expression parser
    # reads "4000 /var/..." as 4000 divided by something.
    echo "pmemsave 0xb8000 4000 \"$work/vga.bin\""
    sleep 1
    echo "quit"
} | qemu-system-i386 -fda "$image" -display none -monitor stdio >/dev/null 2>&1

python3 -I - "$work/vga.bin" "$@" <<'EOF'
import sys
data = open(sys.argv[1], "rb").read()
chars = data[0::2]                       # every other byte is a character
lines = [chars[i:i + 80].decode("cp437", "replace").rstrip() for i in range(0, 2000, 80)]
while lines and not lines[-1]:
    lines.pop()
screen = "\n".join(lines)
print("--- screen ---")
print(screen)
print("--------------")
missing = [e for e in sys.argv[2:] if e not in screen]
for e in missing:
    print(f"FAIL: expected text not on screen: {e!r}")
if not missing:
    print("PASS")
sys.exit(1 if missing else 0)
EOF
