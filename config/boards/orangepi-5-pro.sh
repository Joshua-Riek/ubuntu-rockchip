# shellcheck shell=bash

export BOARD_NAME="Orange Pi 5 Pro"
export BOARD_MAKER="Xulong"
export BOARD_SOC="Rockchip RK3588S"
export BOARD_CPU="ARM Cortex A76 / A55"
export UBOOT_PACKAGE="u-boot-orangepi-rk3588"
export UBOOT_RULES_TARGET="orangepi_5_pro"

function config_image_hook__orangepi-5-pro() {
    local rootfs="$1"
    local overlay="$2"

    # Install panfork
    chroot "${rootfs}" add-apt-repository -y ppa:jjriek/panfork-mesa
    chroot "${rootfs}" apt-get update
    chroot "${rootfs}" apt-get -y install mali-g610-firmware
    chroot "${rootfs}" apt-get -y dist-upgrade

    # Install libmali blobs alongside panfork
    chroot "${rootfs}" apt-get -y install libmali-g610-x11

    # Install the rockchip camera engine
    chroot "${rootfs}" apt-get -y install camera-engine-rkaiq-rk3588

    # Enable bluetooth
    cp "${overlay}/usr/bin/brcm_patchram_plus" "${rootfs}/usr/bin/brcm_patchram_plus"
    cp "${overlay}/usr/lib/systemd/system/ap6256-bluetooth.service" "${rootfs}/usr/lib/systemd/system/ap6256-bluetooth.service"
    chroot "${rootfs}" systemctl enable ap6256-bluetooth

    # Install wiring orangepi package 
    chroot "${rootfs}" apt-get -y install wiringpi-opi libwiringpi2-opi libwiringpi-opi-dev
    echo "BOARD=orangepi5pro" > "${rootfs}/etc/orangepi-release"

    return 0
}
