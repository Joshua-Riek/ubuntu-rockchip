#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

if [ "$(id -u)" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..
mkdir -p build && cd build

if [ ! -d linux-orangepi ]; then
    echo "Error: could not find the kernel source code, please run build-kernel.sh"
    exit 1
fi

# Download the orange pi firmware
if [ ! -d firmware ]; then
    git clone --progress -b master https://github.com/orangepi-xunlong/firmware.git
    git -C firmware checkout 79186949b2fbd01c52d55f085106b96dfd670ff6
fi

# These env vars can cause issues with chroot
unset TMP
unset TEMP
unset TMPDIR

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

# Copy the the kernel, modules, and headers to the rootfs
if ! cp linux-{headers,image,libc}-*.deb ${chroot_dir}/tmp; then
    echo "Error: could not find the kernel deb packages, please run build-kernel.sh"
    exit 1
fi

# Download and update packages
cat << EOF | chroot ${chroot_dir} /bin/bash
set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

# Generate localisation files
locale-gen en_US.UTF-8
update-locale LC_ALL="en_US.UTF-8"

# Download package information
DEBIAN_FRONTEND=noninteractive apt-get -y update

# Update installed packages
DEBIAN_FRONTEND=noninteractive apt-get -y upgrade

# Update installed packages and dependencies
DEBIAN_FRONTEND=noninteractive apt-get -y dist-upgrade

# Download and install generic packages
DEBIAN_FRONTEND=noninteractive apt-get -y install dmidecode mtd-tools \
bash-completion man-db manpages nano gnupg initramfs-tools linux-firmware \
ubuntu-drivers-common ubuntu-server dosfstools mtools parted ntfs-3g zip atop \
p7zip-full htop iotop pciutils lshw lsof landscape-common exfat-fuse hwinfo \
net-tools wireless-tools openssh-client openssh-server wpasupplicant ifupdown \
pigz wget curl lm-sensors bluez gdisk i2c-tools u-boot-tools cloud-init

DEBIAN_FRONTEND=noninteractive apt-get -y remove cryptsetup needrestart

# Clean package cache
apt-get -y autoremove && apt-get -y clean && apt-get -y autoclean
EOF

# Grab the kernel version
kernel_version="$(sed -e 's/.*"\(.*\)".*/\1/' linux-orangepi/include/generated/utsrelease.h)"

# Install kernel, modules, and headers
cat << EOF | chroot ${chroot_dir} /bin/bash
set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

# Install the kernel, modules, and headers
dpkg -i /tmp/linux-{headers,image,libc}-*.deb
rm -rf /tmp/*

# Generate kernel module dependencies
depmod -a ${kernel_version}
update-initramfs -c -k ${kernel_version}

# Create kernel and component symlinks
cd /boot
ln -s initrd.img-${kernel_version} initrd.img
ln -s vmlinuz-${kernel_version} vmlinuz
ln -s System.map-${kernel_version} System.map
ln -s config-${kernel_version} config

# Hold package for jammy
apt-mark hold linux-libc-dev
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

# Install and hold wiringpi package
cp ../debs/wiringpi/wiringpi_2.47.deb ${chroot_dir}/tmp
chroot ${chroot_dir} /bin/bash -c "dpkg -i /tmp/wiringpi_2.47.deb && apt-mark hold wiringpi && rm -rf /tmp/*.deb"
echo "BOARD=orangepi5" > ${chroot_dir}/etc/orangepi-release

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

# Enable the USB 2.0 port on boot
cp ${overlay_dir}/usr/lib/systemd/system/enable-usb2.service ${chroot_dir}/usr/lib/systemd/system/enable-usb2.service
chroot ${chroot_dir} /bin/bash -c "systemctl --no-reload enable enable-usb2"

# Enable bluetooth for AP6275P
cp ${overlay_dir}/usr/lib/systemd/system/ap6275p-bluetooth.service ${chroot_dir}/usr/lib/systemd/system/ap6275p-bluetooth.service
cp ${overlay_dir}/usr/lib/scripts/ap6275p-bluetooth.sh ${chroot_dir}/usr/lib/scripts/ap6275p-bluetooth.sh
cp ${overlay_dir}/usr/bin/brcm_patchram_plus ${chroot_dir}/usr/bin/brcm_patchram_plus
chroot ${chroot_dir} /bin/bash -c "systemctl enable ap6275p-bluetooth"

# Add realtek bluetooth firmware to initrd 
cp ${overlay_dir}/usr/share/initramfs-tools/hooks/rtl-bt ${chroot_dir}/usr/share/initramfs-tools/hooks/rtl-bt

# Synchronise system clock to hardware RTC
cp ${overlay_dir}/usr/lib/systemd/system/rtc-hym8563.service ${chroot_dir}/usr/lib/systemd/system/rtc-hym8563.service
chroot ${chroot_dir} /bin/bash -c "systemctl enable rtc-hym8563"

# Set term for serial tty
mkdir -p ${chroot_dir}/lib/systemd/system/serial-getty@.service.d
cp ${overlay_dir}/usr/lib/systemd/system/serial-getty@.service.d/10-term.conf ${chroot_dir}/usr/lib/systemd/system/serial-getty@.service.d/10-term.conf

# Use gzip compression for the initrd
cp ${overlay_dir}/etc/initramfs-tools/conf.d/compression.conf ${chroot_dir}/etc/initramfs-tools/conf.d/compression.conf

# Remove release upgrade motd
rm -f ${chroot_dir}/var/lib/ubuntu-release-upgrader/release-upgrade-available
cp ${overlay_dir}/etc/update-manager/release-upgrades ${chroot_dir}/etc/update-manager/release-upgrades

# Orange pi firmware
cp -r firmware ${chroot_dir}/usr/lib

# Fix Intel AX210 not working after linux-firmware update
[ -e ${chroot_dir}/usr/lib/firmware/iwlwifi-ty-a0-gf-a0.pnvm ] && mv ${chroot_dir}/usr/lib/firmware/iwlwifi-ty-a0-gf-a0.{pnvm,bak}

# Update initramfs
chroot ${chroot_dir} /bin/bash -c "update-initramfs -u"

# Umount temporary API filesystems
umount -lf ${chroot_dir}/dev/pts 2> /dev/null || true
umount -lf ${chroot_dir}/* 2> /dev/null || true

# Tar the entire rootfs
cd ${chroot_dir} && XZ_OPT="-0 -T0" tar -cpJf ../ubuntu-22.04-preinstalled-server-arm64-orange-pi5.rootfs.tar.xz . && cd ..
../scripts/build-image.sh ubuntu-22.04-preinstalled-server-arm64-orange-pi5.rootfs.tar.xz

# Mount the temporary API filesystems
mkdir -p ${chroot_dir}/{proc,sys,run,dev,dev/pts}
mount -t proc /proc ${chroot_dir}/proc
mount -t sysfs /sys ${chroot_dir}/sys
mount -o bind /dev ${chroot_dir}/dev
mount -o bind /dev/pts ${chroot_dir}/dev/pts

# Copy GPU accelerated packages to the rootfs
cp -r ../debs/* ${chroot_dir}/tmp

# Install GPU accelerated packages
cat << EOF | chroot ${chroot_dir} /bin/bash
set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

mkdir -p /tmp/apt-local
mv /tmp/*/*.deb /tmp/apt-local

# Backup sources.list and setup a local apt repo
cd /tmp/apt-local && apt-ftparchive packages . > Packages && cd /
echo -e "Package: *\nPin: origin ""\nPin-Priority: 1001" > /etc/apt/preferences.d/apt-local
echo "deb [trusted=yes] file:/tmp/apt-local/ ./" > /tmp/apt-local.list
cp /etc/apt/sources.list /etc/apt/sources.list.bak
cat /tmp/apt-local.list /etc/apt/sources.list > /tmp/sources.list
mv /tmp/sources.list /etc/apt/sources.list
rm -rf /tmp/apt-local.list

# Download package information
DEBIAN_FRONTEND=noninteractive apt-get -y update

debs=()
for i in /tmp/apt-local/*.deb; do
    debs+=("\$(basename "\${i}" | cut -d "_" -f1)")
done

# Install packages
DEBIAN_FRONTEND=noninteractive apt-get -y install "\${debs[@]}"

# Hold packages to prevent breaking hw acceleration
DEBIAN_FRONTEND=noninteractive apt-mark hold "\${debs[@]}"

# Copy binary for rkaiq
cp -f /tmp/rkaiq/rkaiq_3A_server /usr/bin

# Chromium uses fixed paths for libv4l2.so
cp -f /tmp/chromium/libjpeg.so.62 /usr/lib/aarch64-linux-gnu
ln -rsf /usr/lib/*/libv4l2.so /usr/lib/
[ -e /usr/lib/aarch64-linux-gnu/ ] && ln -Tsf lib /usr/lib64

# Improve mesa performance 
echo "PAN_MESA_DEBUG=gofaster" >> /etc/environment

# Remove the local apt repo and restore sources.list
mv /etc/apt/sources.list.bak /etc/apt/sources.list
rm -f /etc/apt/preferences.d/apt-local
rm -rf /tmp/*

# Download package information
DEBIAN_FRONTEND=noninteractive apt-get -y update

# Clean package cache
apt-get -y autoremove && apt-get -y clean && apt-get -y autoclean
EOF

# Download and update packages
cat << EOF | chroot ${chroot_dir} /bin/bash
set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

# Desktop packages
DEBIAN_FRONTEND=noninteractive apt-get -y install ubuntu-desktop \
dbus-x11 xterm pulseaudio pavucontrol qtwayland5

# Remove cloud-init and landscape-common
DEBIAN_FRONTEND=noninteractive apt-get -y purge cloud-init landscape-common

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

DEBIAN_FRONTEND=noninteractive apt-get -y install --no-install-recommends \
oem-config-gtk ubiquity-frontend-gtk ubiquity-ubuntu-artwork oem-config-slideshow-ubuntu

mkdir -p /var/log/installer
touch /var/log/syslog
touch /var/log/installer/debug
cp -a /usr/lib/oem-config/oem-config.service /lib/systemd/system
cp -a /usr/lib/oem-config/oem-config.target /lib/systemd/system
systemctl enable oem-config.service
systemctl enable oem-config.target
systemctl set-default oem-config.target

# Clean package cache
apt-get -y autoremove && apt-get -y clean && apt-get -y autoclean
EOF

# Hack for GDM to restart on first HDMI hotplug
cp ${overlay_dir}/usr/lib/scripts/gdm-hack.sh ${chroot_dir}/usr/lib/scripts/gdm-hack.sh
cp ${overlay_dir}/etc/udev/rules.d/99-gdm-hack.rules ${chroot_dir}/etc/udev/rules.d/99-gdm-hack.rules

# Rockchip pulseaudio configs and rules
cp -r ${overlay_dir}/etc/pulse ${chroot_dir}/etc
cp -r ${overlay_dir}/usr/share/alsa ${chroot_dir}/usr/share
cp -r ${overlay_dir}/usr/share/pulseaudio ${chroot_dir}/usr/share
cp -r ${overlay_dir}/etc/udev/rules.d/90-pulseaudio-rockchip.rules ${chroot_dir}/etc/udev/rules.d/90-pulseaudio-rockchip.rules

# Fix pulseaudio stuck on gdm user
cp -r ${overlay_dir}/usr/lib/systemd/user/pulseaudio.service.d ${chroot_dir}/usr/lib/systemd/user/
cp -r ${overlay_dir}/usr/lib/systemd/user/pulseaudio.socket.d ${chroot_dir}/usr/lib/systemd/user/

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
cd ${chroot_dir} && XZ_OPT="-0 -T0" tar -cpJf ../ubuntu-22.04-preinstalled-desktop-arm64-orange-pi5.rootfs.tar.xz . && cd ..
../scripts/build-image.sh ubuntu-22.04-preinstalled-desktop-arm64-orange-pi5.rootfs.tar.xz
