# shellcheck shell=bash

export BOARD_NAME="ArmSoM Sige5"
export BOARD_MAKER="ArmSoM"
export BOARD_SOC="Rockchip RK3576"
export BOARD_CPU="ARM Cortex A72 / A53"
export UBOOT_PACKAGE="u-boot-rk3576"
export UBOOT_RULES_TARGET="armsom-sige5-rk3576"
export COMPATIBLE_SUITES=("noble")
export COMPATIBLE_FLAVORS=("server" "desktop")

function config_image_hook__armsom-sige5() {
    local rootfs="$1"

    # Kernel modules to blacklist
    echo "blacklist panfrost" > "${rootfs}/etc/modprobe.d/panfrost.conf"

    return 0
}
