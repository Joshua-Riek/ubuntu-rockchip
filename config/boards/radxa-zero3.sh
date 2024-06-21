# shellcheck shell=bash

export BOARD_NAME="Radxa Zero 3"
export BOARD_MAKER="Radxa"
export BOARD_SOC="Rockchip RK3566"
export BOARD_CPU="ARM Cortex A55"
export UBOOT_PACKAGE="u-boot-turing-rk3588"
export UBOOT_RULES_TARGET="radxa-zero3-rk3566"

function config_image_hook__radxa-zero3() {
    local rootfs="$1"
    local overlay="$2"

    # Kernel modules to blacklist
    (
        echo "blacklist aic8800_bsp"
        echo "blacklist aic8800_fdrv"
        echo "blacklist aic8800_btlpm"
    ) > "${rootfs}/etc/modprobe.d/aic8800.conf"

    # Install AIC8800 SDIO WiFi and Bluetooth DKMS
    chroot "${rootfs}" apt-get -y install dkms aic8800-firmware aic8800-sdio-dkms

    # shellcheck disable=SC2016
    echo 'SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="88:00:*", NAME="$ENV{ID_NET_SLOT}"' > "${rootfs}/etc/udev/rules.d/99-radxa-aic8800.rules"

    # Enable the on-board bluetooth module AIC8800
    mkdir -p "${rootfs}/usr/lib/scripts/"
    cp "${overlay}/usr/bin/bt_test" "${rootfs}/usr/bin/bt_test"
    cp "${overlay}/usr/lib/scripts/aic8800-bluetooth.sh" "${rootfs}/usr/lib/scripts/aic8800-bluetooth.sh"
    cp "${overlay}/usr/lib/systemd/system/aic8800-bluetooth.service" "${rootfs}/usr/lib/systemd/system/aic8800-bluetooth.service"
    chroot "${rootfs}" systemctl enable aic8800-bluetooth

    return 0
}
