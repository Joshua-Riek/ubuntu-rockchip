# shellcheck shell=bash

export BOARD_NAME="ROC RK3588S PC"
export BOARD_MAKER="Firefly"
export UBOOT_PACKAGE="u-boot-radxa-rk3588"
export UBOOT_RULES_TARGET="roc-rk3588s-pc-rk3588s"

function config_image_hook__roc-rk3588s-pc() {
    local rootfs="$1"

    # Install panfork
    chroot "${rootfs}" add-apt-repository -y ppa:jjriek/panfork-mesa
    chroot "${rootfs}" apt-get update
    chroot "${rootfs}" apt-get -y install mali-g610-firmware
    chroot "${rootfs}" apt-get -y dist-upgrade

    return 0
}
