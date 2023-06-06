#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

cleanup_loopdev() {
    local loop="$1"

    sync --file-system
    sync

    sleep 1

    if [ -b "${loop}" ]; then
        for part in "${loop}"p*; do
            if mnt=$(findmnt -n -o target -S "$part"); then
                umount "${mnt}"
            fi
        done
        losetup -d "${loop}"
    fi
}

wait_loopdev() {
    local loop="$1"
    local seconds="$2"

    until test $((seconds--)) -eq 0 -o -b "${loop}"; do sleep 1; done

    ((++seconds))

    ls -l "${loop}" &> /dev/null
}

if [ "$(id -u)" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

if [ -z "$1" ]; then
    echo "Usage: $0 filename.rootfs.tar"
    exit 1
fi

rootfs="$(readlink -f "$1")"
if [[ "$(basename "${rootfs}")" != *".rootfs.tar" || ! -e "${rootfs}" ]]; then
    echo "Error: $(basename "${rootfs}") must be a rootfs tarfile"
    exit 1
fi

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..
mkdir -p images build && cd build

if [[ -z ${BOARD} ]]; then
    echo "Error: BOARD is not set"
    exit 1
fi

if [[ -z ${VENDOR} ]]; then
    echo "Error: VENDOR is not set"
    exit 1
fi

if [[ "${BOARD}" == orangepi5 ]]; then
    DEVICE_TREE=rk3588s-orangepi-5.dtb
    OVERLAY_PREFIX=orangepi-5
elif [[ "${BOARD}" == orangepi5b ]]; then
    DEVICE_TREE=rk3588s-orangepi-5b.dtb
    OVERLAY_PREFIX=orangepi-5
elif [[ "${BOARD}" == orangepi5plus ]]; then
    DEVICE_TREE=rk3588-orangepi-5-plus.dtb
    OVERLAY_PREFIX=orangepi-5-plus
elif [[ "${BOARD}" == rock5a ]]; then
    DEVICE_TREE=rk3588s-rock-5a.dtb
    OVERLAY_PREFIX=rock-5a
elif [[ "${BOARD}" == rock5b ]]; then
    DEVICE_TREE=rk3588-rock-5b.dtb
    OVERLAY_PREFIX=rock-5b
elif [[ "${BOARD}" == nanopir6c ]]; then
    DEVICE_TREE=rk3588s-nanopi-r6c.dtb
    OVERLAY_PREFIX=
elif [[ "${BOARD}" == nanopir6s ]]; then
    DEVICE_TREE=rk3588s-nanopi-r6s.dtb
    OVERLAY_PREFIX=
elif [[ "${BOARD}" == indiedroid-nova ]]; then
    DEVICE_TREE=rk3588s-9tripod-linux.dtb
    OVERLAY_PREFIX=
fi

# Create an empty disk image
img="../images/$(basename "${rootfs}" .rootfs.tar).img"
size="$(( $(wc -c < "${rootfs}" ) / 1024 / 1024 ))"
truncate -s "$(( size + 2048 + 512 ))M" "${img}"

# Create loop device for disk image
loop="$(losetup -f)"
losetup "${loop}" "${img}"
disk="${loop}"

# Cleanup loopdev on early exit
trap 'cleanup_loopdev ${loop}' EXIT

# Ensure disk is not mounted
mount_point=/tmp/mnt
umount "${disk}"* 2> /dev/null || true
umount ${mount_point}/* 2> /dev/null || true
mkdir -p ${mount_point}

# Setup partition table
dd if=/dev/zero of="${disk}" count=4096 bs=512
parted --script "${disk}" \
mklabel gpt \
mkpart primary fat16 16MiB 528MiB \
mkpart primary ext4 528MiB 100%

set +e

# Create partitions
fdisk "${disk}" << EOF
t
1
BC13C2FF-59E6-4262-A352-B275FD6F7172
t
2
0FC63DAF-8483-4772-8E79-3D69D8477DE4
w
EOF

set -eE

partprobe "${disk}"

partition_char="$(if [[ ${disk: -1} == [0-9] ]]; then echo p; fi)"

sleep 1

wait_loopdev "${disk}${partition_char}2" 60 || {
    echo "Failure to create ${disk}${partition_char}1 in time"
    exit 1
}

sleep 1

wait_loopdev "${disk}${partition_char}1" 60 || {
    echo "Failure to create ${disk}${partition_char}1 in time"
    exit 1
}

sleep 1

# Generate random uuid for bootfs
boot_uuid=$(uuidgen | head -c8)

# Generate random uuid for rootfs
root_uuid=$(uuidgen)

# Create filesystems on partitions
mkfs.vfat -i "${boot_uuid}" -F16 -n system-boot "${disk}${partition_char}1"
dd if=/dev/zero of="${disk}${partition_char}2" bs=1KB count=10 > /dev/null
mkfs.ext4 -U "${root_uuid}" -L writable "${disk}${partition_char}2"

# Mount partitions
mkdir -p ${mount_point}/{system-boot,writable} 
mount "${disk}${partition_char}1" ${mount_point}/system-boot
mount "${disk}${partition_char}2" ${mount_point}/writable

# Copy the rootfs to root partition
tar -xpf "${rootfs}" -C ${mount_point}/writable

# Set boot args for the splash screen
[ -z "${img##*desktop*}" ] && bootargs="quiet splash plymouth.ignore-serial-consoles" || bootargs=""

# Create fstab entries
boot_uuid="${boot_uuid:0:4}-${boot_uuid:4:4}"
mkdir -p ${mount_point}/writable/boot/firmware
cat > ${mount_point}/writable/etc/fstab << EOF
# <file system>     <mount point>  <type>  <options>   <dump>  <fsck>
UUID=${boot_uuid^^} /boot/firmware vfat    defaults    0       2
UUID=${root_uuid,,} /              ext4    defaults    0       1
/swapfile           none           swap    sw          0       0
EOF

# Uboot script
cat > ${mount_point}/system-boot/boot.cmd << 'EOF'
# This is a boot script for U-Boot
#
# Recompile with:
# mkimage -A arm64 -O linux -T script -C none -n "Boot Script" -d boot.cmd boot.scr

setenv load_addr "0x9000000"
setenv overlay_error "false"

echo "Boot script loaded from ${devtype} ${devnum}"

if test -e ${devtype} ${devnum}:${distro_bootpart} /ubuntuEnv.txt; then
	load ${devtype} ${devnum}:${distro_bootpart} ${load_addr} /ubuntuEnv.txt
	env import -t ${load_addr} ${filesize}
fi

load ${devtype} ${devnum}:${distro_bootpart} ${fdt_addr_r} /dtbs/${fdtfile}
fdt addr ${fdt_addr_r} && fdt resize 0x10000

for overlay_file in ${overlays}; do
    if load ${devtype} ${devnum}:${distro_bootpart} ${fdtoverlay_addr_r} /dtbs/overlays/${overlay_prefix}-${overlay_file}.dtbo; then
        echo "Applying device tree overlay: /dtbs/overlays/${overlay_prefix}-${overlay_file}.dtbo"
        fdt apply ${fdtoverlay_addr_r} || setenv overlay_error "true"
    elif load ${devtype} ${devnum}:${distro_bootpart} ${fdtoverlay_addr_r} /dtbs/overlays/${overlay_file}.dtbo; then
        echo "Applying device tree overlay: /dtbs/overlays/${overlay_file}.dtbo"
        fdt apply ${fdtoverlay_addr_r} || setenv overlay_error "true"
    elif load ${devtype} ${devnum}:${distro_bootpart} ${fdtoverlay_addr_r} /dtbs/overlays/rk3588-${overlay_file}.dtbo; then
        echo "Applying device tree overlay: /dtbs/overlays/rk3588-${overlay_file}.dtbo"
        fdt apply ${fdtoverlay_addr_r} || setenv overlay_error "true"
    fi
done
if test "${overlay_error}" = "true"; then
    echo "Error applying device tree overlays, restoring original device tree"
    load ${devtype} ${devnum}:${distro_bootpart} ${fdt_addr_r} /dtbs/${fdtfile}
fi

load ${devtype} ${devnum}:${distro_bootpart} ${kernel_addr_r} /vmlinuz
load ${devtype} ${devnum}:${distro_bootpart} ${ramdisk_addr_r} /initrd.img

booti ${kernel_addr_r} ${ramdisk_addr_r}:${filesize} ${fdt_addr_r}
EOF
mkimage -A arm64 -O linux -T script -C none -n "Boot Script" -d ${mount_point}/system-boot/boot.cmd ${mount_point}/system-boot/boot.scr

# Uboot env
cat > ${mount_point}/system-boot/ubuntuEnv.txt << EOF
bootargs=root=UUID=${root_uuid} rootfstype=ext4 rootwait rw console=ttyS2,1500000 console=tty1 cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory swapaccount=1 systemd.unified_cgroup_hierarchy=0 ${bootargs}
fdtfile=${DEVICE_TREE}
overlay_prefix=${OVERLAY_PREFIX}
overlays=
EOF

# Copy kernel and initrd to boot partition
cp ${mount_point}/writable/boot/initrd.img-5.10.160-rockchip ${mount_point}/system-boot/initrd.img
cp ${mount_point}/writable/boot/vmlinuz-5.10.160-rockchip ${mount_point}/system-boot/vmlinuz

# Copy device trees to boot partition
mv ${mount_point}/writable/boot/firmware/* ${mount_point}/system-boot

# Write bootloader to disk image
dd if=${mount_point}/writable/usr/lib/u-boot-"${VENDOR}"-rk3588/idbloader.img of="${loop}" seek=64 conv=notrunc
dd if=${mount_point}/writable/usr/lib/u-boot-"${VENDOR}"-rk3588/u-boot.itb of="${loop}" seek=16384 conv=notrunc

# Cloud init config for server image
if [ -z "${img##*server*}" ]; then
    cp ../overlay/boot/firmware/{meta-data,user-data,network-config} ${mount_point}/system-boot
    if [ "${BOARD}" == rock5b ] || [ "${BOARD}" == indiedroid-nova ]; then
        sed -i 's/eth0:/enP4p65s0:/g' ${mount_point}/system-boot/network-config
    elif [ "${BOARD}" == orangepi5plus ]; then
        sed -i 's/eth0:/enP4p65s0:\n    dhcp4: true\n    optional: true\n  enP3p49s0:/g' ${mount_point}/system-boot/network-config
    fi
fi

sync --file-system
sync

# Umount partitions
umount "${disk}${partition_char}1"
umount "${disk}${partition_char}2"

# Remove loop device
losetup -d "${loop}"

# Exit trap is no longer needed
trap '' EXIT

echo -e "\nCompressing $(basename "${img}.xz")\n"
xz -3 --force --keep --quiet --threads=0 "${img}"
rm -f "${img}"
cd ../images && sha256sum "$(basename "${img}.xz")" > "$(basename "${img}.xz.sha256")"
