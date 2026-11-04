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
	cat $^ > $@
	truncate -s 1440k $@

# Boot in a QEMU window.
run: $(IMG)
	qemu-system-i386 -drive file=$(IMG),format=raw,if=floppy

# Boot headless and assert what shows up on screen. BOOT_KEYS types keys after boot.
check: $(IMG)
	scripts/boot-check.sh $(IMG) "CrapOS 0.1" "crap>"
	BOOT_KEYS="h e l p ret" scripts/boot-check.sh $(IMG) "Commands:" "reboot  - restart" "clear   - wipe" "crap    - say"
	BOOT_KEYS="c r a p ret x ret" scripts/boot-check.sh $(IMG) "[crap] " "not a command"

clean:
	rm -rf $(BUILD_DIR)
