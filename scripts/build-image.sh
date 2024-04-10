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

if [[ -z ${KERNEL_TARGET} ]]; then
    echo "Error: KERNEL_TARGET is not set"
    exit 1
fi

# shellcheck source=/dev/null
source ../config/kernels/"${KERNEL_TARGET}.conf"

KVER=""
if [[ "${KERNEL_TARGET}" == "mainline" ]]; then
    KVER="-${KERNEL_TARGET}-${KERNEL_VERSION}"
fi

# Create an empty disk image
img="../images/$(basename "${rootfs}" .rootfs.tar)${KVER}.img"
size="$(( $(wc -c < "${rootfs}" ) / 1024 / 1024 ))"
truncate -s "$(( size + 2048 ))M" "${img}"

# Create loop device for disk image
loop="$(losetup -f)"
losetup -P "${loop}" "${img}"
disk="${loop}"

# Cleanup loopdev on early exit
trap 'cleanup_loopdev ${loop}' EXIT

# Ensure disk is not mounted
mount_point=/tmp/mnt
umount "${disk}"* 2> /dev/null || true
umount ${mount_point}/* 2> /dev/null || true
mkdir -p ${mount_point}

if [ -z "${img##*server*}" ]; then
    # Setup partition table
    dd if=/dev/zero of="${disk}" count=4096 bs=512
    parted --script "${disk}" \
    mklabel gpt \
    mkpart primary fat32 16MiB 20MiB \
    mkpart primary ext4 20MiB 100%

    # Create partitions
    {
        echo "t"
        echo "1"
        echo "EBD0A0A2-B9E5-4433-87C0-68B6B72699C7"
        echo "t"
        echo "2"
        echo "C12A7328-F81F-11D2-BA4B-00A0C93EC93B"
        echo "w"
    } | fdisk "${disk}" &> /dev/null || true

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
    mkfs.vfat -i "${boot_uuid}" -F32 -n CIDATA "${disk}${partition_char}1"
    dd if=/dev/zero of="${disk}${partition_char}2" bs=1KB count=10 > /dev/null
    mkfs.ext4 -U "${root_uuid}" -L cloudimg-rootfs "${disk}${partition_char}2"

    # Mount partitions
    mkdir -p ${mount_point}/{system-boot,writable} 
    mount "${disk}${partition_char}1" ${mount_point}/system-boot
    mount "${disk}${partition_char}2" ${mount_point}/writable

    # Cloud init config for server image
    cp ../overlay/boot/firmware/{meta-data,user-data,network-config} ${mount_point}/system-boot
else
    # Setup partition table
    dd if=/dev/zero of="${disk}" count=4096 bs=512
    parted --script "${disk}" \
    mklabel gpt \
    mkpart primary ext4 16MiB 100%

    # Create partitions
    {
        echo "t"
        echo "1"
        echo "C12A7328-F81F-11D2-BA4B-00A0C93EC93B"
        echo "w"
    } | fdisk "${disk}" &> /dev/null || true

    partprobe "${disk}"

    partition_char="$(if [[ ${disk: -1} == [0-9] ]]; then echo p; fi)"

    sleep 1

    wait_loopdev "${disk}${partition_char}1" 60 || {
        echo "Failure to create ${disk}${partition_char}1 in time"
        exit 1
    }

    sleep 1

    # Generate random uuid for rootfs
    root_uuid=$(uuidgen)

    # Create filesystems on partitions
    dd if=/dev/zero of="${disk}${partition_char}1" bs=1KB count=10 > /dev/null
    mkfs.ext4 -U "${root_uuid}" -L desktop-rootfs "${disk}${partition_char}1"

    # Mount partitions
    mkdir -p ${mount_point}/writable
    mount "${disk}${partition_char}1" ${mount_point}/writable

    # Set boot args for the splash screen
    bootargs="quiet splash plymouth.ignore-serial-consoles"
fi

# Copy the rootfs to root partition
tar -xpf "${rootfs}" -C ${mount_point}/writable

# Create fstab entries
echo "# <file system>     <mount point>  <type>  <options>   <dump>  <fsck>" > ${mount_point}/writable/etc/fstab
echo "UUID=${root_uuid,,} /              ext4    defaults,x-systemd.growfs    0       1" >> ${mount_point}/writable/etc/fstab

# Write bootloader to disk image
if [ -f "${mount_point}/writable/usr/lib/u-boot/u-boot-rockchip.bin" ]; then
    dd if="${mount_point}/writable/usr/lib/u-boot/u-boot-rockchip.bin" of="${loop}" seek=1 bs=32k conv=fsync
else
    dd if="${mount_point}/writable/usr/lib/u-boot/idbloader.img" of="${loop}" seek=64 conv=notrunc
    dd if="${mount_point}/writable/usr/lib/u-boot/u-boot.itb" of="${loop}" seek=16384 conv=notrunc
fi

if [[ ${RELEASE} != "noble" ]]; then
touch ${mount_point}/writable/etc/kernel/cmdline
mkdir -p ${mount_point}/writable/usr/share/u-boot-menu/conf.d/
cat << EOF >> ${mount_point}/writable/usr/share/u-boot-menu/conf.d/ubuntu.conf
U_BOOT_PROMPT="1"
U_BOOT_PARAMETERS="\$(cat /etc/kernel/cmdline)"
U_BOOT_TIMEOUT="10"
U_BOOT_FDT="rockchip/${DEVICE_TREE_FILE}"
U_BOOT_FDT_DIR="/usr/lib/linux-image-"
U_BOOT_FDT_OVERLAYS_DIR="/usr/lib/linux-image-"
EOF
# Uboot env
echo "rootwait rw console=ttyS2,1500000 console=tty1 cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory ${bootargs}" > ${mount_point}/writable/etc/kernel/cmdline
fi

# Run build image hook to handle board specific changes
if [[ $(type -t build_image_hook__"${BOARD}") == function ]]; then
    build_image_hook__"${BOARD}"
fi 

chroot ${mount_point}/writable/ /bin/bash -c "u-boot-update"

sync --file-system
sync

# Umount partitions
umount "${disk}${partition_char}1"
umount "${disk}${partition_char}2" 2> /dev/null || true

# Remove loop device
losetup -d "${loop}"

# Exit trap is no longer needed
trap '' EXIT

echo -e "\nCompressing $(basename "${img}.xz")\n"
xz -6 --force --keep --quiet --threads=0 "${img}"
rm -f "${img}"
cd ../images && sha256sum "$(basename "${img}.xz")" > "$(basename "${img}.xz.sha256")"
