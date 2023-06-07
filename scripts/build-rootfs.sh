#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

if [ "$(id -u)" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..
mkdir -p build && cd build

if [[ -f ubuntu-22.04.2-preinstalled-server-arm64.rootfs.tar.xz && -f ubuntu-22.04.2-preinstalled-desktop-arm64.rootfs.tar.xz ]]; then
    exit 0
fi

# These env vars can cause issues with chroot
unset TMP
unset TEMP
unset TMPDIR

# Prevent dpkg interactive dialogues
export DEBIAN_FRONTEND=noninteractive

# Debootstrap options
arch=arm64
release=jammy
mirror=http://ports.ubuntu.com/ubuntu-ports
chroot_dir=rootfs
overlay_dir=../overlay

# Clean chroot dir and make sure folder is not mounted
umount -lf ${chroot_dir}/dev/pts 2> /dev/null || true
umount -lf ${chroot_dir}/* 2> /dev/null || true
rm -rf ${chroot_dir}
mkdir -p ${chroot_dir}

# Install the base system into a directory 
debootstrap --arch ${arch} ${release} ${chroot_dir} ${mirror}

# Use a more complete sources.list file 
cat > ${chroot_dir}/etc/apt/sources.list << EOF
# See http://help.ubuntu.com/community/UpgradeNotes for how to upgrade to
# newer versions of the distribution.
deb ${mirror} ${release} main restricted
# deb-src ${mirror} ${release} main restricted

## Major bug fix updates produced after the final release of the
## distribution.
deb ${mirror} ${release}-updates main restricted
# deb-src ${mirror} ${release}-updates main restricted

## N.B. software from this repository is ENTIRELY UNSUPPORTED by the Ubuntu
## team. Also, please note that software in universe WILL NOT receive any
## review or updates from the Ubuntu security team.
deb ${mirror} ${release} universe
# deb-src ${mirror} ${release} universe
deb ${mirror} ${release}-updates universe
# deb-src ${mirror} ${release}-updates universe

## N.B. software from this repository is ENTIRELY UNSUPPORTED by the Ubuntu
## team, and may not be under a free licence. Please satisfy yourself as to
## your rights to use the software. Also, please note that software in
## multiverse WILL NOT receive any review or updates from the Ubuntu
## security team.
deb ${mirror} ${release} multiverse
# deb-src ${mirror} ${release} multiverse
deb ${mirror} ${release}-updates multiverse
# deb-src ${mirror} ${release}-updates multiverse

## N.B. software from this repository may not have been tested as
## extensively as that contained in the main release, although it includes
## newer versions of some applications which may provide useful features.
## Also, please note that software in backports WILL NOT receive any review
## or updates from the Ubuntu security team.
deb ${mirror} ${release}-backports main restricted universe multiverse
# deb-src ${mirror} ${release}-backports main restricted universe multiverse

deb ${mirror} ${release}-security main restricted
# deb-src ${mirror} ${release}-security main restricted
deb ${mirror} ${release}-security universe
# deb-src ${mirror} ${release}-security universe
deb ${mirror} ${release}-security multiverse
# deb-src ${mirror} ${release}-security multiverse
EOF

# Mount the temporary API filesystems
mkdir -p ${chroot_dir}/{proc,sys,run,dev,dev/pts}
mount -t proc /proc ${chroot_dir}/proc
mount -t sysfs /sys ${chroot_dir}/sys
mount -o bind /dev ${chroot_dir}/dev
mount -o bind /dev/pts ${chroot_dir}/dev/pts

# Package priority for ppa
cp ${overlay_dir}/etc/apt/preferences.d/rockchip-ppa ${chroot_dir}/etc/apt/preferences.d/rockchip-ppa
cp ${overlay_dir}/etc/apt/preferences.d/panfork-mesa-ppa ${chroot_dir}/etc/apt/preferences.d/panfork-mesa-ppa
cp ${overlay_dir}/etc/apt/preferences.d/rockchip-multimedia-ppa ${chroot_dir}/etc/apt/preferences.d/rockchip-multimedia-ppa

# Download and update packages
cat << EOF | chroot ${chroot_dir} /bin/bash
set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

# Update localisation files
locale-gen en_US.UTF-8
update-locale LANG="en_US.UTF-8"

# Add the rockchip ppa
apt-get -y update && apt-get -y install software-properties-common
add-apt-repository -y ppa:jjriek/rockchip

# Add mesa and rockchip multimedia ppa
add-apt-repository -y ppa:liujianfeng1994/panfork-mesa
add-apt-repository -y ppa:liujianfeng1994/rockchip-multimedia

# Download and update installed packages
apt-get -y update && apt-get -y upgrade && apt-get -y dist-upgrade

# Download and install generic packages
apt-get -y install dmidecode mtd-tools i2c-tools u-boot-tools cloud-init \
bash-completion man-db manpages nano gnupg initramfs-tools armbian-firmware \
ubuntu-drivers-common ubuntu-server dosfstools mtools parted ntfs-3g zip atop \
p7zip-full htop iotop pciutils lshw lsof landscape-common exfat-fuse hwinfo \
net-tools wireless-tools openssh-client openssh-server wpasupplicant ifupdown \
pigz wget curl lm-sensors bluez gdisk usb-modeswitch usb-modeswitch-data make \
gcc libc6-dev bison libssl-dev flex flash-kernel fake-hwclock rfkill wireless-regdb

# Remove cryptsetup and needrestart
apt-get -y remove cryptsetup needrestart

# Clean package cache
apt-get -y autoremove && apt-get -y clean && apt-get -y autoclean
EOF

# Swapfile
cat << EOF | chroot ${chroot_dir} /bin/bash
set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

dd if=/dev/zero of=/tmp/swapfile bs=1024 count=2097152
chmod 600 /tmp/swapfile
mkswap /tmp/swapfile
mv /tmp/swapfile /swapfile
EOF

# DNS
cp ${overlay_dir}/etc/resolv.conf ${chroot_dir}/etc/resolv.conf

# Hostname
cp ${overlay_dir}/etc/hostname ${chroot_dir}/etc/hostname

# Hosts file
cp ${overlay_dir}/etc/hosts ${chroot_dir}/etc/hosts

# Serial console resize script
cp ${overlay_dir}/etc/profile.d/resize.sh ${chroot_dir}/etc/profile.d/resize.sh

# Enable rc-local
cp ${overlay_dir}/etc/rc.local ${chroot_dir}/etc/rc.local

# Cloud init config
cp ${overlay_dir}/etc/cloud/cloud.cfg.d/99-fake_cloud.cfg ${chroot_dir}/etc/cloud/cloud.cfg.d/99-fake_cloud.cfg

# Default adduser config
cp ${overlay_dir}/etc/adduser.conf ${chroot_dir}/etc/adduser.conf

# Realtek 8811CU/8821CU usb modeswitch support
cp ${chroot_dir}/lib/udev/rules.d/40-usb_modeswitch.rules ${chroot_dir}/etc/udev/rules.d/40-usb_modeswitch.rules
sed '/LABEL="modeswitch_rules_end"/d' -i ${chroot_dir}/etc/udev/rules.d/40-usb_modeswitch.rules
cat >> ${chroot_dir}/etc/udev/rules.d/40-usb_modeswitch.rules <<EOF
# Realtek 8811CU/8821CU Wifi AC USB
ATTR{idVendor}=="0bda", ATTR{idProduct}=="1a2b", RUN+="/usr/sbin/usb_modeswitch -K -v 0bda -p 1a2b"

LABEL="modeswitch_rules_end"
EOF

# Add usb modeswitch to initrd this fixes a boot hang with 8811CU/8821CU
cp ${overlay_dir}/usr/share/initramfs-tools/hooks/usb_modeswitch ${chroot_dir}/usr/share/initramfs-tools/hooks/usb_modeswitch

# Expand root filesystem on first boot
mkdir -p ${chroot_dir}/usr/lib/scripts
cp ${overlay_dir}/usr/lib/scripts/resize-filesystem.sh ${chroot_dir}/usr/lib/scripts/resize-filesystem.sh
cp ${overlay_dir}/usr/lib/systemd/system/resize-filesystem.service ${chroot_dir}/usr/lib/systemd/system/resize-filesystem.service
chroot ${chroot_dir} /bin/bash -c "systemctl enable resize-filesystem"

# Set cpu governor to performance
cp ${overlay_dir}/usr/lib/systemd/system/cpu-governor-performance.service ${chroot_dir}/usr/lib/systemd/system/cpu-governor-performance.service
chroot ${chroot_dir} /bin/bash -c "systemctl enable cpu-governor-performance"

# Set gpu governor to performance
cp ${overlay_dir}/usr/lib/systemd/system/gpu-governor-performance.service ${chroot_dir}/usr/lib/systemd/system/gpu-governor-performance.service
chroot ${chroot_dir} /bin/bash -c "systemctl enable gpu-governor-performance"

# Enable bluetooth for AP6275P
cp ${overlay_dir}/usr/lib/systemd/system/ap6275p-bluetooth.service ${chroot_dir}/usr/lib/systemd/system/ap6275p-bluetooth.service
cp ${overlay_dir}/usr/lib/scripts/ap6275p-bluetooth.sh ${chroot_dir}/usr/lib/scripts/ap6275p-bluetooth.sh
cp ${overlay_dir}/usr/bin/brcm_patchram_plus ${chroot_dir}/usr/bin/brcm_patchram_plus
chroot ${chroot_dir} /bin/bash -c "systemctl enable ap6275p-bluetooth"

# Add realtek bluetooth firmware to initrd 
cp ${overlay_dir}/usr/share/initramfs-tools/hooks/rtl-bt ${chroot_dir}/usr/share/initramfs-tools/hooks/rtl-bt

# Service to synchronise system clock to hardware RTC
cp ${overlay_dir}/usr/lib/systemd/system/rtc-hym8563.service ${chroot_dir}/usr/lib/systemd/system/rtc-hym8563.service

# Set term for serial tty
mkdir -p ${chroot_dir}/lib/systemd/system/serial-getty@.service.d
cp ${overlay_dir}/usr/lib/systemd/system/serial-getty@.service.d/10-term.conf ${chroot_dir}/usr/lib/systemd/system/serial-getty@.service.d/10-term.conf

# Use gzip compression for the initrd
cp ${overlay_dir}/etc/initramfs-tools/conf.d/compression.conf ${chroot_dir}/etc/initramfs-tools/conf.d/compression.conf

# Remove release upgrade motd
rm -f ${chroot_dir}/var/lib/ubuntu-release-upgrader/release-upgrade-available
cp ${overlay_dir}/etc/update-manager/release-upgrades ${chroot_dir}/etc/update-manager/release-upgrades

# Let systemd create machine id on first boot
rm -f ${chroot_dir}/var/lib/dbus/machine-id
true > ${chroot_dir}/etc/machine-id 

# Do not create bak files for flash-kernel
echo "NO_CREATE_DOT_BAK_FILES=true" >> ${chroot_dir}/etc/environment

# Fix Intel AX210 not working after linux-firmware update
[ -e ${chroot_dir}/usr/lib/firmware/iwlwifi-ty-a0-gf-a0.pnvm ] && mv ${chroot_dir}/usr/lib/firmware/iwlwifi-ty-a0-gf-a0.{pnvm,bak}

# Umount temporary API filesystems
umount -lf ${chroot_dir}/dev/pts 2> /dev/null || true
umount -lf ${chroot_dir}/* 2> /dev/null || true

# Tar the entire rootfs
cd ${chroot_dir} && XZ_OPT="-3 -T0" tar -cpJf ../ubuntu-22.04.2-preinstalled-server-arm64.rootfs.tar.xz . && cd ..

# Mount the temporary API filesystems
mkdir -p ${chroot_dir}/{proc,sys,run,dev,dev/pts}
mount -t proc /proc ${chroot_dir}/proc
mount -t sysfs /sys ${chroot_dir}/sys
mount -o bind /dev ${chroot_dir}/dev
mount -o bind /dev/pts ${chroot_dir}/dev/pts

# Install rkaiq
cp -r ../packages/rkaiq/camera-engine-rkaiq_rk3588_arm64.deb ${chroot_dir}/tmp
chroot ${chroot_dir} /bin/bash -c "dpkg -i /tmp/camera-engine-rkaiq_rk3588_arm64.deb"
cp -f ../packages/rkaiq/rkaiq_3A_server ${chroot_dir}/usr/bin
rm -f ${chroot_dir}/tmp/camera-engine-rkaiq_rk3588_arm64.deb

# Download and update packages
cat << EOF | chroot ${chroot_dir} /bin/bash
set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

# Desktop packages
apt-get -y install ubuntu-desktop dbus-x11 xterm pulseaudio pavucontrol qtwayland5 \
gstreamer1.0-plugins-bad gstreamer1.0-plugins-base gstreamer1.0-plugins-good mpv \
gstreamer1.0-tools gstreamer1.0-rockchip1 chromium-browser mali-g610-firmware malirun \
rockchip-multimedia-config librist4 librist-dev rist-tools dvb-tools ir-keytable \
libdvbv5-0 libdvbv5-dev libdvbv5-doc libv4l-0 libv4l2rds0 libv4lconvert0 libv4l-dev \
libv4l-rkmpp qv4l2 v4l-utils librockchip-mpp1 librockchip-mpp-dev librockchip-vpu0 \
rockchip-mpp-demos librga2 librga-dev libegl-mesa0 libegl1-mesa-dev libgbm-dev \
libgl1-mesa-dev libgles2-mesa-dev libglx-mesa0 mesa-common-dev mesa-vulkan-drivers \
mesa-utils libwidevinecdm

# Remove cloud-init and landscape-common
apt-get -y purge cloud-init landscape-common

# Chromium uses fixed paths for libv4l2.so
ln -rsf /usr/lib/*/libv4l2.so /usr/lib/
[ -e /usr/lib/aarch64-linux-gnu/ ] && ln -Tsf lib /usr/lib64

# Clean package cache
apt-get -y autoremove && apt-get -y clean && apt-get -y autoclean
EOF

# Setup and configure oem installer
cat << EOF | chroot ${chroot_dir} /bin/bash
set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

addgroup --gid 29999 oem
adduser --gecos "OEM Configuration (temporary user)" --add_extra_groups --disabled-password --gid 29999 --uid 29999 oem
usermod -a -G adm,sudo -p "$(date +%s | sha256sum | base64 | head -c 32)" oem

apt-get -y install --no-install-recommends oem-config-slideshow-ubuntu oem-config \
oem-config-gtk ubiquity-frontend-gtk ubiquity-ubuntu-artwork ubiquity 

mkdir -p /var/log/installer
touch /var/log/{syslog,installer/debug}
oem-config-prepare --quiet

# Clean package cache
apt-get -y autoremove && apt-get -y clean && apt-get -y autoclean
EOF

# Hack for GDM to restart on first HDMI hotplug
cp ${overlay_dir}/usr/lib/scripts/gdm-hack.sh ${chroot_dir}/usr/lib/scripts/gdm-hack.sh
cp ${overlay_dir}/etc/udev/rules.d/99-gdm-hack.rules ${chroot_dir}/etc/udev/rules.d/99-gdm-hack.rules

# Set gstreamer environment variables
cp ${overlay_dir}/etc/profile.d/gst.sh ${chroot_dir}/etc/profile.d/gst.sh

# Set cogl to use gles2
cp ${overlay_dir}/etc/profile.d/cogl.sh ${chroot_dir}/etc/profile.d/cogl.sh

# Set qt to use wayland
cp ${overlay_dir}/etc/profile.d/qt.sh ${chroot_dir}/etc/profile.d/qt.sh

# Config file for mpv
cp ${overlay_dir}/etc/mpv/mpv.conf ${chroot_dir}/etc/mpv/mpv.conf

# Use mpv as the default video player
sed -i 's/org\.gnome\.Totem\.desktop/mpv\.desktop/g' ${chroot_dir}/usr/share/applications/gnome-mimeapps.list 

# Adjust hostname for desktop
echo "localhost.localdomain" > ${chroot_dir}/etc/hostname

# Adjust hosts file for desktop
sed -i 's/127.0.0.1 localhost/127.0.0.1\tlocalhost.localdomain\tlocalhost\n::1\t\tlocalhost6.localdomain6\tlocalhost6/g' ${chroot_dir}/etc/hosts
sed -i 's/::1 ip6-localhost ip6-loopback/::1     localhost ip6-localhost ip6-loopback/g' ${chroot_dir}/etc/hosts
sed -i "/ff00::0 ip6-mcastprefix\b/d" ${chroot_dir}/etc/hosts

# Config file for xorg
mkdir -p ${chroot_dir}/etc/X11/xorg.conf.d
cp ${overlay_dir}/etc/X11/xorg.conf.d/20-modesetting.conf ${chroot_dir}/etc/X11/xorg.conf.d/20-modesetting.conf

# Networking interfaces
cp ${overlay_dir}/etc/NetworkManager/NetworkManager.conf ${chroot_dir}/etc/NetworkManager/NetworkManager.conf
cp ${overlay_dir}/usr/lib/NetworkManager/conf.d/10-globally-managed-devices.conf ${chroot_dir}/usr/lib/NetworkManager/conf.d/10-globally-managed-devices.conf
cp ${overlay_dir}/usr/lib/NetworkManager/conf.d/10-override-wifi-random-mac-disable.conf ${chroot_dir}/usr/lib/NetworkManager/conf.d/10-override-wifi-random-mac-disable.conf
cp ${overlay_dir}/usr/lib/NetworkManager/conf.d/20-override-wifi-powersave-disable.conf ${chroot_dir}/usr/lib/NetworkManager/conf.d/20-override-wifi-powersave-disable.conf

# Enable wayland session
cp ${overlay_dir}/etc/gdm3/custom.conf ${chroot_dir}/etc/gdm3/custom.conf

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

# Have plymouth use the framebuffer
mkdir -p ${chroot_dir}/etc/initramfs-tools/conf-hooks.d
cp ${overlay_dir}/etc/initramfs-tools/conf-hooks.d/plymouth ${chroot_dir}/etc/initramfs-tools/conf-hooks.d/plymouth

# Fix Intel AX210 not working after linux-firmware update
[ -e ${chroot_dir}/usr/lib/firmware/iwlwifi-ty-a0-gf-a0.pnvm ] && mv ${chroot_dir}/usr/lib/firmware/iwlwifi-ty-a0-gf-a0.{pnvm,bak}

# Update initramfs
chroot ${chroot_dir} /bin/bash -c "update-initramfs -u"

# Umount the temporary API filesystems
umount -lf ${chroot_dir}/dev/pts 2> /dev/null || true
umount -lf ${chroot_dir}/* 2> /dev/null || true

# Tar the entire rootfs
cd ${chroot_dir} && XZ_OPT="-3 -T0" tar -cpJf ../ubuntu-22.04.2-preinstalled-desktop-arm64.rootfs.tar.xz . && cd ..
