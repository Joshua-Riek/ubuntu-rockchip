# shellcheck shell=bash

export BOARD_NAME="Orange Pi 5 Pro"
export BOARD_MAKER="Xulong"
export BOARD_SOC="Rockchip RK3588S"
export BOARD_CPU="ARM Cortex A76 / A55"
export UBOOT_PACKAGE="u-boot-radxa-rk3588"
export UBOOT_RULES_TARGET="orangepi-5-pro-rk3588s"
export COMPATIBLE_SUITES=("jammy" "noble")
export COMPATIBLE_FLAVORS=("server" "desktop")

function config_image_hook__orangepi-5-pro() {
    local rootfs="$1"
    local overlay="$2"
    local suite="$3"

    if [ "${suite}" == "jammy" ] || [ "${suite}" == "noble" ]; then
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
        cp "${overlay}/usr/lib/systemd/system/ap6256s-bluetooth.service" "${rootfs}/usr/lib/systemd/system/ap6256s-bluetooth.service"
        chroot "${rootfs}" systemctl enable ap6256s-bluetooth

        # Unbind SDIO device before reboot
        cp "${overlay}/usr/lib/systemd/system/ap6256-reboot.service" "${rootfs}/usr/lib/systemd/system/ap6256-reboot.service"
        chroot "${rootfs}" systemctl enable ap6256-reboot.service

        # Install wiring orangepi package 
        chroot "${rootfs}" apt-get -y install wiringpi-opi libwiringpi2-opi libwiringpi-opi-dev
        echo "BOARD=orangepi5pro" > "${rootfs}/etc/orangepi-release"

        # Deactivate the Qualcomm PD mapper service, because we are on a Rockchip.
        chroot "${rootfs}" systemctl disable pd-mapper.service
    fi

    return 0
}
