# shellcheck shell=bash

export BOARD_NAME="Orange Pi 5"
export BOARD_MAKER="Xulong"
export BOARD_SOC="Rockchip RK3588S"
export BOARD_CPU="ARM Cortex A76 / A55"
export UBOOT_PACKAGE="u-boot-radxa-rk3588"
export UBOOT_RULES_TARGET="orangepi-5-rk3588s"
export UBOOT_RULES_TARGET_EXTRA="orangepi-5-sata-rk3588s"

function config_image_hook__orangepi-5() {
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

    # Enable bluetooth for AP6275P
    mkdir -p "${rootfs}/usr/lib/scripts"
    cp "${overlay}/usr/lib/systemd/system/ap6275p-bluetooth.service" "${rootfs}/usr/lib/systemd/system/ap6275p-bluetooth.service"
    cp "${overlay}/usr/lib/scripts/ap6275p-bluetooth.sh" "${rootfs}/usr/lib/scripts/ap6275p-bluetooth.sh"
    cp "${overlay}/usr/bin/brcm_patchram_plus" "${rootfs}/usr/bin/brcm_patchram_plus"
    chroot "${rootfs}" systemctl enable ap6275p-bluetooth

    # Enable USB 2.0 port
    cp "${overlay}/usr/lib/systemd/system/enable-usb2.service" "${rootfs}/usr/lib/systemd/system/enable-usb2.service"
    chroot "${rootfs}" systemctl --no-reload enable enable-usb2

    # Install wiring orangepi package 
    chroot "${rootfs}" apt-get -y install wiringpi-opi libwiringpi2-opi libwiringpi-opi-dev
    echo "BOARD=orangepi5" > "${rootfs}/etc/orangepi-release"

    return 0
}
