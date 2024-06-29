# shellcheck shell=bash

export BOARD_NAME="ArmSoM Sige5"
export BOARD_MAKER="ArmSoM"
export BOARD_SOC="Rockchip RK3576"
export BOARD_CPU="ARM Cortex A76 / A55"
export UBOOT_PACKAGE="u-boot-armsom-rk3576"
export UBOOT_RULES_TARGET="armsom-sige5-rk3576"

function config_image_hook__armsom-sige5() {

    return 0
}
