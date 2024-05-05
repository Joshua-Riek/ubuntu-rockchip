# shellcheck shell=bash

export BOARD_NAME="Indiedroid Nova"
export BOARD_MAKER="9Tripod"
export UBOOT_PACKAGE="u-boot-radxa-rk3588"
export UBOOT_RULES_TARGET="indiedroid-nova-rk3588s"

function config_image_hook__indiedroid-nova() {
    local rootfs="$1"
    local overlay="$2"

    # Install panfork
    chroot "${rootfs}" add-apt-repository -y ppa:jjriek/panfork-mesa
    chroot "${rootfs}" apt-get update
    chroot "${rootfs}" apt-get -y install mali-g610-firmware
    chroot "${rootfs}" apt-get -y dist-upgrade

    # Enable the on-board WiFi / Bluetooth module RTL8821CS
    cp "${overlay}/usr/bin/rtk_hciattach" "${rootfs}/usr/bin/rtk_hciattach"
    cp "${overlay}/usr/bin/bt_load_rtk_firmware" "${rootfs}/usr/bin/bt_load_rtk_firmware"
    cp "${overlay}/usr/lib/systemd/system/rtl8821cs-bluetooth.service" "${rootfs}/usr/lib/systemd/system/rtl8821cs-bluetooth.service"
    chroot "${rootfs}" systemctl enable rtl8821cs-bluetooth

    return 0
}
