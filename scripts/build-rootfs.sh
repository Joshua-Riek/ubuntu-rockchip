#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

if [ "$(id -u)" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

if [ $# -ne 1 ]; then
    echo "Usage: $0 [focal|jammy]"
    exit 1
fi

if [ "$1" == "focal" ]; then
    release="focal"
    version="20.04"
elif [ "$1" == "jammy" ]; then
    release="jammy"
    version="22.04"
else
    echo "Usage: $0 [focal|jammy]"
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
    git -C firmware checkout 75747c7034b1136b4674269e248b69bf1a5e4039
fi

# These env vars can cause issues with chroot
unset TMP
unset TEMP
unset TMPDIR

# Debootstrap options
arch=arm64
mirror=http://ports.ubuntu.com/ubuntu-ports
chroot_dir=rootfs
overlay_dir=../overlay

# Clean chroot dir and make sure folder is not mounted
umount -lf ${chroot_dir}/dev/pts 2> /dev/null || true
umount -lf ${chroot_dir}/* 2> /dev/null || true
rm -rf ${chroot_dir}
mkdir -p ${chroot_dir}

# Install the base system into a directory 
qemu-debootstrap --arch ${arch} ${release} ${chroot_dir} ${mirror}

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
DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends update

# Update installed packages
DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends upgrade

# Update installed packages and dependencies
DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends dist-upgrade

# Download and install generic packages
DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install \
bash-completion man-db manpages nano gnupg initramfs-tools linux-firmware \
ubuntu-drivers-common ubuntu-server dosfstools mtools parted ntfs-3g zip atop \
p7zip-full htop iotop pciutils lshw lsof cryptsetup exfat-fuse hwinfo dmidecode \
net-tools wireless-tools openssh-client openssh-server wpasupplicant ifupdown \
pigz wget curl gdisk

# Download and install developer packages
DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install \
git binutils build-essential bc bison cmake flex libssl-dev device-tree-compiler \
i2c-tools u-boot-tools binfmt-support python3

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

# Create user accounts
cat << EOF | chroot ${chroot_dir} /bin/bash
set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

# Setup user account
adduser --shell /bin/bash --gecos ubuntu --disabled-password ubuntu
usermod -a -G sudo,video,adm,dialout,cdrom,audio,plugdev,netdev ubuntu
mkdir -m 700 /home/ubuntu/.ssh
chown -R ubuntu:ubuntu /home/ubuntu
echo -e "root\nroot" | passwd ubuntu

# Root pass
echo -e "root\nroot" | passwd
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

# Networking interfaces
cp ${overlay_dir}/etc/network/interfaces.d/interfaces ${chroot_dir}/etc/network/interfaces.d/interfaces

# Hosts file
cp ${overlay_dir}/etc/hosts ${chroot_dir}/etc/hosts

# WIFI
cp ${overlay_dir}/etc/wpa_supplicant/wpa_supplicant.conf ${chroot_dir}/etc/wpa_supplicant/wpa_supplicant.conf

# Serial console resize script
cp ${overlay_dir}/etc/profile.d/resize.sh ${chroot_dir}/etc/profile.d/resize.sh

# Enable rc-local
cp ${overlay_dir}/etc/rc.local ${chroot_dir}/etc/rc.local

# Expand root filesystem on first boot
mkdir -p ${chroot_dir}/usr/lib/scripts
cp ${overlay_dir}/usr/lib/scripts/resize-filesystem.sh ${chroot_dir}/usr/lib/scripts/resize-filesystem.sh
cp ${overlay_dir}/usr/lib/systemd/system/resize-filesystem.service ${chroot_dir}/usr/lib/systemd/system/resize-filesystem.service
chroot ${chroot_dir} /bin/bash -c "systemctl enable resize-filesystem"

# Set cpu governors to performance
cp ${overlay_dir}/usr/lib/systemd/system/cpu-governor-performance.service ${chroot_dir}/usr/lib/systemd/system/cpu-governor-performance.service
chroot ${chroot_dir} /bin/bash -c "systemctl enable cpu-governor-performance"

# Enable the USB 2.0 port on boot
cp ${overlay_dir}/usr/lib/systemd/system/enable-usb2.service ${chroot_dir}/usr/lib/systemd/system/enable-usb2.service
chroot ${chroot_dir} /bin/bash -c "systemctl --no-reload enable enable-usb2"

# Enable bluetooth for AP6275P
cp ${overlay_dir}/usr/lib/systemd/system/ap6275p-bluetooth.service ${chroot_dir}/usr/lib/systemd/system/ap6275p-bluetooth.service
chroot ${chroot_dir} /bin/bash -c "systemctl enable ap6275p-bluetooth"

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

# Update initramfs
chroot ${chroot_dir} /bin/bash -c "update-initramfs -u"

# Umount temporary API filesystems
umount -lf ${chroot_dir}/dev/pts 2> /dev/null || true
umount -lf ${chroot_dir}/* 2> /dev/null || true

# Tar the entire rootfs
cd ${chroot_dir} && XZ_OPT="-0 -T0" tar -cpJf ../ubuntu-${version}-preinstalled-server-arm64-orange-pi5.rootfs.tar.xz . && cd ..
../scripts/build-image.sh ubuntu-${version}-preinstalled-server-arm64-orange-pi5.rootfs.tar.xz

# Mount the temporary API filesystems
mkdir -p ${chroot_dir}/{proc,sys,run,dev,dev/pts}
mount -t proc /proc ${chroot_dir}/proc
mount -t sysfs /sys ${chroot_dir}/sys
mount -o bind /dev ${chroot_dir}/dev
mount -o bind /dev/pts ${chroot_dir}/dev/pts

# Copy GPU accelerated packages to the rootfs
cp -r ../debs/${release}/* ${chroot_dir}/tmp

# Install GPU accelerated packages
cat << EOF | chroot ${chroot_dir} /bin/bash
set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

mkdir -p /tmp/apt-local
mv /tmp/*/*.deb /tmp/apt-local

# Backup sources.list and setup a local apt repo
cd /tmp/apt-local && apt-ftparchive packages . > Packages && cd /
echo -e "Package: *\nPin: origin ""\nPin-Priority: 1001" > /etc/apt/prefrences
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

# Remove other dri libs
cp /usr/lib/aarch64-linux-gnu/dri/{kms_swrast_dri,swrast_dri,rockchip_dri}.so /
rm -f /usr/lib/aarch64-linux-gnu/dri/*.so
mv /*.so /usr/lib/aarch64-linux-gnu/dri/

# Use panfrost by default
echo "/opt/panfrost/lib/aarch64-linux-gnu" > /etc/ld.so.conf.d/00-panfrost.conf
[ -e /etc/ld.so.conf.d/00-aarch64-mali.conf ] && mv /etc/ld.so.conf.d/{00-aarch64-mali.conf,01-aarch64-mali.conf}
ldconfig

# Improve mesa performance 
echo "PAN_MESA_DEBUG=gofaster" >> /etc/environment

# Remove the local apt repo and restore sources.list
mv /etc/apt/sources.list.bak /etc/apt/sources.list
rm -f /etc/apt/prefrences
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
dbus-x11 pulseaudio pavucontrol

# Firefox has no gpu support 
DEBIAN_FRONTEND=noninteractive apt-get -y purge firefox

# Clean package cache
apt-get -y autoremove && apt-get -y clean && apt-get -y autoclean
EOF

# Rockchip pulseaudio configs and rules
cp -r ${overlay_dir}/etc/pulse ${chroot_dir}/etc
cp -r ${overlay_dir}/usr/share/alsa ${chroot_dir}/usr/share
cp -r ${overlay_dir}/usr/share/pulseaudio ${chroot_dir}/usr/share
cp -r ${overlay_dir}/etc/udev/rules.d/90-pulseaudio-rockchip.rules ${chroot_dir}/etc/udev/rules.d/90-pulseaudio-rockchip.rules

# Fix pulseaudio stuck on gdm user
cp -r ${overlay_dir}/usr/lib/systemd/user/pulseaudio.service.d ${chroot_dir}/usr/lib/systemd/user/
cp -r ${overlay_dir}/usr/lib/systemd/user/pulseaudio.socket.d ${chroot_dir}/usr/lib/systemd/user/

# Rockchip multimedia rules
cp ${overlay_dir}/etc/udev/rules.d/99-rk-device-permissions.rules ${chroot_dir}/etc/udev/rules.d/99-rk-device-permissions.rules
cp ${overlay_dir}/usr/bin/create-chromium-vda-vea-devices.sh ${chroot_dir}/usr/bin/create-chromium-vda-vea-devices.sh

# Set gstreamer environment variables
cp ${overlay_dir}/etc/profile.d/gst.sh ${chroot_dir}/etc/profile.d/gst.sh

# Set cogl to use gles2
cp ${overlay_dir}/etc/profile.d/cogl.sh ${chroot_dir}/etc/profile.d/cogl.sh

# Config file for mpv
cp ${overlay_dir}/etc/mpv/mpv.conf ${chroot_dir}/etc/mpv/mpv.conf

# Config file for xorg
mkdir -p ${chroot_dir}/etc/X11/xorg.conf.d
cp ${overlay_dir}/etc/X11/xorg.conf.d/20-modesetting.conf ${chroot_dir}/etc/X11/xorg.conf.d/20-modesetting.conf

# Networking interfaces
rm -f ${chroot_dir}/etc/wpa_supplicant/wpa_supplicant.conf ${chroot_dir}/etc/network/interfaces.d/interfaces 
cp ${overlay_dir}/etc/NetworkManager/NetworkManager.conf ${chroot_dir}/etc/NetworkManager/NetworkManager.conf
cp ${overlay_dir}/usr/lib/NetworkManager/conf.d/10-globally-managed-devices.conf ${chroot_dir}/usr/lib/NetworkManager/conf.d/10-globally-managed-devices.conf

# Enable wayland session
cp ${overlay_dir}/etc/gdm3/custom.conf ${chroot_dir}/etc/gdm3/custom.conf

# Use wayland as the default desktop session
cp ${overlay_dir}/var/lib/AccountsService/users/ubuntu ${chroot_dir}/var/lib/AccountsService/users/ubuntu 

# Fix chromium desktop entry
rm -rf ${chroot_dir}/usr/share/applications/chromium.desktop
cp ${overlay_dir}/usr/share/applications/chromium-browser.desktop ${chroot_dir}/usr/share/applications/chromium-browser.desktop

# Set chromium as default browser
chroot ${chroot_dir} /bin/bash -c "update-alternatives --install /usr/bin/x-www-browser x-www-browser /usr/bin/chromium 500"
chroot ${chroot_dir} /bin/bash -c "update-alternatives --set x-www-browser /usr/bin/chromium"

# Add chromium to favorites bar
chroot ${chroot_dir} /bin/bash -c "sudo -u ubuntu dbus-launch gsettings set org.gnome.shell favorite-apps \
\"['ubiquity.desktop', 'chromium-browser.desktop', 'thunderbird.desktop', 'org.gnome.Nautilus.desktop', \
'rhythmbox.desktop', 'libreoffice-writer.desktop', 'snap-store_ubuntu-software.desktop', 'yelp.desktop']\""

# Update initramfs
chroot ${chroot_dir} /bin/bash -c "update-initramfs -u"

# Umount the temporary API filesystems
umount -lf ${chroot_dir}/dev/pts 2> /dev/null || true
umount -lf ${chroot_dir}/* 2> /dev/null || true

# Tar the entire rootfs
cd ${chroot_dir} && XZ_OPT="-0 -T0" tar -cpJf ../ubuntu-${version}-preinstalled-desktop-arm64-orange-pi5.rootfs.tar.xz . && cd ..
../scripts/build-image.sh ubuntu-${version}-preinstalled-desktop-arm64-orange-pi5.rootfs.tar.xz
