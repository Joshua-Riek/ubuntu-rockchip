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

if [[ -z ${RELEASE} ]]; then
    echo "Error: RELEASE is not set"
    exit 1
fi

# shellcheck source=/dev/null
source ../config/releases/"${RELEASE}.sh"

if [[ ${RELEASE} != "noble" ]]; then
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

setup_mountpoint() {
    local mountpoint="$1"

    if [ ! -c /dev/mem ]; then
        mknod -m 660 /dev/mem c 1 1
        chown root:kmem /dev/mem
    fi

    mount dev-live -t devtmpfs "$mountpoint/dev"
    mount devpts-live -t devpts -o nodev,nosuid "$mountpoint/dev/pts"
    mount proc-live -t proc "$mountpoint/proc"
    mount sysfs-live -t sysfs "$mountpoint/sys"
    mount securityfs -t securityfs "$mountpoint/sys/kernel/security"
    # Provide more up to date apparmor features, matching target kernel
    # cgroup2 mount for LP: 1944004
    mount -t cgroup2 none "$mountpoint/sys/fs/cgroup"
    mount -t tmpfs none "$mountpoint/tmp"
    mount -t tmpfs none "$mountpoint/var/lib/apt/lists"
    mount -t tmpfs none "$mountpoint/var/cache/apt"
    mv "$mountpoint/etc/resolv.conf" resolv.conf.tmp
    cp /etc/resolv.conf "$mountpoint/etc/resolv.conf"
    mv "$mountpoint/etc/nsswitch.conf" nsswitch.conf.tmp
    sed 's/systemd//g' nsswitch.conf.tmp > "$mountpoint/etc/nsswitch.conf"
    chroot "$mountpoint" apt-get update
    chroot "$mountpoint" apt-get -y upgrade
}

teardown_mountpoint() {
    # Reverse the operations from setup_mountpoint
    local mountpoint=$(realpath "$1")

    # Clean package cache and update initramfs
    chroot "$mountpoint" update-initramfs -u
    chroot "$mountpoint" apt-get -y autoremove
    chroot "$mountpoint" apt-get -y clean
    chroot "$mountpoint" apt-get -y autoclean

    # ensure we have exactly one trailing slash, and escape all slashes for awk
    mountpoint_match=$(echo "$mountpoint" | sed -e's,/$,,; s,/,\\/,g;')'\/'
    # sort -r ensures that deeper mountpoints are unmounted first
    for submount in $(awk </proc/self/mounts "\$2 ~ /$mountpoint_match/ \
                      { print \$2 }" | LC_ALL=C sort -r); do
        mount --make-private $submount
        umount $submount
    done
    mv resolv.conf.tmp "$mountpoint/etc/resolv.conf"
    mv nsswitch.conf.tmp "$mountpoint/etc/nsswitch.conf"
}

if [[ ${RELEASE} == "noble" ]]; then
    for type in $target; do
        rm -rf ${chroot_dir} && mkdir -p ${chroot_dir}
        tar -xpJf "ubuntu-${RELASE_VERSION}-${type}-arm64.rootfs.tar.xz" -C ${chroot_dir}

        setup_mountpoint $chroot_dir

        # Run config hook to handle board specific changes
        if [[ $(type -t config_image_hook__"${BOARD}") == function ]]; then
            config_image_hook__"${BOARD}"
        fi 

        chroot ${chroot_dir} apt-get -y install "u-boot-${BOARD}"

        teardown_mountpoint $chroot_dir

        cd ${chroot_dir} && tar -cpf "../ubuntu-${RELASE_VERSION}-${type}-arm64-${BOARD}.rootfs.tar" . && cd .. && rm -rf ${chroot_dir}
        ../scripts/build-image.sh "ubuntu-${RELASE_VERSION}-${type}-arm64-${BOARD}.rootfs.tar"
        rm -f "ubuntu-${RELASE_VERSION}-${type}-arm64-${BOARD}.rootfs.tar"
    done
    exit 0
fi

