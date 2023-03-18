#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

function cleanup_loopdev {
    sync --file-system
    sync

    if [ -b "${loop}" ]; then
        umount "${loop}"* 2> /dev/null || true
        losetup -d "${loop}" 2> /dev/null || true
    fi
}
trap cleanup_loopdev EXIT

if [ "$(id -u)" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

if [ -z "$1" ]; then
    echo "Usage: $0 filename.rootfs.tar.xz"
    exit 1
fi

rootfs="$(readlink -f "$1")"
if [[ "$(basename "${rootfs}")" != *".rootfs.tar.xz" || ! -e "${rootfs}" ]]; then
    echo "Error: $(basename "${rootfs}") must be a rootfs tarfile"
    exit 1
fi

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..
mkdir -p images build && cd build

# Create an empty disk image
img="../images/$(basename "${rootfs}" .rootfs.tar.xz).img"
size="$(xz -l "${rootfs}" | tail -n +2 | sed 's/,//g' | awk '{print int($5 + 1)}')"
truncate -s "$(( size + 2048 + 512 ))M" "${img}"

# Create loop device for disk image
loop="$(losetup -f)"
losetup "${loop}" "${img}"
disk="${loop}"

# Ensure disk is not mounted
mount_point=/tmp/mnt
umount "${disk}"* 2> /dev/null || true
umount ${mount_point}/* 2> /dev/null || true
mkdir -p ${mount_point}

# Setup partition table
dd if=/dev/zero of="${disk}" count=4096 bs=512
parted --script "${disk}" \
mklabel gpt \
mkpart primary fat16 16MiB 272MiB \
mkpart primary ext4 272MiB 100%

set +e

# Create partitions
fdisk "${disk}" << EOF
t
1
30
t
2
20
w
EOF

set -eE

partprobe "${disk}"

sleep 2

# Generate random uuid for bootfs
boot_uuid=$(uuidgen | head -c8)

# Generate random uuid for rootfs
root_uuid=$(uuidgen)
    
# Create filesystems on partitions
partition_char="$(if [[ ${disk: -1} == [0-9] ]]; then echo p; fi)"
mkfs.vfat -i "${boot_uuid}" -F16 -n system-boot "${disk}${partition_char}1"
dd if=/dev/zero of="${disk}${partition_char}2" bs=1KB count=10 > /dev/null
mkfs.ext4 -U "${root_uuid}" -L writable "${disk}${partition_char}2"

# Mount partitions
mkdir -p ${mount_point}/{system-boot,writable} 
mount "${disk}${partition_char}1" ${mount_point}/system-boot
mount "${disk}${partition_char}2" ${mount_point}/writable

# Copy the rootfs to root partition
echo -e "Decompressing $(basename "${rootfs}")\n"
tar -xpJf "${rootfs}" -C ${mount_point}/writable

# Set boot args for the splash screen
[ -z "${img##*desktop*}" ] && bootargs="quiet splash plymouth.ignore-serial-consoles" || bootargs=""

# Create fstab entries
mkdir -p ${mount_point}/writable/boot/firmware
cat > ${mount_point}/writable/etc/fstab << EOF
# <file system>     <mount point>  <type>  <options>   <dump>  <fsck>
LABEL=system-boot   /boot/firmware vfat    defaults    0       2
LABEL=writable      /              ext4    defaults    0       1
/swapfile           none           swap    sw          0       0
EOF

# Uboot script
cat > ${mount_point}/system-boot/boot.cmd << EOF
# This is a boot script for U-Boot
#
# Recompile with:
# mkimage -A arm64 -O linux -T script -C none -n "Boot Script" boot.cmd boot.scr

env set bootargs "console=ttyS2,1500000 console=tty1 root=LABEL=writable rootfstype=ext4 rootwait rw cma=64M cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory swapaccount=1 systemd.unified_cgroup_hierarchy=0 ${bootargs}"

load \${devtype} \${devnum}:1 \${fdt_addr_r} /rk3588s-orangepi-5.dtb
fdt addr \${fdt_addr_r} && fdt resize 0x10000

if test -e \${devtype} \${devnum}:1 \${fdtoverlay_addr_r} /overlays.txt; then
    load \${devtype} \${devnum}:1 \${fdtoverlay_addr_r} /overlays.txt
    env import -t \${fdtoverlay_addr_r} \${filesize}
fi
for overlay_file in \${overlays}; do
    if load \${devtype} \${devnum}:1 \${fdtoverlay_addr_r} /overlays/rk3588-\${overlay_file}.dtbo; then
        echo "Applying device tree overlay: /overlays/\${overlay_file}"
        fdt apply \${fdtoverlay_addr_r} || setenv overlay_error "true"
    fi
done
if test -n \${overlay_error}; then
    echo "Error applying device tree overlays, restoring original device tree"
    load \${devtype} \${devnum}:1 \${fdt_addr_r} /rk3588s-orangepi-5.dtb
fi

load \${devtype} \${devnum}:2 \${kernel_addr_r} /boot/vmlinuz
load \${devtype} \${devnum}:2 \${ramdisk_addr_r} /boot/initrd.img

booti \${kernel_addr_r} \${ramdisk_addr_r}:\${filesize} \${fdt_addr_r}
EOF
mkimage -A arm64 -O linux -T script -C none -n "Boot Script" -d ${mount_point}/system-boot/boot.cmd ${mount_point}/system-boot/boot.scr

# Device tree overlays to load
echo "overlays=" > ${mount_point}/system-boot/overlays.txt

# Copy device tree blobs
mkdir -p ${mount_point}/system-boot/overlays
cp -r linux-orangepi/arch/arm64/boot/dts/rockchip/rk3588s-orangepi-5.dtb ${mount_point}/system-boot

# Copy device tree overlays
mkdir -p ${mount_point}/system-boot/overlays
cp -r linux-orangepi/arch/arm64/boot/dts/rockchip/overlay/rk3588*.dtbo ${mount_point}/system-boot/overlays

# Write bootloader to disk image
dd if=u-boot-orangepi/idbloader.img of="${loop}" seek=64 conv=notrunc
dd if=u-boot-orangepi/u-boot.itb of="${loop}" seek=16384 conv=notrunc

# Copy spi bootloader to disk image
mkdir -p ${mount_point}/writable/usr/share/orangepi
cp u-boot-orangepi/rkspi_loader.img ${mount_point}/writable/usr/share/orangepi/rkspi_loader.img
cp u-boot-orangepi/rkspi_loader_sata.img ${mount_point}/writable/usr/share/orangepi/rkspi_loader_sata.img

# Cloud init config for server image
[ -z "${img##*server*}" ] && cp ../overlay/boot/firmware/{meta-data,user-data,network-config} ${mount_point}/system-boot

sync --file-system
sync

# Umount partitions
umount "${disk}${partition_char}1"
umount "${disk}${partition_char}2"

# Remove loop device
losetup -d "${loop}"

echo -e "\nCompressing $(basename "${img}.xz")\n"
xz -9 --extreme --force --keep --quiet --threads=0 "${img}"
rm -f "${img}"
