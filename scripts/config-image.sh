#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

if [ "$(id -u)" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..
mkdir -p build && cd build

if [[ -z ${BOARD} ]]; then
    echo "Error: BOARD is not set"
    exit 1
fi

if [[ -z ${VENDOR} ]]; then
    echo "Error: VENDOR is not set"
    exit 1
fi

if [[ ${LAUNCHPAD} != "Y" ]]; then
    uboot_package="$(basename "$(find u-boot-"${BOARD}"_*.deb | sort | tail -n1)")"
    if [ ! -e "$uboot_package" ]; then
        echo 'Error: could not find the u-boot .deb file'
        exit 1
    fi

    linux_image_package="$(basename "$(find linux-image-*.deb | sort | tail -n1)")"
    if [ ! -e "$linux_image_package" ]; then
        echo 'Error: could not find the linux image .deb file'
        exit 1
    fi

    linux_headers_package="$(basename "$(find linux-headers-*.deb | sort | tail -n1)")"
    if [ ! -e "$linux_headers_package" ]; then
        echo 'Error: could not find the linux headers .deb file'
        exit 1
    fi
fi

if [[ ${SERVER_ONLY} == "Y" ]]; then
    target="server"
elif [[ ${DESKTOP_ONLY} == "Y" ]]; then
    target="desktop"
else
    target="server desktop"
fi

# These env vars can cause issues with chroot
unset TMP
unset TEMP
unset TMPDIR

# Prevent dpkg interactive dialogues
export DEBIAN_FRONTEND=noninteractive

# Debootstrap options
chroot_dir=rootfs
overlay_dir=../overlay

for type in $target; do

    # Clean chroot dir and make sure folder is not mounted
    umount -lf ${chroot_dir}/dev/pts 2> /dev/null || true
    umount -lf ${chroot_dir}/* 2> /dev/null || true
    rm -rf ${chroot_dir}
    mkdir -p ${chroot_dir}

    tar -xpJf ubuntu-22.04.3-preinstalled-${type}-arm64.rootfs.tar.xz -C ${chroot_dir}

    # Mount the temporary API filesystems
    mkdir -p ${chroot_dir}/{proc,sys,run,dev,dev/pts}
    mount -t proc /proc ${chroot_dir}/proc
    mount -t sysfs /sys ${chroot_dir}/sys
    mount -o bind /dev ${chroot_dir}/dev
    mount -o bind /dev/pts ${chroot_dir}/dev/pts

    # Board specific changes
    if [ "${BOARD}" == orangepi-5-plus ]; then
    {
        echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-hdmi0-sound", ENV{SOUND_DESCRIPTION}="HDMI0 Audio"'
        echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-hdmi1-sound", ENV{SOUND_DESCRIPTION}="HDMI1 Audio"'
        echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-hdmiin-sound", ENV{SOUND_DESCRIPTION}="HDMI-In Audio"'
        echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-dp0-sound", ENV{SOUND_DESCRIPTION}="DP0 Audio"'
        echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-es8388-sound", ENV{SOUND_DESCRIPTION}="ES8388 Audio"'
    } > ${chroot_dir}/etc/udev/rules.d/90-naming-audios.rules

        # Fix WiFi not working when bluetooth enabled for the official RTL8852BE WiFi + BT card
        cp ${overlay_dir}/usr/lib/systemd/system/rtl8852be-reload.service ${chroot_dir}/usr/lib/systemd/system/rtl8852be-reload.service
        chroot ${chroot_dir} /bin/bash -c "systemctl enable rtl8852be-reload"

        chroot ${chroot_dir} /bin/bash -c "apt-get -y install wiringpi-opi libwiringpi2-opi libwiringpi-opi-dev"
        echo "BOARD=orangepi5plus" > ${chroot_dir}/etc/orangepi-release
    elif [ "${BOARD}" == orangepi-5 ] || [ "${BOARD}" == orangepi-5b ]; then
    {
        echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-hdmi0-sound", ENV{SOUND_DESCRIPTION}="HDMI0 Audio"'
        echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-dp0-sound", ENV{SOUND_DESCRIPTION}="DP0 Audio"'
        echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-es8388-sound", ENV{SOUND_DESCRIPTION}="ES8388 Audio"'
    } > ${chroot_dir}/etc/udev/rules.d/90-naming-audios.rules

        # Enable bluetooth for AP6275P
        cp ${overlay_dir}/usr/lib/systemd/system/ap6275p-bluetooth.service ${chroot_dir}/usr/lib/systemd/system/ap6275p-bluetooth.service
        cp ${overlay_dir}/usr/lib/scripts/ap6275p-bluetooth.sh ${chroot_dir}/usr/lib/scripts/ap6275p-bluetooth.sh
        cp ${overlay_dir}/usr/bin/brcm_patchram_plus ${chroot_dir}/usr/bin/brcm_patchram_plus
        chroot ${chroot_dir} /bin/bash -c "systemctl enable ap6275p-bluetooth"

        # Enable USB 2.0 port
        cp ${overlay_dir}/usr/lib/systemd/system/enable-usb2.service ${chroot_dir}/usr/lib/systemd/system/enable-usb2.service
        chroot ${chroot_dir} /bin/bash -c "systemctl --no-reload enable enable-usb2"

        chroot ${chroot_dir} /bin/bash -c "apt-get -y install wiringpi-opi libwiringpi2-opi libwiringpi-opi-dev"
        echo "BOARD=orangepi5" > ${chroot_dir}/etc/orangepi-release
    elif [ "${BOARD}" == rock-5a ]; then
    {
        echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-hdmi0-sound", ENV{SOUND_DESCRIPTION}="HDMI0 Audio"'
        echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-dp0-sound", ENV{SOUND_DESCRIPTION}="HDMI1 Audio"'
        echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-es8316-sound", ENV{SOUND_DESCRIPTION}="ES8316 Audio"'
    } > ${chroot_dir}/etc/udev/rules.d/90-naming-audios.rules

        cp ${overlay_dir}/usr/lib/scripts/alsa-audio-config ${chroot_dir}/usr/lib/scripts/alsa-audio-config
        cp ${overlay_dir}/usr/lib/systemd/system/alsa-audio-config.service ${chroot_dir}/usr/lib/systemd/system/alsa-audio-config.service
        chroot ${chroot_dir} /bin/bash -c "systemctl enable alsa-audio-config"
    elif [ "${BOARD}" == rock-5b ]; then
    {
        echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-hdmi0-sound", ENV{SOUND_DESCRIPTION}="HDMI0 Audio"'
        echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-hdmi1-sound", ENV{SOUND_DESCRIPTION}="HDMI1 Audio"'
        echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-hdmiin-sound", ENV{SOUND_DESCRIPTION}="HDMI-In Audio"'
        echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-dp0-sound", ENV{SOUND_DESCRIPTION}="DP0 Audio"'
        echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-es8316-sound", ENV{SOUND_DESCRIPTION}="ES8316 Audio"'
    } > ${chroot_dir}/etc/udev/rules.d/90-naming-audios.rules

        cp ${overlay_dir}/usr/lib/scripts/alsa-audio-config ${chroot_dir}/usr/lib/scripts/alsa-audio-config
        cp ${overlay_dir}/usr/lib/systemd/system/alsa-audio-config.service ${chroot_dir}/usr/lib/systemd/system/alsa-audio-config.service
        chroot ${chroot_dir} /bin/bash -c "systemctl enable alsa-audio-config"
    elif [ "${BOARD}" == radxa-cm5-io ]; then
    {
        echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-hdmi0-sound", ENV{SOUND_DESCRIPTION}="HDMI0 Audio"'
        echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-dp0-sound", ENV{SOUND_DESCRIPTION}="DP0 Audio"'
        echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-es8316-sound", ENV{SOUND_DESCRIPTION}="ES8316 Audio"'
    } > ${chroot_dir}/etc/udev/rules.d/90-naming-audios.rules

        cp ${overlay_dir}/usr/lib/scripts/alsa-audio-config ${chroot_dir}/usr/lib/scripts/alsa-audio-config
        cp ${overlay_dir}/usr/lib/systemd/system/alsa-audio-config.service ${chroot_dir}/usr/lib/systemd/system/alsa-audio-config.service
        chroot ${chroot_dir} /bin/bash -c "systemctl enable alsa-audio-config"
    elif [ "${BOARD}" == nanopi-r6c ] || [ "${BOARD}" == nanopi-r6s ]; then
    {
        echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-hdmi0-sound", ENV{SOUND_DESCRIPTION}="HDMI0 Audio"'
    } > ${chroot_dir}/etc/udev/rules.d/90-naming-audios.rules

        cp ${overlay_dir}/etc/init.d/friendlyelec-leds.sh ${chroot_dir}/etc/init.d/friendlyelec-leds.sh
        chroot ${chroot_dir} /bin/bash -c "update-rc.d friendlyelec-leds.sh defaults"
    elif [ "${BOARD}" == nanopc-t6 ]; then
    {
        echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-hdmi0-sound", ENV{SOUND_DESCRIPTION}="HDMI0 Audio"'
        echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-hdmi1-sound", ENV{SOUND_DESCRIPTION}="HDMI1 Audio"'
        echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-hdmiin-sound", ENV{SOUND_DESCRIPTION}="HDMI-In Audio"'
        echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-dp0-sound", ENV{SOUND_DESCRIPTION}="DP0 Audio"'
        echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-rt5616-sound", ENV{SOUND_DESCRIPTION}="RT5616 Audio"'
    } > ${chroot_dir}/etc/udev/rules.d/90-naming-audios.rules
    elif [ "${BOARD}" == mixtile-blade3 ]; then
    {
        echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-hdmi0-sound", ENV{SOUND_DESCRIPTION}="HDMI0 Audio"'
        echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-hdmiin-sound", ENV{SOUND_DESCRIPTION}="HDMI-In Audio"'
        echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-dp0-sound", ENV{SOUND_DESCRIPTION}="DP0 Audio"'
        echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-dp1-sound", ENV{SOUND_DESCRIPTION}="DP1 Audio"'
    } > ${chroot_dir}/etc/udev/rules.d/90-naming-audios.rules
    elif [ "${BOARD}" == indiedroid-nova ]; then
    {
        echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-hdmi0-sound", ENV{SOUND_DESCRIPTION}="HDMI0 Audio"'
        echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-dp0-sound", ENV{SOUND_DESCRIPTION}="DP0 Audio"'
        echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-es8388-sound", ENV{SOUND_DESCRIPTION}="ES8388 Audio"'
    } > ${chroot_dir}/etc/udev/rules.d/90-naming-audios.rules

        cp ${overlay_dir}/usr/bin/rtk_hciattach ${chroot_dir}/usr/bin/rtk_hciattach
        cp ${overlay_dir}/usr/bin/bt_load_rtk_firmware ${chroot_dir}/usr/bin/bt_load_rtk_firmware
        cp ${overlay_dir}/usr/lib/systemd/system/rtl8821cs-bluetooth.service ${chroot_dir}/usr/lib/systemd/system/rtl8821cs-bluetooth.service
        chroot ${chroot_dir} /bin/bash -c "systemctl enable rtl8821cs-bluetooth"
    elif [ "${BOARD}" == lubancat-4 ]; then
    {
        echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-hdmi0-sound", ENV{SOUND_DESCRIPTION}="HDMI0 Audio"'
        echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-dp0-sound", ENV{SOUND_DESCRIPTION}="DP0 Audio"'
        echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-es8388-sound", ENV{SOUND_DESCRIPTION}="ES8388 Audio"'
    } > ${chroot_dir}/etc/udev/rules.d/90-naming-audios.rules
    elif [ "${BOARD}" == turing-rk1 ]; then
    {
        echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-hdmi0-sound", ENV{SOUND_DESCRIPTION}="HDMI0 Audio"'
        echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-dp0-sound", ENV{SOUND_DESCRIPTION}="DP0 Audio"'
    } > ${chroot_dir}/etc/udev/rules.d/90-naming-audios.rules
    fi

    if [[ ${type} == "desktop" ]]; then
        if [ "${BOARD}" == orangepi-5 ] || [ "${BOARD}" == orangepi-5b ] || [ "${BOARD}" == nanopi-r6c ] || [ "${BOARD}" == nanopi-r6s ] || [ "${BOARD}" == turing-rk1 ]; then
            echo "set-default-sink alsa_output.platform-hdmi0-sound.stereo-fallback" >> ${chroot_dir}/etc/pulse/default.pa
        fi
    fi

    # Install the bootloader
    if [[ ${LAUNCHPAD}  == "Y" ]]; then
        chroot ${chroot_dir} /bin/bash -c "apt-get -y install u-boot-${BOARD}"
    else
        cp "${uboot_package}" ${chroot_dir}/tmp/
        chroot ${chroot_dir} /bin/bash -c "dpkg -i /tmp/${uboot_package} && rm -rf /tmp/*"
        chroot ${chroot_dir} /bin/bash -c "apt-mark hold $(echo "${uboot_package}" | sed -rn 's/(.*)_[[:digit:]].*/\1/p')"
    fi

    # Install the kernel
    if [[ ${LAUNCHPAD}  == "Y" ]]; then
        chroot ${chroot_dir} /bin/bash -c "apt-get -y install linux-rockchip-5.10"
        chroot ${chroot_dir} /bin/bash -c "depmod -a 5.10.160-rockchip"
    else
        cp "${linux_image_package}" "${linux_headers_package}" ${chroot_dir}/tmp/
        chroot ${chroot_dir} /bin/bash -c "dpkg -i /tmp/{${linux_image_package},${linux_headers_package}} && rm -rf /tmp/*"
        chroot ${chroot_dir} /bin/bash -c "depmod -a $(echo "${linux_image_package}" | sed -rn 's/linux-image-(.*)_[[:digit:]].*/\1/p')"
        chroot ${chroot_dir} /bin/bash -c "apt-mark hold $(echo "${linux_image_package}" | sed -rn 's/(.*)_[[:digit:]].*/\1/p')"
        chroot ${chroot_dir} /bin/bash -c "apt-mark hold $(echo "${linux_headers_package}" | sed -rn 's/(.*)_[[:digit:]].*/\1/p')"
    fi

    # Clean package cache
    chroot ${chroot_dir} /bin/bash -c "apt-get -y autoremove && apt-get -y clean && apt-get -y autoclean"

    # Copy kernel and initrd for the boot partition
    mkdir -p ${chroot_dir}/boot/firmware/
    cp ${chroot_dir}/boot/initrd.img-* ${chroot_dir}/boot/firmware/initrd.img
    cp ${chroot_dir}/boot/vmlinuz-* ${chroot_dir}/boot/firmware/vmlinuz

    # Copy device trees and overlays for the boot partition
    mkdir -p ${chroot_dir}/boot/firmware/dtbs/
    cp -r ${chroot_dir}/usr/lib/linux-image-*/. ${chroot_dir}/boot/firmware/dtbs/

    # Umount temporary API filesystems
    umount -lf ${chroot_dir}/dev/pts 2> /dev/null || true
    umount -lf ${chroot_dir}/* 2> /dev/null || true

    # Tar the entire rootfs
    cd ${chroot_dir} && tar -cpf ../ubuntu-22.04.3-preinstalled-${type}-arm64-"${BOARD}".rootfs.tar . && cd ..
    ../scripts/build-image.sh ubuntu-22.04.3-preinstalled-${type}-arm64-"${BOARD}".rootfs.tar
    rm -f ubuntu-22.04.3-preinstalled-${type}-arm64-"${BOARD}".rootfs.tar
done