for type in $target; do

    # Clean chroot dir and make sure folder is not mounted
    umount -lf ${chroot_dir}/dev/pts 2> /dev/null || true
    umount -lf ${chroot_dir}/* 2> /dev/null || true

    rm -rf ${chroot_dir}
    mkdir -p ${chroot_dir}

    tar -xpJf ubuntu-${RELASE_VERSION}-${type}-arm64.rootfs.tar.xz -C ${chroot_dir}

    # Mount the temporary API filesystems
    mkdir -p ${chroot_dir}/{proc,sys,run,dev,dev/pts}
setup_mountpoint $chroot_dir

    chroot ${chroot_dir} /bin/bash -c "apt-get -y update"

    if [ "${KERNEL_TARGET}" == "rockchip-5.10" ] || [ "${KERNEL_TARGET}" == "rockchip-6.1" ]; then
        if [[ ${RELEASE} != "noble" ]]; then
        if [[ ${RELEASE} == "jammy" ]]; then
            cp ${overlay_dir}/etc/apt/preferences.d/rockchip-multimedia-ppa ${chroot_dir}/etc/apt/preferences.d/rockchip-multimedia-ppa
            chroot ${chroot_dir} /bin/bash -c "add-apt-repository -y ppa:liujianfeng1994/rockchip-multimedia"

            if [ "${OVERLAY_PREFIX}" == "rk3588" ]; then
                cp ${overlay_dir}/etc/apt/preferences.d/panfork-mesa-ppa ${chroot_dir}/etc/apt/preferences.d/panfork-mesa-ppa
                chroot ${chroot_dir} /bin/bash -c "add-apt-repository -y ppa:liujianfeng1994/panfork-mesa"
            fi
        else
            cp ${overlay_dir}/etc/apt/preferences.d/jjriek-rockchip-multimedia-ppa ${chroot_dir}/etc/apt/preferences.d/jjriek-rockchip-multimedia-ppa
            chroot ${chroot_dir} /bin/bash -c "add-apt-repository -y ppa:jjriek/rockchip-multimedia"  

            if [ "${OVERLAY_PREFIX}" == "rk3588" ]; then
                cp ${overlay_dir}/etc/apt/preferences.d/jjriek-panfork-mesa-ppa ${chroot_dir}/etc/apt/preferences.d/jjriek-panfork-mesa-ppa
                chroot ${chroot_dir} /bin/bash -c "add-apt-repository -y ppa:jjriek/panfork-mesa" 
            fi
        fi

        # Download and update installed packages
        chroot ${chroot_dir} /bin/bash -c "apt-get -y update && apt-get --allow-downgrades -y upgrade && apt-get --allow-downgrades -y dist-upgrade"

        if [ "${OVERLAY_PREFIX}" == "rk3588" ]; then
            # Set cpu governor to performance
            cp ${overlay_dir}/usr/lib/systemd/system/cpu-governor-performance.service ${chroot_dir}/usr/lib/systemd/system/cpu-governor-performance.service
            chroot ${chroot_dir} /bin/bash -c "systemctl enable cpu-governor-performance"

            # Set gpu governor to performance
            cp ${overlay_dir}/usr/lib/systemd/system/gpu-governor-performance.service ${chroot_dir}/usr/lib/systemd/system/gpu-governor-performance.service
            chroot ${chroot_dir} /bin/bash -c "systemctl enable gpu-governor-performance"

            # Install the mali g610 firmware
            chroot ${chroot_dir} /bin/bash -c "apt-get -y install mali-g610-firmware"
        fi

        # Install the multimedia config
        chroot ${chroot_dir} /bin/bash -c "apt-get -y install rockchip-multimedia-config"

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
            fi

            # Install chrome and gstreamer rockchip
            chroot ${chroot_dir} /bin/bash -c "apt-get -y install gstreamer1.0-rockchip1 chromium-browser libv4l-rkmpp"

            # Set chromium inital prefrences
            mkdir -p ${chroot_dir}/usr/lib/chromium-browser
            cp ${overlay_dir}/usr/lib/chromium-browser/initial_preferences ${chroot_dir}/usr/lib/chromium-browser/initial_preferences

            # Set chromium default launch args
            mkdir -p ${chroot_dir}/usr/lib/chromium-browser
            mkdir -p ${chroot_dir}/etc/chromium-browser
            cp ${overlay_dir}/etc/chromium-browser/default ${chroot_dir}/etc/chromium-browser/default

            # Add chromium to favorites bar
            mkdir -p ${chroot_dir}/etc/dconf/db/local.d
            cp ${overlay_dir}/etc/dconf/db/local.d/00-favorite-apps ${chroot_dir}/etc/dconf/db/local.d/00-favorite-apps
            cp ${overlay_dir}/etc/dconf/profile/user ${chroot_dir}/etc/dconf/profile/user
            chroot ${chroot_dir} /bin/bash -c "dconf update"

            if [[ ${RELEASE} == "jammy" ]]; then
                chroot ${chroot_dir} /bin/bash -c "apt-get -y install libwidevinecdm"

                # Config file for mpv
                cp ${overlay_dir}/etc/mpv/mpv.conf ${chroot_dir}/etc/mpv/mpv.conf

                # Set chromium as default browser
                chroot ${chroot_dir} /bin/bash -c "update-alternatives --install /usr/bin/x-www-browser x-www-browser /usr/bin/chromium-browser 500"
                chroot ${chroot_dir} /bin/bash -c "update-alternatives --set x-www-browser /usr/bin/chromium-browser"

                # Use mpv as the default video player
                sed -i 's/org\.gnome\.Totem\.desktop/mpv\.desktop/g' ${chroot_dir}/usr/share/applications/gnome-mimeapps.list 

                # Set chromium as default browser
                sed -i 's/firefox-esr\.desktop/chromium-browser\.desktop/g;s/firefox\.desktop;//g' ${chroot_dir}/usr/share/applications/gnome-mimeapps.list 
            else
                cp ${overlay_dir}/usr/share/applications/mimeapps.list ${chroot_dir}/usr/share/applications/mimeapps.list
            fi
        fi
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
        if [[ ${RELEASE} == "jammy" ]]; then
            chroot ${chroot_dir} /bin/bash -c "apt-get -y install linux-rockchip-5.10"
            chroot ${chroot_dir} /bin/bash -c "depmod -a 5.10.160-rockchip"
        fi
    else
        cp "${linux_image_package}" "${linux_headers_package}" ${chroot_dir}/tmp/
        chroot ${chroot_dir} /bin/bash -c "dpkg -i /tmp/{${linux_image_package},${linux_headers_package}} && rm -rf /tmp/*"
        chroot ${chroot_dir} /bin/bash -c "depmod -a $(echo "${linux_image_package}" | sed -rn 's/linux-image-(.*)_[[:digit:]].*/\1/p')"
        chroot ${chroot_dir} /bin/bash -c "apt-mark hold $(echo "${linux_image_package}" | sed -rn 's/(.*)_[[:digit:]].*/\1/p')"
        chroot ${chroot_dir} /bin/bash -c "apt-mark hold $(echo "${linux_headers_package}" | sed -rn 's/(.*)_[[:digit:]].*/\1/p')"
    fi
    chroot ${chroot_dir} /bin/bash -c "apt-get -y purge flash-kernel"
    chroot ${chroot_dir} /bin/bash -c "apt-get -y install u-boot-menu"
    chroot ${chroot_dir} /bin/bash -c "update-initramfs -u"

    # Clean package cache
    chroot ${chroot_dir} /bin/bash -c "apt-get -y autoremove && apt-get -y clean && apt-get -y autoclean"
teardown_mountpoint $chroot_dir
    # Umount temporary API filesystems
    umount -lf ${chroot_dir}/dev/pts 2> /dev/null || true
    umount -lf ${chroot_dir}/* 2> /dev/null || true

    # Tar the entire rootfs
    cd ${chroot_dir} && tar -cpf ../ubuntu-${RELASE_VERSION}-${type}-arm64-"${BOARD}".rootfs.tar . && cd .. && rm -rf ${chroot_dir}
    ../scripts/build-image.sh ubuntu-${RELASE_VERSION}-${type}-arm64-"${BOARD}".rootfs.tar
    rm -f ubuntu-${RELASE_VERSION}-${type}-arm64-"${BOARD}".rootfs.tar
done
