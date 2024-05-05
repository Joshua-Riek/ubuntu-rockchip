# shellcheck shell=bash

export BOARD_NAME="Radxa NX5 IO"
export BOARD_MAKER="Radxa"
export UBOOT_PACKAGE="u-boot-radxa-rk3588"
export UBOOT_RULES_TARGET="radxa-nx5-io-rk3588s"

function config_image_hook__radxa-nx-io() {
    local rootfs="$1"

    # Install panfork
    chroot "${rootfs}" add-apt-repository -y ppa:jjriek/panfork-mesa
    chroot "${rootfs}" apt-get update
    chroot "${rootfs}" apt-get -y install mali-g610-firmware
    chroot "${rootfs}" apt-get -y dist-upgrade

    return 0
}
