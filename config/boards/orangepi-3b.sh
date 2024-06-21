# shellcheck shell=bash

export BOARD_NAME="Orange Pi 3B"
export BOARD_MAKER="Xulong"
export BOARD_SOC="Rockchip RK3566"
export BOARD_CPU="ARM Cortex A55"
export UBOOT_PACKAGE="u-boot-turing-rk3588"
export UBOOT_RULES_TARGET="orangepi-3b-rk3566"

function config_image_hook__orangepi-3b() {
    local rootfs="$1"
    local overlay="$2"

    # Kernel modules to load at boot time
    echo "sprdbt_tty" >> "${rootfs}/etc/modules"
    echo "sprdwl_ng" >> "${rootfs}/etc/modules"

    # Kernel modules to blacklist
    echo "blacklist bcmdhd" > "${rootfs}/etc/modprobe.d/bcmdhd.conf"

    # Enable bluetooth
    cp "${overlay}/usr/bin/hciattach_opi" "${rootfs}/usr/bin/hciattach_opi"
    cp "${overlay}/usr/lib/systemd/system/sprd-bluetooth.service" "${rootfs}/usr/lib/systemd/system/sprd-bluetooth.service"
    chroot "${rootfs}" systemctl enable sprd-bluetooth

    # Install wiring orangepi package 
    chroot "${rootfs}" apt-get -y install wiringpi-opi libwiringpi2-opi libwiringpi-opi-dev
    echo "BOARD=orangepi3b" > "${rootfs}/etc/orangepi-release"

    return 0
}
