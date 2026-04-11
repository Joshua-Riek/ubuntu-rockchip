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
        # Use the Broadcom BCMDHD SDIO driver for the AP6256 module
        chroot "${rootfs}" apt-get -y install dkms bcmdhd-sdio-dkms

        cat <<'EOF' > "${rootfs}/etc/modprobe.d/ap6256-bcmdhd.conf"
options bcmdhd_sdio firmware_path=/lib/firmware/fw_bcm43456c5_ag.bin nvram_path=/lib/firmware/nvram_ap6256.txt config_path=/lib/firmware/config.txt op_mode=0 iface_name=wlan0
EOF

        cat <<'EOF' > "${rootfs}/etc/modprobe.d/ap6256-brcmfmac-blacklist.conf"
blacklist brcmfmac
blacklist brcmutil
EOF

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

        # Ensure the SDIO Wi-Fi module is powered down cleanly before shutdown/reboot
        cp "${overlay}/usr/lib/systemd/system/ap6256-poweroff.service" "${rootfs}/usr/lib/systemd/system/ap6256-poweroff.service"
        chroot "${rootfs}" systemctl enable ap6256-poweroff.service

        # Install wiring orangepi package 
        chroot "${rootfs}" apt-get -y install wiringpi-opi libwiringpi2-opi libwiringpi-opi-dev
        echo "BOARD=orangepi5pro" > "${rootfs}/etc/orangepi-release"
    fi

    return 0
}
