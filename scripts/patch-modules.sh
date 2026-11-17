#!/usr/bin/env bash
# Binary patcher for BlissOS 16.9.7 (kernel 6.1.112-gloria-xanmod1) modules
# Target device: Lenovo Yoga Tablet 2 10.1" (YT2-1050L / YT2-1050F)

set -euo pipefail

MOD_DIR="${1:-./modules}"

for m in spi-pxa2xx-platform.ko arizona.ko st_accel_i2c.ko brcmfmac.ko; do
    if [ ! -f "$MOD_DIR/$m" ]; then
        echo "ERROR: Missing $MOD_DIR/$m" >&2
        echo "Extract the 4 unpatched .ko files from system.efs (/system/lib/modules/6.1.112-gloria-xanmod1/kernel/...) into $MOD_DIR first." >&2
        exit 1
    fi
done

echo "[1/4] Patching spi-pxa2xx-platform.ko (force hardware CS0 for Wolfson WM5102)..."
printf '\x31\xc0\x90\x90\x90\x90' | dd of="$MOD_DIR/spi-pxa2xx-platform.ko" bs=1 seek=$((0x20c6)) conv=notrunc status=none
printf '\x31\xd2\x90\x90\x90\x90\x90' | dd of="$MOD_DIR/spi-pxa2xx-platform.ko" bs=1 seek=$((0x342f)) conv=notrunc status=none

echo "[2/4] Patching arizona.ko (bypass Bay Trail IRQ probe abort in arizona_dev_init)..."
printf '\x0d\x00' | dd of="$MOD_DIR/arizona.ko" bs=1 seek=$((0x12abf)) conv=notrunc status=none

echo "[3/4] Patching st_accel_i2c.ko (add 'lsm9ds0' I2C ID at 0x1d)..."
printf 'lsm9ds0\x00' | dd of="$MOD_DIR/st_accel_i2c.ko" bs=1 seek=$((0x1790)) conv=notrunc status=none

echo "[4/4] Patching brcmfmac.ko (force MMC_PM_KEEP_POWER=0x1 during s2idle suspend/resume)..."
printf '\x90\x90\x90\x90\x90\x90' | dd of="$MOD_DIR/brcmfmac.ko" bs=1 seek=$((0x4376e)) conv=notrunc status=none
printf '\x41\xbe\x01\x00\x00\x00' | dd of="$MOD_DIR/brcmfmac.ko" bs=1 seek=$((0x438bb)) conv=notrunc status=none
printf '\x90\x90' | dd of="$MOD_DIR/brcmfmac.ko" bs=1 seek=$((0x43961)) conv=notrunc status=none

chmod 644 "$MOD_DIR"/*.ko

echo "Done! Checksums:"
md5sum "$MOD_DIR"/*.ko
