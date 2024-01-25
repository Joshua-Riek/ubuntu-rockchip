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

if [[ -z ${KERNEL_TARGET} ]]; then
    echo "Error: KERNEL_TARGET is not set"
    exit 1
fi

# shellcheck source=/dev/null
source ../config/kernels/"${KERNEL_TARGET}.conf"

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
    target="preinstalled-server"
elif [[ ${DESKTOP_ONLY} == "Y" ]]; then
    target="preinstalled-desktop"
else
    target="preinstalled-server preinstalled-desktop"
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

    tar -xpJf ubuntu-22.04.3-${type}-arm64.rootfs.tar.xz -C ${chroot_dir}

    # Mount the temporary API filesystems
    mkdir -p ${chroot_dir}/{proc,sys,run,dev,dev/pts}
    mount -t proc /proc ${chroot_dir}/proc
    mount -t sysfs /sys ${chroot_dir}/sys
    mount -o bind /dev ${chroot_dir}/dev
    mount -o bind /dev/pts ${chroot_dir}/dev/pts

    if [ "${KERNEL_TARGET}" == "bsp" ]; then
        if [ "${OVERLAY_PREFIX}" == "rk3588" ]; then
            # Pin and add panfork mesa ppa
            cp ${overlay_dir}/etc/apt/preferences.d/panfork-mesa-ppa ${chroot_dir}/etc/apt/preferences.d/panfork-mesa-ppa
            chroot ${chroot_dir} /bin/bash -c "add-apt-repository -y ppa:liujianfeng1994/panfork-mesa"

            # Set cpu governor to performance
            cp ${overlay_dir}/usr/lib/systemd/system/cpu-governor-performance.service ${chroot_dir}/usr/lib/systemd/system/cpu-governor-performance.service
            chroot ${chroot_dir} /bin/bash -c "systemctl enable cpu-governor-performance"

            # Set gpu governor to performance
            cp ${overlay_dir}/usr/lib/systemd/system/gpu-governor-performance.service ${chroot_dir}/usr/lib/systemd/system/gpu-governor-performance.service
            chroot ${chroot_dir} /bin/bash -c "systemctl enable gpu-governor-performance"
        fi

        # Pin and add rockchip multimedia ppa
        cp ${overlay_dir}/etc/apt/preferences.d/rockchip-multimedia-ppa ${chroot_dir}/etc/apt/preferences.d/rockchip-multimedia-ppa
        chroot ${chroot_dir} /bin/bash -c "add-apt-repository -y ppa:liujianfeng1994/rockchip-multimedia"

        # Download and update installed packages
        chroot ${chroot_dir} /bin/bash -c "apt-get -y update && apt-get -y upgrade && apt-get -y dist-upgrade"

        # Realtek 8811CU/8821CU usb modeswitch support
        cp ${chroot_dir}/lib/udev/rules.d/40-usb_modeswitch.rules ${chroot_dir}/etc/udev/rules.d/40-usb_modeswitch.rules
        sed '/LABEL="modeswitch_rules_end"/d' -i ${chroot_dir}/etc/udev/rules.d/40-usb_modeswitch.rules
        echo '# Realtek 8811CU/8821CU Wifi AC USB' >> ${chroot_dir}/etc/udev/rules.d/40-usb_modeswitch.rules
        echo 'ATTR{idVendor}=="0bda", ATTR{idProduct}=="1a2b", RUN+="/usr/sbin/usb_modeswitch -K -v 0bda -p 1a2b"' >> ${chroot_dir}/etc/udev/rules.d/40-usb_modeswitch.rules
        echo 'LABEL="modeswitch_rules_end"' >> ${chroot_dir}/etc/udev/rules.d/40-usb_modeswitch.rules

        # Add usb modeswitch and realtek firmware to initrd this fixes a boot hang with 8811CU/8821CU
        cp ${overlay_dir}/usr/share/initramfs-tools/hooks/usb_modeswitch ${chroot_dir}/usr/share/initramfs-tools/hooks/usb_modeswitch
        cp ${overlay_dir}/usr/share/initramfs-tools/hooks/rtl-bt ${chroot_dir}/usr/share/initramfs-tools/hooks/rtl-bt

        if [[ $type == "preinstalled-desktop" ]]; then
            if [ "${OVERLAY_PREFIX}" == "rk3588" ]; then
                # Install rkaiq and rkisp
                cp -r ../packages/rkaiq/camera_engine_*_arm64.deb ${chroot_dir}/tmp
                chroot ${chroot_dir} /bin/bash -c "dpkg -i /tmp/camera_engine_rkaiq_rk3588_1.0.3_arm64.deb"
                chroot ${chroot_dir} /bin/bash -c "dpkg -i /tmp/camera_engine_rkaiq_rk3588_update_arm64.deb"
                chroot ${chroot_dir} /bin/bash -c "dpkg -i /tmp/camera_engine_rkisp-v2.2.0_arm64.deb"
                rm -f ${chroot_dir}/tmp/camera_engine_*_arm64.deb

                # Hack for GDM to restart on first HDMI hotplug
                mkdir -p ${chroot_dir}/usr/lib/scripts
                cp ${overlay_dir}/usr/lib/scripts/gdm-hack.sh ${chroot_dir}/usr/lib/scripts/gdm-hack.sh
                cp ${overlay_dir}/etc/udev/rules.d/99-gdm-hack.rules ${chroot_dir}/etc/udev/rules.d/99-gdm-hack.rules

                chroot ${chroot_dir} /bin/bash -c "apt-get -y install libwidevinecdm librockchip-mpp1 librockchip-mpp-dev librockchip-vpu0 libv4l-rkmpp librist-dev librist4 librga2 librga-dev rist-tools rockchip-mpp-demos rockchip-multimedia-config gstreamer1.0-rockchip1 chromium-browser mali-g610-firmware malirun"
            else
                chroot ${chroot_dir} /bin/bash -c "apt-get -y install libwidevinecdm rockchip-multimedia-config chromium-browser"
            fi

            # Chromium uses fixed paths for libv4l2.so
            chroot ${chroot_dir} /bin/bash -c "ln -rsf /usr/lib/*/libv4l2.so /usr/lib/"
            chroot ${chroot_dir} /bin/bash -c "[ -e /usr/lib/aarch64-linux-gnu/ ] && ln -Tsf lib /usr/lib64"

            # Config file for mpv
            cp ${overlay_dir}/etc/mpv/mpv.conf ${chroot_dir}/etc/mpv/mpv.conf

            # Use mpv as the default video player
            sed -i 's/org\.gnome\.Totem\.desktop/mpv\.desktop/g' ${chroot_dir}/usr/share/applications/gnome-mimeapps.list 

            # Config file for xorg
            mkdir -p ${chroot_dir}/etc/X11/xorg.conf.d
            cp ${overlay_dir}/etc/X11/xorg.conf.d/20-modesetting.conf ${chroot_dir}/etc/X11/xorg.conf.d/20-modesetting.conf

            # Set chromium inital prefrences
            mkdir -p ${chroot_dir}/usr/lib/chromium-browser
            cp ${overlay_dir}/usr/lib/chromium-browser/initial_preferences ${chroot_dir}/usr/lib/chromium-browser/initial_preferences

            # Set chromium default launch args
            mkdir -p ${chroot_dir}/usr/lib/chromium-browser
            cp ${overlay_dir}/etc/chromium-browser/default ${chroot_dir}/etc/chromium-browser/default

            # Set chromium as default browser
            chroot ${chroot_dir} /bin/bash -c "update-alternatives --install /usr/bin/x-www-browser x-www-browser /usr/bin/chromium-browser 500"
            chroot ${chroot_dir} /bin/bash -c "update-alternatives --set x-www-browser /usr/bin/chromium-browser"
            sed -i 's/firefox-esr\.desktop/chromium-browser\.desktop/g;s/firefox\.desktop;//g' ${chroot_dir}/usr/share/applications/gnome-mimeapps.list 

            # Add chromium to favorites bar
            mkdir -p ${chroot_dir}/etc/dconf/db/local.d
            cp ${overlay_dir}/etc/dconf/db/local.d/00-favorite-apps ${chroot_dir}/etc/dconf/db/local.d/00-favorite-apps
            cp ${overlay_dir}/etc/dconf/profile/user ${chroot_dir}/etc/dconf/profile/user
            chroot ${chroot_dir} /bin/bash -c "dconf update"
        fi
    fi

    # Run config hook to handle board specific changes
    if [[ $(type -t config_image_hook__"${BOARD}") == function ]]; then
        config_image_hook__"${BOARD}"
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
    cd ${chroot_dir} && tar -cpf ../ubuntu-22.04.3-${type}-arm64-"${BOARD}".rootfs.tar . && cd .. && rm -rf ${chroot_dir}
    ../scripts/build-image.sh ubuntu-22.04.3-${type}-arm64-"${BOARD}".rootfs.tar
    rm -f ubuntu-22.04.3-${type}-arm64-"${BOARD}".rootfs.tar
done
