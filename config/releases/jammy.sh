# shellcheck shell=bash

RELASE_NAME="Ubuntu 22.04 LTS (Jammy Jellyfish)"
RELASE_VERSION="22.04.3"

if [ -z "${KERNEL_TARGET}" ]; then
    KERNEL_TARGET="rockchip-5.10"
fi

function build_image_hook__jammy() {
    # Uboot script
    cat > ${mount_point}/system-boot/boot.cmd << 'EOF'
# This is a boot script for U-Boot
#
# Recompile with:
# mkimage -A arm64 -O linux -T script -C none -n "Boot Script" -d boot.cmd boot.scr

setenv load_addr "0x7000000"
setenv overlay_error "false"

echo "Boot script loaded from ${devtype} ${devnum}"

if test -e ${devtype} ${devnum}:${distro_bootpart} /ubuntuEnv.txt; then
    load ${devtype} ${devnum}:${distro_bootpart} ${load_addr} /ubuntuEnv.txt
    env import -t ${load_addr} ${filesize}
fi

load ${devtype} ${devnum}:${distro_bootpart} ${fdt_addr_r} ${fdtfile}
fdt addr ${fdt_addr_r} && fdt resize 0x10000

for overlay_file in ${overlays}; do
    for file in "${overlay_prefix}-${overlay_file}.dtbo ${overlay_prefix}-${overlay_file} ${overlay_file}.dtbo ${overlay_file}"; do
        test -e ${devtype} ${devnum}:${distro_bootpart} /overlays/${file} \
        && load ${devtype} ${devnum}:${distro_bootpart} ${fdtoverlay_addr_r} /overlays/${file} \
        && echo "Applying device tree overlay: /overlays/${file}" \
        && fdt apply ${fdtoverlay_addr_r} || setenv overlay_error "true"
    done
done
if test "${overlay_error}" = "true"; then
    echo "Error applying device tree overlays, restoring original device tree"
    load ${devtype} ${devnum}:${distro_bootpart} ${fdt_addr_r} ${fdtfile}
fi

load ${devtype} ${devnum}:${distro_bootpart} ${kernel_addr_r} /vmlinuz
load ${devtype} ${devnum}:${distro_bootpart} ${ramdisk_addr_r} /initrd.img

booti ${kernel_addr_r} ${ramdisk_addr_r}:${filesize} ${fdt_addr_r}
EOF
    mkimage -A arm64 -O linux -T script -C none -n "Boot Script" -d ${mount_point}/system-boot/boot.cmd ${mount_point}/system-boot/boot.scr

    # Uboot env
    cat > ${mount_point}/system-boot/ubuntuEnv.txt << EOF
bootargs=root=UUID=${root_uuid} rootfstype=ext4 rootwait rw console=ttyS2,1500000 console=tty1 cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory swapaccount=1 ${bootargs}
fdtfile=${DEVICE_TREE_FILE}
overlay_prefix=${OVERLAY_PREFIX}
overlays=
EOF

    # Add flash kernel override
    cat << EOF >> ${mount_point}/writable/etc/flash-kernel/db
Machine: *
Kernel-Flavors: any
Method: pi
Boot-Kernel-Path: /boot/firmware/vmlinuz
Boot-Initrd-Path: /boot/firmware/initrd.img
EOF

    # Mount the temporary API filesystems
    mkdir -p ${mount_point}/writable/{proc,sys,run,dev,dev/pts}
    mount -t proc /proc ${mount_point}/writable/proc
    mount -o bind /dev ${mount_point}/writable/dev
    mount -o bind /dev/pts ${mount_point}/writable/dev/pts
    
    # Populate the boot firmware path
	mkdir -p ${mount_point}/writable/boot/firmware
    chroot ${mount_point}/writable /bin/bash -c "FK_FORCE=yes flash-kernel"

    # Umount temporary API filesystems
    umount -lf ${mount_point}/writable/dev/pts 2> /dev/null || true
    umount -lf ${mount_point}/writable/* 2> /dev/null || true

    # Copy the device trees, kernel, and initrd to the boot partition
    mv ${mount_point}/writable/boot/firmware/* ${mount_point}/system-boot/

    return 0
}
