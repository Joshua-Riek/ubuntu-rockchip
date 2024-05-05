# shellcheck shell=bash

export BOARD_NAME="Turing RK1"
export BOARD_MAKER="Turing Machines"
export UBOOT_PACKAGE="u-boot-turing-rk3588"
export UBOOT_RULES_TARGET="turing-rk1-rk3588"

function config_image_hook__turing-rk1() {
    local rootfs="$1"

    # Install panfork
    chroot "${rootfs}" add-apt-repository -y ppa:jjriek/panfork-mesa
    chroot "${rootfs}" apt-get update
    chroot "${rootfs}" apt-get -y install mali-g610-firmware
    chroot "${rootfs}" apt-get -y dist-upgrade

    # The RK1 uses UART9 for console output
    sed -i 's/console=ttyS2,1500000/console=ttyS9,115200/g' "${rootfs}/etc/kernel/cmdline"

    return 0
}
