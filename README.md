# BlissOS 16.9.7 (Android 13 Go, Kernel 6.1) on Lenovo Yoga Tablet 2 10.1" (`YT2-1050L` / `YT2-1050F`)

This repository contains the complete engineering guide, startup scripts, binary module patcher, and GRUB configuration for running **Android 13 (BlissOS 16.9.7 Go Edition, Linux kernel `6.1.112-gloria-xanmod1`)** on the **Lenovo Yoga Tablet 2 10.1"** (`YT2-1050L` LTE and `YT2-1050F` Wi-Fi, Intel Atom Z3745, 2 GB RAM) in a **dual-boot** configuration alongside Stock Android 5.0.1.

## Repository Contents

- **[`BLISSOS_YOGA_TAB_2.md`](BLISSOS_YOGA_TAB_2.md)** — **Full step-by-step technical guide** (rooting, dual-boot architecture, binary kernel patches, `libnativebridge` $2^N$ mount explosion fix, `s2idle` Wi-Fi fix, Wolfson WM5102 audio, IIO sensors, `fstab` SD card notification fix, Widevine L3 VOD setup, and Google Password Manager Autofill).
- **[`scripts/01-yoga2.sh`](scripts/01-yoga2.sh)** — Ready-to-use `initrd` startup hook script (`/bliss16/scripts/01-yoga2.sh`, `LF` line endings).
- **[`scripts/patch-modules.sh`](scripts/patch-modules.sh)** — Linux bash script that automatically applies the binary patches to `spi-pxa2xx-platform.ko`, `arizona.ko`, `st_accel_i2c.ko`, and `brcmfmac.ko`.
- **[`scripts/debloat-vod.sh`](scripts/debloat-vod.sh)** — Post-install ADB script for Tier 1 VOD debloating, disabling unneeded GMS background sync adapters, and enabling Google Password Manager Autofill.
- **[`grub/grub.cfg`](grub/grub.cfg)** — Dual-boot GRUB configuration for the ESP partition (`/EFI/BOOT/grub.cfg` and `/boot/grub/grub.cfg`).

## Quick Start

Read the full guide in **[`BLISSOS_YOGA_TAB_2.md`](BLISSOS_YOGA_TAB_2.md)**.
