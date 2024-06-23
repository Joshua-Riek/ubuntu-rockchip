# shellcheck shell=bash

export BOARD_NAME="Mixtile Blade 3"
export BOARD_MAKER="Mixtile"
export BOARD_SOC="Rockchip RK3588"
export BOARD_CPU="ARM Cortex A76 / A55"
export UBOOT_PACKAGE="u-boot-mixtile-rk3588"
export UBOOT_RULES_TARGET="mixtile-blade3-rk3588"

function config_image_hook__mixtile-blade3() {
    local rootfs="$1"

    # Install panfork
    chroot "${rootfs}" add-apt-repository -y ppa:jjriek/panfork-mesa
    chroot "${rootfs}" apt-get update
    chroot "${rootfs}" apt-get -y install mali-g610-firmware
    chroot "${rootfs}" apt-get -y dist-upgrade

    # Install libmali blobs alongside panfork
    chroot "${rootfs}" apt-get -y install libmali-g610-x11

    # Install the rockchip camera engine
    chroot "${rootfs}" apt-get -y install camera-engine-rkaiq-rk3588

    return 0
}
