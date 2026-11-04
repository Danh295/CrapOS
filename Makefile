SRC_DIR=src
BUILD_DIR=build
IMG=$(BUILD_DIR)/main_floppy.img

.PHONY: run check

$(IMG): ${BUILD_DIR}/main.bin
	cp ${BUILD_DIR}/main.bin $(IMG)
	truncate -s 1440k $(IMG)

$(BUILD_DIR)/main.bin: $(SRC_DIR)/main.asm
	@mkdir -p $(BUILD_DIR)
	nasm $(SRC_DIR)/main.asm -f bin -o $(BUILD_DIR)/main.bin

# Boot in a QEMU window.
run: $(IMG)
	qemu-system-i386 -fda $(IMG)

# Boot headless and assert the screen shows the expected text (our feedback loop).
check: $(IMG)
	scripts/boot-check.sh $(IMG) "Hello world!"
