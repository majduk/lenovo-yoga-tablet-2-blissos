# Yoga Tablet 2 (YT2-1050L / YT2-1050F) initrd hook for BlissOS 16

yoga_early_prep()
{
	[ -n "$_YOGA_EARLY_DONE" ] && return 0
	_YOGA_EARLY_DONE=1

	# 1. Bind-mount patched kernel modules BEFORE auto_detect/load_modules
	MODSRC=""
	for d in /src/modules /mnt/bliss16/modules; do
		[ -d "$d" ] && MODSRC="$d" && break
	done
	if [ -n "$MODSRC" ] && [ -d /android/system/lib/modules ]; then
		mkdir -p /tmp/yoga_mods
		for m in arizona.ko spi-pxa2xx-platform.ko st_accel_i2c.ko brcmfmac.ko; do
			if [ -f "$MODSRC/$m" ]; then
				cp "$MODSRC/$m" "/tmp/yoga_mods/$m"
				chmod 644 "/tmp/yoga_mods/$m"
				tgt=$(busybox find /android/system/lib/modules -name "$m" 2>/dev/null | busybox head -n 1)
				if [ -n "$tgt" ]; then
					mount --bind "/tmp/yoga_mods/$m" "$tgt" 2>/dev/null || true
				fi
			fi
		done
	fi

	# 2. Prepare Broadcom Wi-Fi & BT firmware BEFORE auto_detect loads brcmfmac/hci_uart
	for r in /sys/class/rfkill/*; do
		[ -e "$r/state" ] && echo 1 > "$r/state" 2>/dev/null || true
	done

	FWSRC=""
	for d in /src/firmware/brcm /mnt/bliss16/firmware/brcm; do
		[ -d "$d" ] && FWSRC="$d" && break
	done

	mkdir -p /tmp/fw_yoga/brcm
	if [ -f /android/vendor/firmware/brcm/brcmfmac43241b4-sdio.bin.zst ]; then
		cp /android/vendor/firmware/brcm/brcmfmac43241b4-sdio.bin.zst /tmp/fw_yoga/brcm/brcmfmac43241b4-sdio.bin.zst
	elif [ -n "$FWSRC" ] && [ -f "$FWSRC/brcmfmac43241b4-sdio.bin.fallback" ]; then
		cp "$FWSRC/brcmfmac43241b4-sdio.bin.fallback" /tmp/fw_yoga/brcm/brcmfmac43241b4-sdio.bin
	fi

	if [ -n "$FWSRC" ] && [ -f "$FWSRC/brcmfmac43241b4-sdio.txt" ]; then
		cp "$FWSRC/brcmfmac43241b4-sdio.txt" /tmp/fw_yoga/brcm/brcmfmac43241b4-sdio.txt
		cp /tmp/fw_yoga/brcm/brcmfmac43241b4-sdio.txt "/tmp/fw_yoga/brcm/brcmfmac43241b4-sdio.Intel Corp.-VALLEYVIEW C0 PLATFORM.txt"
	fi
	if [ -n "$FWSRC" ] && [ -f "$FWSRC/BCM4324B3.hcd" ]; then
		cp "$FWSRC/BCM4324B3.hcd" /tmp/fw_yoga/brcm/BCM4324B3.hcd
		cp "$FWSRC/BCM4324B3.hcd" /tmp/fw_yoga/brcm/BCM.hcd
	fi

	chmod 755 /tmp/fw_yoga /tmp/fw_yoga/brcm
	chmod 644 /tmp/fw_yoga/brcm/* 2>/dev/null || true

	echo -n "/tmp/fw_yoga" > /sys/module/firmware_class/parameters/path 2>/dev/null || true
	rm -f /lib/firmware 2>/dev/null || true
	ln -s /tmp/fw_yoga /lib/firmware
}

# Run early prep immediately during initrd source (before load_modules/auto_detect)
yoga_early_prep

post_detect()
{
	DIAG=/android/data/boot_diag
	mkdir -p "$DIAG"
	chmod 777 "$DIAG"

	{
		echo "=== uname ==="
		uname -a
		echo "=== cmdline ==="
		cat /proc/cmdline

		echo "=== modprobe i915 ==="
		busybox modprobe -v i915 modeset=1 2>&1
		echo "modprobe i915 rc=$?"

		i=0
		while [ $i -lt 3 ]; do
			[ -e /dev/dri/card0 ] && break
			sleep 1
			i=$((i + 1))
		done

		echo "=== modprobe x86-android-tablets & touch ==="
		busybox modprobe -v x86-android-tablets 2>&1
		echo "modprobe x86-android-tablets rc=$?"
		busybox modprobe -v rmi_core 2>&1
		busybox modprobe -v rmi_i2c 2>&1
		echo "modprobe rmi_i2c rc=$?"

		echo "=== verify patched kernel modules & reload WM5102 in power-on order ==="
		ls -la /tmp/yoga_mods 2>&1
		busybox rmmod arizona_spi 2>/dev/null || true
		busybox rmmod arizona 2>/dev/null || true
		busybox rmmod spi_pxa2xx_platform 2>/dev/null || true
		busybox rmmod st_accel_i2c 2>/dev/null || true
		busybox rmmod st_accel 2>/dev/null || true
		busybox rmmod st_sensors 2>/dev/null || true
		busybox rmmod snd_sof_acpi_intel_byt 2>/dev/null || true

		echo "=== modprobe WM5102 audio ==="
		busybox modprobe -v arizona-ldo1 2>&1
		busybox modprobe -v arizona-micsupp 2>&1
		busybox modprobe -v gpio-arizona 2>&1
		busybox modprobe -v snd-soc-wm5102 2>&1
		busybox modprobe -v spi-pxa2xx-platform 2>&1
		busybox modprobe -v arizona-spi 2>&1

		i=0
		while [ $i -lt 3 ]; do
			[ -e /sys/bus/spi/devices/spi-10WM5102:00/driver ] && break
			sleep 1
			i=$((i + 1))
		done

		busybox modprobe -v snd-soc-sst-bytcr-wm5102 2>&1
		echo "asound cards:"
		cat /proc/asound/cards 2>&1

		if [ -e /android/data/vendor/asound.state ] && [ ! -s /android/data/vendor/asound.state ]; then
			echo "Removing 0-byte /android/data/vendor/asound.state"
			rm -f /android/data/vendor/asound.state
		fi

		echo "=== modprobe I2C sensors (al3320a + lsm9ds0/LSM303D) ==="
		busybox modprobe -v al3320a 2>&1
		busybox modprobe -v st_accel_i2c 2>&1
		i=0
		while [ $i -lt 3 ]; do
			[ -e /sys/bus/i2c/devices/i2c-4/new_device ] && break
			sleep 1
			i=$((i + 1))
		done
		if [ -e /sys/bus/i2c/devices/i2c-4/new_device ]; then
			[ ! -e /sys/bus/i2c/devices/4-001c ] && echo al3320a 0x1c > /sys/bus/i2c/devices/i2c-4/new_device 2>&1
			[ ! -e /sys/bus/i2c/devices/4-001d ] && echo lsm9ds0 0x1d > /sys/bus/i2c/devices/i2c-4/new_device 2>&1
		fi
		i=0
		while [ $i -lt 2 ]; do
			ls /sys/bus/iio/devices/iio:device*/in_accel_x_raw >/dev/null 2>&1 && break
			sleep 1
			i=$((i + 1))
		done
		grep . /sys/bus/iio/devices/iio:device*/name 2>&1 || true
		for f in /sys/bus/iio/devices/iio:device*/sampling_frequency; do
			[ -e "$f" ] && echo 100 > "$f" 2>/dev/null || true
		done

		echo "=== modprobe usb gadget & extcon ==="
		busybox modprobe -v extcon-intel-int3496 2>&1
		busybox modprobe -v extcon-axp288 2>&1
		busybox modprobe -v libcomposite 2>&1
		busybox modprobe -v usb_f_rndis 2>&1
		mdev -s 2>&1

		echo "=== wifi & bt firmware check ==="
		rm -rf /android/data/bliss16/fw_runtime 2>/dev/null || true
		mkdir -p /android/data/bliss16/fw_runtime
		cp -a /tmp/fw_yoga/. /android/data/bliss16/fw_runtime/ 2>/dev/null || true

		ls -la /tmp/fw_yoga/brcm 2>&1
		df -h /tmp /android/data 2>&1
		echo "fw_path=$(cat /sys/module/firmware_class/parameters/path 2>&1)"

		# Wait briefly for early-probed wlan0, only recover if missing
		i=0
		while [ $i -lt 3 ]; do
			[ -e /sys/class/net/wlan0 ] && break
			sleep 1
			i=$((i + 1))
		done
		if [ ! -e /sys/class/net/wlan0 ]; then
			echo "wlan0 missing after auto_detect, retrying brcmfmac..."
			for r in /sys/class/rfkill/*; do
				[ -e "$r/state" ] && echo 0 > "$r/state" 2>/dev/null || true
			done
			busybox rmmod brcmfmac 2>/dev/null || true
			sleep 1
			for r in /sys/class/rfkill/*; do
				[ -e "$r/state" ] && echo 1 > "$r/state" 2>/dev/null || true
			done
			sleep 1
			busybox modprobe -v brcmfmac 2>&1
			sleep 2
		fi
		if [ ! -e /sys/class/bluetooth/hci0 ]; then
			busybox modprobe -v hci_uart 2>&1
			sleep 1
		fi

		echo "=== net & bluetooth status ==="
		ls -la /sys/class/net /sys/class/bluetooth 2>&1
		echo "wlan0 mac: $(cat /sys/class/net/wlan0/address 2>&1)"

		echo "=== zram setup (1.0 GiB lz4) ==="
		if [ -e /sys/block/zram0 ]; then
			busybox modprobe -v lz4 2>&1 || true
			busybox swapoff /dev/block/zram0 2>/dev/null || true
			busybox swapoff /dev/zram0 2>/dev/null || true
			echo 1 > /sys/block/zram0/reset 2>/dev/null || true
			echo lz4 > /sys/block/zram0/comp_algorithm 2>&1 || true
			echo 1073741824 > /sys/block/zram0/disksize 2>&1
			mdev -s 2>&1
			if [ ! -e /dev/block/zram0 ] && [ -e /dev/zram0 ]; then
				ln -s /dev/zram0 /dev/block/zram0
			fi
			ZDEV=""
			for d in /dev/block/zram0 /dev/zram0; do
				[ -b "$d" ] && ZDEV="$d" && break
			done
			if [ -n "$ZDEV" ]; then
				busybox mkswap "$ZDEV" 2>&1
				busybox swapon "$ZDEV" 2>&1
			fi
			cat /proc/swaps 2>&1
			cat /sys/block/zram0/comp_algorithm 2>&1
		fi

		echo "=== usb udc / role / extcon check ==="
		ls -la /sys/class/udc /sys/class/usb_role /sys/class/extcon 2>&1
		for r in /sys/class/usb_role/*; do
			if [ -e "$r/role" ]; then
				cur=$(cat "$r/role" 2>/dev/null)
				echo "usb_role $r current=$cur"
				if [ "$cur" = "none" ]; then
					echo device > "$r/role" 2>&1 || true
					echo "usb_role $r after=$(cat "$r/role" 2>/dev/null)"
				fi
			fi
		done
		for e in /sys/class/extcon/*; do
			[ -e "$e/state" ] && echo "extcon $e: $(cat "$e/state" 2>/dev/null)"
		done

		echo "=== drm & fb check ==="
		ls -la /dev/dri /dev/fb* /sys/class/drm /sys/class/graphics 2>&1
		echo "fb0 driver: $(readlink /sys/class/graphics/fb0/device/driver 2>&1)"
		cat /sys/class/graphics/fb0/modes 2>&1

		echo "=== lsmod ==="
		lsmod 2>&1
	} > "$DIAG/post_detect.txt" 2>&1

	dmesg > "$DIAG/dmesg_initrd.txt" 2>&1

	# Enable ro.config.low_ram=true, disable Vulkan/blurs, cap HWUI caches & bg_apps_limit,
	# and scrub userdebug/test-keys across all partition build.prop files for VOD / Widevine L3
	CERT_FP="google/redfin/redfin:13/TQ3A.230901.001.C1/10750268:user/release-keys"
	CERT_DESC="redfin-user 13 TQ3A.230901.001.C1 10750268 release-keys"
	prop_idx=0
	for propfile in \
		/android/system/build.prop \
		/android/system/vendor/build.prop \
		/android/system/product/etc/build.prop \
		/android/system/system_ext/etc/build.prop \
		/android/system/system_dlkm/etc/build.prop \
		/android/system/vendor/odm/etc/build.prop \
		/android/system/vendor/vendor_dlkm/etc/build.prop; do
		if [ -f "$propfile" ]; then
			prop_idx=$((prop_idx + 1))
			tmpprop="/tmp/prop_${prop_idx}.prop"
			grep -vE '^(ro\.config\.low_ram|ro\.hwui\.use_vulkan|debug\.hwui\.render_dirty_regions|ro\.surface_flinger\.supports_background_blur|ro\.hwui\.texture_cache_size|ro\.hwui\.layer_cache_size|ro\.hwui\.r_buffer_cache_size|ro\.hwui\.path_cache_size|ro\.hwui\.gradient_cache_size|ro\.hwui\.drop_shadow_cache_size|dalvik\.vm\.heapgrowthlimit|dalvik\.vm\.heapsize|dalvik\.vm\.dex2oat-threads|dalvik\.vm\.background-dex2oat-threads|dalvik\.vm\.dex2oat-cpu-set|dalvik\.vm\.background-dex2oat-cpu-set|dalvik\.vm\.dex2oat-Xmx|dalvik\.vm\.dex2oat-Xms|ro\.sys\.fw\.bg_apps_limit|ro\.lmk\.kill_heaviest_task|ro\.build\.fingerprint)=' "$propfile" \
				| busybox sed \
					-e "s|^\(ro\.[a-z0-9_]*\.build\.fingerprint=\).*|\1${CERT_FP}|" \
					-e "s|^ro\.build\.tags=.*|ro.build.tags=release-keys|" \
					-e "s|^\(ro\.[a-z0-9_]*\.build\.tags=\).*|\1release-keys|" \
					-e "s|^ro\.build\.description=.*|ro.build.description=${CERT_DESC}|" \
				> "$tmpprop"
			if [ "$propfile" = "/android/system/build.prop" ]; then
				echo "ro.build.fingerprint=${CERT_FP}" >> "$tmpprop"
			fi
			if [ "$propfile" = "/android/system/build.prop" ] || [ "$propfile" = "/android/system/vendor/build.prop" ]; then
				cat << 'EOF' >> "$tmpprop"
ro.config.low_ram=true
ro.hwui.use_vulkan=false
debug.hwui.render_dirty_regions=true
ro.surface_flinger.supports_background_blur=0
ro.hwui.texture_cache_size=24
ro.hwui.layer_cache_size=16
ro.hwui.r_buffer_cache_size=4
ro.hwui.path_cache_size=8
ro.hwui.gradient_cache_size=1
ro.hwui.drop_shadow_cache_size=0
dalvik.vm.heapgrowthlimit=128m
dalvik.vm.heapsize=384m
dalvik.vm.dex2oat-threads=2
dalvik.vm.background-dex2oat-threads=1
dalvik.vm.dex2oat-cpu-set=0,1
dalvik.vm.background-dex2oat-cpu-set=0
dalvik.vm.dex2oat-Xmx=256m
dalvik.vm.dex2oat-Xms=32m
ro.sys.fw.bg_apps_limit=4
ro.lmk.kill_heaviest_task=true
EOF
			fi
			chmod 644 "$tmpprop"
			mount --bind "$tmpprop" "$propfile"
		fi
	done

	# Bind-mount cpuinfo.arm*.txt from tmpfs so they sit in independent mount peer groups
	# instead of '/' (shared:1), preventing 2^N mount explosion when libnativebridge bind-mounts /proc/cpuinfo
	for ci in cpuinfo.arm.txt cpuinfo.arm64.txt; do
		if [ -f "/android/system/etc/$ci" ]; then
			cp "/android/system/etc/$ci" "/tmp/$ci"
			chmod 644 "/tmp/$ci"
			mount --bind "/tmp/$ci" "/android/system/etc/$ci"
		fi
	done

	# Exclude internal eMMC (80860F14:00) from voldmanaged=sdcard1 in fstab so vold only manages external microSD (80860F14:01)
	fstab_idx=0
	for fstab in /android/fstab.bliss_x86_64 /android/vendor/etc/fstab.internal.x86 /android/system/vendor/etc/fstab.internal.x86; do
		if [ -f "$fstab" ]; then
			fstab_idx=$((fstab_idx + 1))
			tmpfstab="/tmp/fstab_${fstab_idx}"
			busybox sed 's|80860F\*:\*|80860F14:01|g' "$fstab" > "$tmpfstab"
			chmod 644 "$tmpfstab"
			mount --bind "$tmpfstab" "$fstab"
		fi
	done

	# Configure TCP ADB (5555) + USB RNDIS ConfigFS + MGLRU/VM tuning + mount propagation safety
	UDC_NAME=""
	for u in /sys/class/udc/*; do
		[ -e "$u" ] && UDC_NAME=$(basename "$u") && break
	done
	SERIAL=$(cat /sys/class/dmi/id/product_serial 2>/dev/null | sed 's/[^A-Za-z0-9_-]//g')
	[ -z "$SERIAL" ] && SERIAL="BaytrailYT21050"

	if [ -f /android/vendor/etc/init/android.hardware.usb@1.0-service.rc ]; then
		cp /android/vendor/etc/init/android.hardware.usb@1.0-service.rc /tmp/yoga2_usb.rc
		cat << EOF >> /tmp/yoga2_usb.rc

# Yoga Tablet 2 TCP ADB, USB RNDIS, Mount Propagation Fix & Memory Tuning
on post-fs
    mount none /system/etc/cpuinfo.arm.txt /system/etc/cpuinfo.arm.txt bind
    mount none none /system/etc/cpuinfo.arm.txt private
    mount none /system/etc/cpuinfo.arm64.txt /system/etc/cpuinfo.arm64.txt bind
    mount none none /system/etc/cpuinfo.arm64.txt private

on early-boot
    setprop service.adb.tcp.port 5555
    setprop persist.adb.tcp.port 5555
    write /sys/module/firmware_class/parameters/path /data/bliss16/fw_runtime
    write /sys/module/brcmfmac/parameters/roamoff 1
EOF
		if [ -n "$UDC_NAME" ]; then
			cat << EOF >> /tmp/yoga2_usb.rc
    mkdir /config/usb_gadget/g1 0770 root root
    write /config/usb_gadget/g1/idVendor 0x18d1
    write /config/usb_gadget/g1/idProduct 0x4ee3
    write /config/usb_gadget/g1/bcdDevice 0x0223
    write /config/usb_gadget/g1/bcdUSB 0x0200
    write /config/usb_gadget/g1/os_desc/use 1
    write /config/usb_gadget/g1/os_desc/b_vendor_code 0xcd
    write /config/usb_gadget/g1/os_desc/qw_sign "MSFT100"
    mkdir /config/usb_gadget/g1/strings/0x409 0770 root root
    write /config/usb_gadget/g1/strings/0x409/serialnumber ${SERIAL}
    write /config/usb_gadget/g1/strings/0x409/manufacturer "Lenovo"
    write /config/usb_gadget/g1/strings/0x409/product "YOGA Tablet 2-1050"
    mkdir /config/usb_gadget/g1/configs/b.1 0770 root root
    mkdir /config/usb_gadget/g1/configs/b.1/strings/0x409 0770 root root
    write /config/usb_gadget/g1/configs/b.1/MaxPower 500
    mkdir /config/usb_gadget/g1/functions/rndis.usb0 0770 root root
    write /config/usb_gadget/g1/functions/rndis.usb0/os_desc/interface.rndis/compatible_id "RNDIS"
    write /config/usb_gadget/g1/functions/rndis.usb0/os_desc/interface.rndis/sub_compatible_id "5162001"
    symlink /config/usb_gadget/g1/functions/rndis.usb0 /config/usb_gadget/g1/configs/b.1/f1
    symlink /config/usb_gadget/g1/configs/b.1 /config/usb_gadget/g1/os_desc/b.1
    write /config/usb_gadget/g1/UDC ${UDC_NAME}
EOF
		fi
		cat << 'EOF' >> /tmp/yoga2_usb.rc

on boot
    setprop service.adb.tcp.port 5555
    setprop persist.adb.tcp.port 5555
    write /proc/sys/vm/swappiness 60
    write /proc/sys/vm/vfs_cache_pressure 100
    write /proc/sys/vm/page-cluster 0
    write /sys/kernel/mm/lru_gen/enabled 7

on property:sys.boot_completed=1
    setprop service.adb.tcp.port 5555
    setprop persist.adb.tcp.port 5555
    write /proc/sys/vm/swappiness 60
    write /proc/sys/vm/vfs_cache_pressure 100
    write /proc/sys/vm/page-cluster 0
    write /sys/kernel/mm/lru_gen/enabled 7
    restart adbd
    exec - root root -- /system/bin/sh -c "ip link set usb0 up 2>/dev/null; ip addr replace 192.168.77.2/24 dev usb0 2>/dev/null; [ -d /sys/class/bluetooth/hci0 ] && pm enable com.android.bluetooth"
EOF
		chmod 644 /tmp/yoga2_usb.rc
		mount --bind /tmp/yoga2_usb.rc /android/vendor/etc/init/android.hardware.usb@1.0-service.rc
	fi

	# Wrap /system/etc/init.sh with lightweight boot_diag log and post_init/post_bootcomplete hooks
	if [ -f /android/system/etc/init.sh ]; then
		sed -n '1,1074p' /android/system/etc/init.sh > /tmp/init_custom.sh
		cat << 'EOF' >> /tmp/init_custom.sh
if [ -d /data/boot_diag ]; then
	exec >> /data/boot_diag/init_sh.log 2>&1
	echo "=== init.sh arg1=$1 ==="
fi
post_init() {
	for f in /sys/bus/iio/devices/iio:device*/sampling_frequency; do
		[ -e "$f" ] && echo 100 > "$f" 2>/dev/null || true
	done
	if [ -n "$(ls /sys/bus/iio/devices/iio:device* 2>/dev/null)" ]; then
		toybox chown -R 1000.1000 /sys/bus/iio/devices/iio:device*/ 2>/dev/null
		chown 1000.1000 /dev/iio:device* 2>/dev/null
		chmod 660 /dev/iio:device* 2>/dev/null
	fi
}
post_bootcomplete() {
	[ -d /sys/class/bluetooth/hci0 ] && pm enable com.android.bluetooth 2>/dev/null || true
	settings put secure lockscreen_use_double_line_clock 0 2>/dev/null || true
	settings put secure ui_night_mode 2 2>/dev/null || true
	settings put global disable_window_blurs 1 2>/dev/null || true
	settings put global fancy_ime_animations 0 2>/dev/null || true
	settings put global window_animation_scale 0.0 2>/dev/null || true
	settings put global transition_animation_scale 0.0 2>/dev/null || true
	settings put global animator_duration_scale 0.25 2>/dev/null || true
	cmd overlay enable --user 0 com.android.system.theme.black 2>/dev/null || true
	settings put global wifi_on 1 2>/dev/null || true
	settings put global wifi_sleep_policy 2 2>/dev/null || true
	settings put global wifi_suspend_optimizations_enabled 0 2>/dev/null || true
	svc wifi enable 2>/dev/null || true
	iw dev wlan0 set power_save off 2>/dev/null || true
	device_config put activity_manager max_cached_processes 4 2>/dev/null || true
	for q in /sys/block/mmcblk[0-9]/queue; do
		[ -e "$q/nr_requests" ] && echo 64 > "$q/nr_requests" 2>/dev/null || true
		[ -e "$q/read_ahead_kb" ] && echo 128 > "$q/read_ahead_kb" 2>/dev/null || true
	done
	for k in $(cmd notification list 2>/dev/null | grep 'public:179,[1-8]'); do
		cmd notification snooze --for 31536000000 "$k" >/dev/null 2>&1 || true
	done
	for c in \
		com.google.android.gms.autofill.service.AutofillService \
		com.google.android.gms.autofill.ui.AutofillActivity \
		com.google.android.gms.autofill.ui.AutofillDialogActivity \
		com.google.android.gms.autofill.ui.AutofillSettingsPrivacyHubActivity \
		com.google.android.gms.autofill.ui.AutofillTransparentActivity \
		com.google.android.gms.autofill.ui.AutofillSettingsActivity \
		com.google.android.gms.autofill.ui.AutofillManagePasswordsActivity \
		com.google.android.gms.autofill.ui.settings.AutofillModernSettingsActivity \
		com.google.android.gms.autofill.service.AutofillImeCoreService \
		com.google.android.gms.autofill.service.AutofillInputMethodServiceProxy \
		com.google.android.gms.auth.api.phone.ui.AutofillConsentActivity \
		com.google.android.gms.auth.api.phone.ui.AutofillSettingsActivity \
		com.google.android.gms.auth.api.phone.ui.AutofillSettingsCollapsingActivity; do
		pm enable "com.google.android.gms/$c" >/dev/null 2>&1 || true
	done
	settings put secure autofill_service com.google.android.gms/com.google.android.gms.autofill.service.AutofillService 2>/dev/null || true
}
EOF
		sed -n '1076,$p' /android/system/etc/init.sh >> /tmp/init_custom.sh
		chmod 755 /tmp/init_custom.sh
		mount --bind /tmp/init_custom.sh /android/system/etc/init.sh
	fi

	if [ -f /android/data/adb/adb_keys ] && [ ! -f /android/data/misc/adb/adb_keys ]; then
		mkdir -p /android/data/misc/adb
		cp /android/data/adb/adb_keys /android/data/misc/adb/adb_keys
		chmod 770 /android/data/misc/adb
		chmod 640 /android/data/misc/adb/adb_keys
		chown 1000:2000 /android/data/misc/adb /android/data/misc/adb/adb_keys
	fi

	rm -f /android/data/tombstones/tombstone_* /android/data/log.txt /android/data/kmsg.txt "$DIAG/init_sh.log" 2>/dev/null || true
	chmod -R 755 "$DIAG" 2>/dev/null || true
}
