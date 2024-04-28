# shellcheck shell=bash

RELASE_NAME="Ubuntu 24.04 LTS (Noble Nombat)"
RELASE_VERSION="24.04"

if [ -z "${KERNEL_TARGET}" ]; then
    KERNEL_TARGET="rockchip-6.1"
fi

function build_image_hook__noble() {
    (
        echo LINUX_KERNEL_CMDLINE="\"console=ttyS2,1500000 console=tty1 rootwait rw cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory ${bootargs}"\"
        echo LINUX_KERNEL_CMDLINE_DEFAULTS="\""\"
    ) > ${mount_point}/writable/etc/default/flash-kernel

    # Mount the temporary API filesystems
    mkdir -p ${mount_point}/writable/{proc,sys,run,dev,dev/pts}
    mount -t proc /proc ${mount_point}/writable/proc
    mount -o bind /dev ${mount_point}/writable/dev
    mount -o bind /dev/pts ${mount_point}/writable/dev/pts

    # Populate the boot firmware path
    mkdir -p ${mount_point}/writable/boot/firmware
    chroot ${mount_point}/writable /bin/bash -c "FK_FORCE=yes FK_MACHINE='${FLASH_KERNEL_MACHINE_MODEL}' update-initramfs -u"

    # Umount temporary API filesystems
    umount -lf ${mount_point}/writable/dev/pts 2> /dev/null || true
    umount -lf ${mount_point}/writable/* 2> /dev/null || true

    # Copy the device trees, kernel, and initrd to the boot partition
    mv ${mount_point}/writable/boot/firmware/* ${mount_point}/system-boot/

    return 0
}
