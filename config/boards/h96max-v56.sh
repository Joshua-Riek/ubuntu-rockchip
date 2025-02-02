# shellcheck shell=bash

export BOARD_NAME="h96 v56 tvbox"
export BOARD_MAKER="h96-max"
export BOARD_SOC="Rockchip RK3566"
export BOARD_CPU="ARM Cortex A55"
export UBOOT_PACKAGE="u-boot-rk3566"
export UBOOT_RULES_TARGET="h96max-v56-rk3566"
export COMPATIBLE_SUITES=("jammy" "noble")
export COMPATIBLE_FLAVORS=("server" "desktop")

function config_image_hook__h96max-v56() {
    local rootfs="$1"
    local overlay="$2"
    local suite="$3"

    if [ "${suite}" == "jammy" ] || [ "${suite}" == "noble" ]; then
        # Kernel modules to load at boot time
        echo "sprdbt_tty" >> "${rootfs}/etc/modules"
        echo "sprdwl_ng" >> "${rootfs}/etc/modules"
    
        # Install BCMDHD SDIO WiFi and Bluetooth DKMS
        chroot "${rootfs}" apt-get -y install dkms bcmdhd-sdio-dkms

        # Enable bluetooth for AP6275P
        mkdir -p "${rootfs}/usr/lib/scripts"
        cp "${overlay}/usr/lib/systemd/system/ap6275p-bluetooth.service" "${rootfs}/usr/lib/systemd/system/ap6275p-bluetooth.service"
        cp "${overlay}/usr/lib/scripts/ap6275p-bluetooth.sh" "${rootfs}/usr/lib/scripts/ap6275p-bluetooth.sh"
        cp "${overlay}/usr/bin/brcm_patchram_plus" "${rootfs}/usr/bin/brcm_patchram_plus"
        chroot "${rootfs}" systemctl enable ap6275p-bluetooth
    fi

    return 0
}