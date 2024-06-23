# shellcheck shell=bash

export BOARD_NAME="ROCK 5D"
export BOARD_MAKER="Radxa"
export BOARD_SOC="Rockchip RK3588S2"
export BOARD_CPU="ARM Cortex A76 / A55"
export UBOOT_PACKAGE="u-boot-radxa-rk3588"
export UBOOT_RULES_TARGET="rock-5d-rk3588s"

function config_image_hook__rock-5d() {
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

    # Install AIC8800 WiFi and Bluetooth DKMS
    chroot "${rootfs}" apt-get -y install dkms aic8800-firmware aic8800-usb-dkms

    # shellcheck disable=SC2016
    echo 'SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="88:00:*", NAME="$ENV{ID_NET_SLOT}"' > "${rootfs}/etc/udev/rules.d/99-radxa-aic8800.rules"

    # Fix and configure audio device
    mkdir -p "${rootfs}/usr/lib/scripts"
    cp "${overlay}/usr/lib/scripts/alsa-audio-config" "${rootfs}/usr/lib/scripts/alsa-audio-config"
    cp "${overlay}/usr/lib/systemd/system/alsa-audio-config.service" "${rootfs}/usr/lib/systemd/system/alsa-audio-config.service"
    chroot "${rootfs}" systemctl enable alsa-audio-config

    return 0
}
