#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

if [ "$(id -u)" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..
mkdir -p build && cd build

if [[ -z ${RELEASE} ]]; then
    echo "Error: RELEASE is not set"
    exit 1
fi

# shellcheck source=/dev/null
source ../config/releases/"${RELEASE}.sh"

if [[ ${DESKTOP_ONLY} == "Y" ]]; then
    if [[ -f ubuntu-${RELASE_VERSION}-preinstalled-desktop-arm64.rootfs.tar.xz ]]; then
        exit 0
    fi
elif [[ ${SERVER_ONLY} == "Y" ]]; then
    if [[ -f ubuntu-${RELASE_VERSION}-preinstalled-server-arm64.rootfs.tar.xz ]]; then
        exit 0
    fi
else
    if [[ -f ubuntu-${RELASE_VERSION}-preinstalled-server-arm64.rootfs.tar.xz && -f ubuntu-${RELASE_VERSION}-preinstalled-desktop-arm64.rootfs.tar.xz ]]; then
        exit 0
    fi
fi

if [[ ${SERVER_ONLY} == "Y" ]]; then
    if [[ ${RELEASE} == "noble" ]]; then
        git clone https://github.com/Joshua-Riek/ubuntu-live-build.git
        cd ubuntu-live-build
        sudo ./livecd-rootfs.sh && sudo ./build.sh -s
        mv "./build/ubuntu-${RELASE_VERSION}-preinstalled-server-arm64.rootfs.tar.xz" ../
        exit 0
    fi
fi

if [[ ${DESKTOP_ONLY} == "Y" ]]; then
    if [[ ${RELEASE} == "noble" ]]; then
        git clone https://github.com/Joshua-Riek/ubuntu-live-build.git
        cd ubuntu-live-build
        sudo ./livecd-rootfs.sh && sudo ./build.sh -d
        mv "./build/ubuntu-${RELASE_VERSION}-preinstalled-desktop-arm64.rootfs.tar.xz" ../
        exit 0
    fi
fi

# These env vars can cause issues with chroot
unset TMP
unset TEMP
unset TMPDIR

# Prevent dpkg interactive dialogues
export DEBIAN_FRONTEND=noninteractive

# Debootstrap options
arch=arm64
release=${RELEASE}
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
if [[ ${RELEASE} == "jammy" ]]; then
    cat > ${chroot_dir}/etc/apt/preferences.d/rockchip-ppa << EOF
Package: *
Pin: release o=LP-PPA-jjriek-rockchip
Pin-Priority: 1001

Package: flash-kernel
Pin: release o=LP-PPA-jjriek-rockchip
Pin-Priority: 1
EOF
else
    cat > ${chroot_dir}/etc/apt/preferences.d/rockchip-ppa << EOF
Package: *
Pin: release o=LP-PPA-jjriek-rockchip
Pin-Priority: 1001
EOF
fi

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

# Download and update installed packages
apt-get -y update && apt-get -y upgrade && apt-get -y dist-upgrade

# Download and install generic packages
apt-get -y install dmidecode mtd-tools i2c-tools u-boot-tools cloud-init \
bash-completion man-db manpages nano gnupg initramfs-tools mmc-utils rfkill \
ubuntu-drivers-common ubuntu-server dosfstools mtools parted ntfs-3g zip atop \
p7zip-full htop iotop pciutils lshw lsof landscape-common exfat-fuse hwinfo \
net-tools wireless-tools openssh-client openssh-server wpasupplicant ifupdown \
pigz wget curl lm-sensors bluez gdisk usb-modeswitch usb-modeswitch-data make \
gcc libc6-dev bison libssl-dev flex fake-hwclock wireless-regdb psmisc rsync \
uuid-runtime linux-firmware rockchip-firmware cloud-initramfs-growroot flash-kernel \
avahi-daemon

# Remove cryptsetup and needrestart
apt-get -y remove cryptsetup needrestart snapd fwupd

# Clean package cache
apt-get -y autoremove && apt-get -y clean && apt-get -y autoclean
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

# Add extra groups to adduser config
sed -i 's/#EXTRA_GROUPS=.*/EXTRA_GROUPS="video adm dialout cdrom audio plugdev netdev input bluetooth floppy users"/g' ${chroot_dir}/etc/adduser.conf
sed -i 's/#ADD_EXTRA_GROUPS=.*/ADD_EXTRA_GROUPS=1/g' ${chroot_dir}/etc/adduser.conf

# Service to synchronise system clock to hardware RTC
cp ${overlay_dir}/usr/lib/systemd/system/rtc-hym8563.service ${chroot_dir}/usr/lib/systemd/system/rtc-hym8563.service

# Set term for serial tty
mkdir -p ${chroot_dir}/lib/systemd/system/serial-getty@.service.d/
cp ${overlay_dir}/usr/lib/systemd/system/serial-getty@.service.d/10-term.conf ${chroot_dir}/usr/lib/systemd/system/serial-getty@.service.d/10-term.conf

# Create swapfile on boot
mkdir -p ${chroot_dir}/usr/lib/systemd/system/swap.target.wants/
cp ${overlay_dir}/usr/lib/systemd/system/mkswap.service ${chroot_dir}/usr/lib/systemd/system/mkswap.service
cp ${overlay_dir}/usr/lib/systemd/system/swapfile.swap ${chroot_dir}/usr/lib/systemd/system/swapfile.swap        
chroot ${chroot_dir} /bin/bash -c "ln -s ../mkswap.service /usr/lib/systemd/system/swap.target.wants/"
chroot ${chroot_dir} /bin/bash -c "ln -s ../swapfile.swap /usr/lib/systemd/system/swap.target.wants/"

# Fix 120 second timeout bug
mkdir -p ${chroot_dir}/etc/systemd/system/systemd-networkd-wait-online.service.d/
cp ${overlay_dir}/etc/systemd/system/systemd-networkd-wait-online.service.d/override.conf ${chroot_dir}/etc/systemd/system/systemd-networkd-wait-online.service.d/override.conf

# Use gzip compression for the initrd
mkdir -p ${chroot_dir}/etc/initramfs-tools/conf.d/
echo "COMPRESS=gzip" > ${chroot_dir}/etc/initramfs-tools/conf.d/compression.conf

# Disable terminal ads
sed -i 's/ENABLED=1/ENABLED=0/g' ${chroot_dir}/etc/default/motd-news
chroot ${chroot_dir} /bin/bash -c "pro config set apt_news=false"

# Disable apport bug reporting
sed -i 's/enabled=1/enabled=0/g' ${chroot_dir}/etc/default/apport

# Remove release upgrade motd
rm -f ${chroot_dir}/var/lib/ubuntu-release-upgrader/release-upgrade-available
sed -i 's/Prompt=.*/Prompt=never/g' ${chroot_dir}/etc/update-manager/release-upgrades

# Copy over the ubuntu rockchip install util
cp ${overlay_dir}/usr/bin/ubuntu-rockchip-install ${chroot_dir}/usr/bin/ubuntu-rockchip-install

# Let systemd create machine id on first boot
rm -f ${chroot_dir}/var/lib/dbus/machine-id
true > ${chroot_dir}/etc/machine-id 

# Configure cloud-init for NoCloud
cat << EOF > ${chroot_dir}/etc/cloud/cloud.cfg.d/99-fake_cloud.cfg
datasource_list: [ NoCloud, None ]
datasource:
  NoCloud:
    fs_label: system-boot
EOF

# Ensure our customized seed location is mounted prior to execution
mkdir -p ${chroot_dir}/etc/systemd/system/cloud-init-local.service.d
cat << EOF > ${chroot_dir}/etc/systemd/system/cloud-init-local.service.d/mount-seed.conf
[Unit]
RequiresMountsFor=/boot/firmware
EOF

# Wait for cloud-init to finish (creating users, etc.) before running getty
mkdir -p ${chroot_dir}/etc/systemd/system/cloud-config.service.d
cat << EOF > ${chroot_dir}/etc/systemd/system/cloud-config.service.d/getty-wait.conf
[Unit]
Before=getty.target
EOF

if [[ ${RELEASE} == "noble" ]]; then
    echo "options rfkill master_switch_mode=2" > ${chroot_dir}/etc/modprobe.d/rfkill.conf
    echo "options rfkill default_state=1" >> ${chroot_dir}/etc/modprobe.d/rfkill.conf
fi

# Umount temporary API filesystems
umount -lf ${chroot_dir}/dev/pts 2> /dev/null || true
umount -lf ${chroot_dir}/* 2> /dev/null || true

# Tar the entire rootfs
[[ ${DESKTOP_ONLY} != "Y" ]] && cd ${chroot_dir} && XZ_OPT="-3 -T0" tar -cpJf ../ubuntu-${RELASE_VERSION}-preinstalled-server-arm64.rootfs.tar.xz . && cd ..
[[ ${SERVER_ONLY} == "Y" ]] && exit 0

# Mount the temporary API filesystems
mkdir -p ${chroot_dir}/{proc,sys,run,dev,dev/pts}
mount -t proc /proc ${chroot_dir}/proc
mount -t sysfs /sys ${chroot_dir}/sys
mount -o bind /dev ${chroot_dir}/dev
mount -o bind /dev/pts ${chroot_dir}/dev/pts

# Remove cloud init stuff from the desktop image
rm -rf ${chroot_dir}/etc/cloud/cloud.cfg.d/99-fake_cloud.cfg
rm -rf ${chroot_dir}/etc/systemd/system/cloud-config.service.d/getty-wait.conf
rm -rf ${chroot_dir}/etc/systemd/system/cloud-init-local.service.d/mount-seed.conf

# Download and update packages
cat << EOF | chroot ${chroot_dir} /bin/bash
set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

# Desktop packages
apt-get -y install ubuntu-desktop dbus-x11 xterm pulseaudio pavucontrol qtwayland5 \
gstreamer1.0-plugins-bad gstreamer1.0-plugins-base gstreamer1.0-plugins-good mpv \
gstreamer1.0-tools dvb-tools ir-keytable libdvbv5-0 libdvbv5-dev libdvbv5-doc libv4l-0 \
libv4l2rds0 libv4lconvert0 libv4l-dev qv4l2 v4l-utils libegl-mesa0 libegl1-mesa-dev \
libgbm-dev libgl1-mesa-dev libgles2-mesa-dev libglx-mesa0 mesa-common-dev mesa-vulkan-drivers \
mesa-utils libcanberra-pulse oem-config-gtk ubiquity-frontend-gtk ubiquity-slideshow-ubuntu \
language-pack-en-base

# Remove cloud-init and landscape-common
apt-get -y purge cloud-init landscape-common cryptsetup-initramfs snapd firefox fwupd

rm -rf /boot/grub/

# Create files/dirs Ubiquity requires
mkdir -p /var/log/installer
touch /var/log/installer/debug
touch /var/log/syslog
chown syslog:adm /var/log/syslog

# Create the oem user account
/usr/sbin/useradd -d /home/oem -G adm,sudo -m -N -u 29999 oem

/usr/sbin/oem-config-prepare --quiet
touch "/var/lib/oem-config/run"

# Clean package cache
apt-get -y autoremove && apt-get -y clean && apt-get -y autoclean
EOF

# Adjust hostname for desktop
echo "localhost.localdomain" > ${chroot_dir}/etc/hostname

# Adjust hosts file for desktop
sed -i 's/127.0.0.1 localhost/127.0.0.1\tlocalhost.localdomain\tlocalhost\n::1\t\tlocalhost6.localdomain6\tlocalhost6/g' ${chroot_dir}/etc/hosts
sed -i 's/::1 ip6-localhost ip6-loopback/::1     localhost ip6-localhost ip6-loopback/g' ${chroot_dir}/etc/hosts
sed -i "/ff00::0 ip6-mcastprefix\b/d" ${chroot_dir}/etc/hosts

if [[ ${RELEASE} == "jammy" ]]; then
    # Networking interfaces
    cp ${overlay_dir}/etc/NetworkManager/NetworkManager.conf ${chroot_dir}/etc/NetworkManager/NetworkManager.conf
    cp ${overlay_dir}/usr/lib/NetworkManager/conf.d/10-globally-managed-devices.conf ${chroot_dir}/usr/lib/NetworkManager/conf.d/10-globally-managed-devices.conf
    cp ${overlay_dir}/usr/lib/NetworkManager/conf.d/10-override-wifi-random-mac-disable.conf ${chroot_dir}/usr/lib/NetworkManager/conf.d/10-override-wifi-random-mac-disable.conf
    cp ${overlay_dir}/usr/lib/NetworkManager/conf.d/20-override-wifi-powersave-disable.conf ${chroot_dir}/usr/lib/NetworkManager/conf.d/20-override-wifi-powersave-disable.conf

    # Ubuntu desktop uses a diffrent network manager, so remove this systemd override
    rm -rf ${chroot_dir}/etc/systemd/system/systemd-networkd-wait-online.service.d/override.conf
fi

# Enable wayland session
sed -i 's/#WaylandEnable=false/WaylandEnable=true/g' ${chroot_dir}/etc/gdm3/custom.conf

# Have plymouth use the framebuffer
mkdir -p ${chroot_dir}/etc/initramfs-tools/conf-hooks.d
echo "if which plymouth >/dev/null 2>&1; then" > ${chroot_dir}/etc/initramfs-tools/conf-hooks.d/plymouth
echo "    FRAMEBUFFER=y" >> ${chroot_dir}/etc/initramfs-tools/conf-hooks.d/plymouth
echo "fi" >> ${chroot_dir}/etc/initramfs-tools/conf-hooks.d/plymouth

# Mouse lag/stutter (missed frames) in Wayland sessions
# https://bugs.launchpad.net/ubuntu/+source/mutter/+bug/1982560
echo "MUTTER_DEBUG_ENABLE_ATOMIC_KMS=0" >> ${chroot_dir}/etc/environment
echo "MUTTER_DEBUG_FORCE_KMS_MODE=simple" >> ${chroot_dir}/etc/environment
echo "CLUTTER_PAINT=disable-dynamic-max-render-time" >> ${chroot_dir}/etc/environment

# Update initramfs
chroot ${chroot_dir} /bin/bash -c "update-initramfs -u"

# Umount the temporary API filesystems
umount -lf ${chroot_dir}/dev/pts 2> /dev/null || true
umount -lf ${chroot_dir}/* 2> /dev/null || true

# Tar the entire rootfs
cd ${chroot_dir} && XZ_OPT="-3 -T0" tar -cpJf ../ubuntu-${RELASE_VERSION}-preinstalled-desktop-arm64.rootfs.tar.xz . && cd ..
