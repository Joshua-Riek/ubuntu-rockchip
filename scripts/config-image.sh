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
    for file in linux-{headers,image}-5.10.160-rockchip_*.deb; do
        if [ ! -e "$file" ]; then
            echo "Error: missing kernel debs, please run build-kernel.sh"
            exit 1
        fi
    done
    for file in u-boot-"${BOARD}"_*.deb; do
        if [ ! -e "$file" ]; then
            echo "Error: missing u-boot deb, please run build-u-boot.sh"
            exit 1
        fi
    done
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

for type in server desktop; do

    # Clean chroot dir and make sure folder is not mounted
    umount -lf ${chroot_dir}/dev/pts 2> /dev/null || true
    umount -lf ${chroot_dir}/* 2> /dev/null || true
    rm -rf ${chroot_dir}
    mkdir -p ${chroot_dir}

    tar -xpJf ubuntu-22.04.2-preinstalled-${type}-arm64.rootfs.tar.xz -C ${chroot_dir}

    # Mount the temporary API filesystems
    mkdir -p ${chroot_dir}/{proc,sys,run,dev,dev/pts}
    mount -t proc /proc ${chroot_dir}/proc
    mount -t sysfs /sys ${chroot_dir}/sys
    mount -o bind /dev ${chroot_dir}/dev
    mount -o bind /dev/pts ${chroot_dir}/dev/pts

    # Install the kernel
    if [[ ${LAUNCHPAD}  == "Y" ]]; then
        chroot ${chroot_dir} /bin/bash -c "apt-get -y install linux-image-5.10.160-rockchip linux-headers-5.10.160-rockchip"
    else
        cp linux-{headers,image}-5.10.160-rockchip_*.deb ${chroot_dir}/tmp
        chroot ${chroot_dir} /bin/bash -c "dpkg -i /tmp/linux-{headers,image}-5.10.160-rockchip_*.deb && rm -rf /tmp/*"
        chroot ${chroot_dir} /bin/bash -c "apt-mark hold linux-image-5.10.160-rockchip linux-headers-5.10.160-rockchip"
    fi

    # Generate kernel module dependencies
    chroot ${chroot_dir} /bin/bash -c "depmod -a 5.10.160-rockchip"

    # Copy device trees and overlays
    mkdir -p ${chroot_dir}/boot/firmware/dtbs/overlays
    cp ${chroot_dir}/usr/lib/linux-image-5.10.160-rockchip/rockchip/*.dtb ${chroot_dir}/boot/firmware/dtbs
    cp ${chroot_dir}/usr/lib/linux-image-5.10.160-rockchip/rockchip/overlay/*.dtbo ${chroot_dir}/boot/firmware/dtbs/overlays

    # Install the bootloader
    if [[ ${LAUNCHPAD}  == "Y" ]]; then
        chroot ${chroot_dir} /bin/bash -c "apt-get -y install u-boot-${BOARD}"
    else
        cp u-boot-"${BOARD}"_*.deb ${chroot_dir}/tmp
        chroot ${chroot_dir} /bin/bash -c "dpkg -i /tmp/u-boot-${BOARD}_*.deb && rm -rf /tmp/*"
        chroot ${chroot_dir} /bin/bash -c "apt-mark hold u-boot-${BOARD}"
    fi

    # Board specific changes
    if [ "${BOARD}" == orangepi-5-plus ]; then
    {
        echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-hdmi0-sound", ENV{SOUND_DESCRIPTION}="HDMI0 Audio"'
        echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-hdmi1-sound", ENV{SOUND_DESCRIPTION}="HDMI1 Audio"'
        echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-hdmiin-sound", ENV{SOUND_DESCRIPTION}="HDMI-In Audio"'
        echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-dp0-sound", ENV{SOUND_DESCRIPTION}="DP0 Audio"'
        echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-es8388-sound", ENV{SOUND_DESCRIPTION}="ES8388 Audio"'
    } > ${chroot_dir}/etc/udev/rules.d/90-naming-audios.rules

        chroot ${chroot_dir} /bin/bash -c "apt-get -y install wiringpi-opi libwiringpi2-opi libwiringpi-opi-dev"
        echo "BOARD=orangepi5plus" > ${chroot_dir}/etc/orangepi-release
    elif [ "${BOARD}" == orangepi-5 ] || [ "${BOARD}" == orangepi-5b ]; then
    {
        echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-hdmi0-sound", ENV{SOUND_DESCRIPTION}="HDMI0 Audio"'
        echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-dp0-sound", ENV{SOUND_DESCRIPTION}="DP0 Audio"'
        echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-es8388-sound", ENV{SOUND_DESCRIPTION}="ES8388 Audio"'
    } > ${chroot_dir}/etc/udev/rules.d/90-naming-audios.rules

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
        cp ${overlay_dir}/etc/init.d/friendlyelec-leds.sh ${chroot_dir}/etc/init.d/friendlyelec-leds.sh
        chroot ${chroot_dir} /bin/bash -c "update-rc.d friendlyelec-leds.sh defaults"
    } > ${chroot_dir}/etc/udev/rules.d/90-naming-audios.rules
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
        cp ${overlay_dir}/usr/bin/rtk_hciattach ${chroot_dir}/usr/bin/rtk_hciattach
        cp ${overlay_dir}/usr/bin/bt_load_rtk_firmware ${chroot_dir}/usr/bin/bt_load_rtk_firmware
        cp ${overlay_dir}/usr/lib/systemd/system/rtl8821cs-bluetooth.service ${chroot_dir}/usr/lib/systemd/system/rtl8821cs-bluetooth.service
        chroot ${chroot_dir} /bin/bash -c "systemctl enable rtl8821cs-bluetooth"
    fi

    if [[ ${type} == "desktop" ]]; then
        if [ "${BOARD}" == orangepi-5 ] || [ "${BOARD}" == orangepi-5b ] || [ "${BOARD}" == nanopi-r6c ] || [ "${BOARD}" == nanopi-r6s ]; then
            echo "set-default-sink alsa_output.platform-hdmi0-sound.stereo-fallback" >> ${chroot_dir}/etc/pulse/default.pa
        elif [ "${BOARD}" == indiedroid-nova ]; then
            echo "set-default-sink 1" >> ${chroot_dir}/etc/pulse/default.pa
        fi
    fi

    # Update initramfs
    chroot ${chroot_dir} /bin/bash -c "update-initramfs -u"

    # Umount temporary API filesystems
    umount -lf ${chroot_dir}/dev/pts 2> /dev/null || true
    umount -lf ${chroot_dir}/* 2> /dev/null || true

    # Tar the entire rootfs
    cd ${chroot_dir} && tar -cpf ../ubuntu-22.04.2-preinstalled-${type}-arm64-"${BOARD}".rootfs.tar . && cd ..
    ../scripts/build-image.sh ubuntu-22.04.2-preinstalled-${type}-arm64-"${BOARD}".rootfs.tar
    rm -f ubuntu-22.04.2-preinstalled-${type}-arm64-"${BOARD}".rootfs.tar
done
