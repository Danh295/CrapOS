SRC_DIR=src
BUILD_DIR=build
IMG=$(BUILD_DIR)/crapos.img

.PHONY: all run check clean
.DELETE_ON_ERROR:

all: $(IMG)

$(BUILD_DIR)/%.bin: $(SRC_DIR)/%.asm
	@mkdir -p $(BUILD_DIR)
	nasm $< -f bin -o $@

# Stage 1 (the boot sector, exactly 512 bytes) followed by stage 2 (4 sectors), padded to a 1.44 MB floppy.
$(IMG): $(BUILD_DIR)/stage1.bin $(BUILD_DIR)/stage2.bin
	@test $$(( $$(wc -c < $(BUILD_DIR)/stage1.bin) )) -eq 512 || { echo "stage1.bin must be exactly 512 bytes"; exit 1; }
	@test $$(( $$(wc -c < $(BUILD_DIR)/stage2.bin) )) -eq 2048 || { echo "stage2.bin must be exactly 2048 bytes"; exit 1; }
	@test "$$(od -An -tx1 -j510 -N2 $(BUILD_DIR)/stage1.bin | tr -d ' \n')" = "55aa" || { echo "stage1.bin must end with the boot signature 55 AA"; exit 1; }
	cat $^ > $@
	truncate -s 1440k $@

# Boot in a QEMU window.
run: $(IMG)
	qemu-system-i386 -drive file=$(IMG),format=raw,if=floppy

# Run the boot tests: headless QEMU, drives the shell through QMP, asserts on screen text.
# Run one scenario with: python3 tests/boot_tests.py -k backspace
check: $(IMG)
	python3 tests/boot_tests.py $(IMG)

clean:
	rm -rf $(BUILD_DIR)
