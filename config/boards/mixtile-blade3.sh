# shellcheck shell=bash

export BOARD_NAME="Mixtile Blade 3"
export BOARD_MAKER="Mixtile"
export UBOOT_PACKAGE="u-boot-mixtile-rk3588"
export UBOOT_RULES_TARGET="mixtile-blade3-rk3588"

function config_image_hook__mixtile-blade3() {
    local rootfs="$1"

    # Install panfork
    chroot "${rootfs}" add-apt-repository -y ppa:jjriek/panfork-mesa
    chroot "${rootfs}" apt-get update
    chroot "${rootfs}" apt-get -y install mali-g610-firmware
    chroot "${rootfs}" apt-get -y dist-upgrade

    return 0
}
