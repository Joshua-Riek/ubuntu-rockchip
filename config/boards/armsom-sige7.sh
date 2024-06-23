# shellcheck shell=bash

export BOARD_NAME="ArmSoM Sige7"
export BOARD_MAKER="ArmSoM"
export BOARD_SOC="Rockchip RK3588"
export BOARD_CPU="ARM Cortex A76 / A55"
export UBOOT_PACKAGE="u-boot-radxa-rk3588"
export UBOOT_RULES_TARGET="armsom-sige7-rk3588"

function config_image_hook__armsom-sige7() {
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
    sed -i 's/ttyS9/ttyS6/g' "${rootfs}/usr/lib/scripts/ap6275p-bluetooth.sh"
    chroot "${rootfs}" systemctl enable ap6275p-bluetooth

    # Fix and configure audio device
    mkdir -p "${rootfs}/usr/lib/scripts"
    cp "${overlay}/usr/lib/scripts/alsa-audio-config" "${rootfs}/usr/lib/scripts/alsa-audio-config"
    cp "${overlay}/usr/lib/systemd/system/alsa-audio-config.service" "${rootfs}/usr/lib/systemd/system/alsa-audio-config.service"
    chroot "${rootfs}" systemctl enable alsa-audio-config

    return 0
}
