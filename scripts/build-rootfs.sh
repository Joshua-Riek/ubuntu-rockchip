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
    git clone --depth 1 --progress -b master https://github.com/orangepi-xunlong/firmware.git
fi

# These env vars can cause issues with chroot
unset TMP
unset TEMP
unset TMPDIR

# Debootstrap options
arch=arm64
mirror=http://ports.ubuntu.com/ubuntu-ports
chroot_dir=rootfs

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
pigz wget curl grub-common grub2-common grub-efi-arm64 grub-efi-arm64-bin gdisk

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
EOF

# Create user accounts
cat << EOF | chroot ${chroot_dir} /bin/bash
set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

# Setup user account
adduser --shell /bin/bash --gecos ubuntu --disabled-password ubuntu
usermod -a -G sudo,video,adm,dialout,cdrom,audio,plugdev ubuntu
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
echo "nameserver 8.8.8.8" > ${chroot_dir}/etc/resolv.conf

# Hostname
echo "orange-pi" > ${chroot_dir}/etc/hostname

# Networking interfaces
cat > ${chroot_dir}/etc/network/interfaces << EOF
auto lo
iface lo inet loopback

allow-hotplug eth0
iface eth0 inet dhcp

allow-hotplug enp0s3
iface enp0s3 inet dhcp

allow-hotplug wlan0
iface wlan0 inet dhcp
    wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf
EOF

# Hosts file
cat > ${chroot_dir}/etc/hosts << EOF
127.0.0.1       localhost
127.0.1.1       raspberry-pi

::1             localhost ip6-localhost ip6-loopback
fe00::0         ip6-localnet
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters
ff02::3         ip6-allhosts
EOF

# WIFI
cat > ${chroot_dir}/etc/wpa_supplicant/wpa_supplicant.conf << EOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=US

network={
    ssid="your_home_ssid"
    psk="your_home_psk"
    key_mgmt=WPA-PSK
    priority=1
}

network={
    ssid="your_work_ssid"
    psk="your_work_psk"
    key_mgmt=WPA-PSK
    priority=2
}
EOF

# Serial console resize script
cat > ${chroot_dir}/etc/profile.d/resize.sh << 'EOF'
if [ -t 0 -a $# -eq 0 ]; then
    if [ ! -x @BINDIR@/resize ] ; then
        if [ -n "$BASH_VERSION" ] ; then
            # Optimized resize funciton for bash
            resize() {
                local x y
                IFS='[;' read -t 2 -p $(printf '\e7\e[r\e[999;999H\e[6n\e8') -sd R _ y x _
                [ -n "$y" ] && \
                echo -e "COLUMNS=$x;\nLINES=$y;\nexport COLUMNS LINES;" && \
                stty cols $x rows $y
            }
        else
            # Portable resize function for ash/bash/dash/ksh
            # with subshell to avoid local variables
            resize() {
                (o=$(stty -g)
                stty -echo raw min 0 time 2
                printf '\0337\033[r\033[999;999H\033[6n\0338'
                if echo R | read -d R x 2> /dev/null; then
                    IFS='[;R' read -t 2 -d R -r z y x _
                else
                    IFS='[;R' read -r _ y x _
                fi
                stty "$o"
                [ -z "$y" ] && y=${z##*[}&&x=${y##*;}&&y=${y%%;*}
                [ -n "$y" ] && \
                echo "COLUMNS=$x;"&&echo "LINES=$y;"&&echo "export COLUMNS LINES;"&& \
                stty cols $x rows $y)
            }
        fi
    fi
    # Use the EDITOR not being set as a trigger to call resize
    # and only do this for /dev/tty[A-z] which are typically
    # serial ports
    if [ -z "$EDITOR" -a "$SHLVL" = 1 ] ; then
        case $(tty 2>/dev/null) in
            /dev/tty[A-z]*) resize >/dev/null;;
        esac
    fi
fi
EOF

# Expand root filesystem on first boot
cat > ${chroot_dir}/etc/init.d/expand-rootfs.sh << 'EOF'
#!/bin/bash
### BEGIN INIT INFO
# Provides: expand-rootfs.sh
# Required-Start:
# Required-Stop:
# Default-Start: 2 3 4 5 S
# Default-Stop:
# Short-Description: Resize the root filesystem to fill partition
# Description:
### END INIT INFO

# Get the root partition
partition_root="$(findmnt -n -o SOURCE /)"
partition_name="$(lsblk -no name "${partition_root}")"
partition_pkname="$(lsblk -no pkname "${partition_root}")"
partition_num="$(echo "${partition_name}" | grep -Eo '[0-9]+$')"

# Get size of disk and root partition
partition_start="$(cat /sys/block/${partition_pkname}/${partition_name}/start)"
partition_end="$(( partition_start + $(cat /sys/block/${partition_pkname}/${partition_name}/size)))"
partition_newend="$(( $(cat /sys/block/${partition_pkname}/size) - 8))"

# Resize partition and filesystem
if [ "${partition_newend}" -gt "${partition_end}" ]; then
    sgdisk -e "/dev/${partition_pkname}"
    sgdisk -d "${partition_num}" "/dev/${partition_pkname}"
    sgdisk -N "${partition_num}" "/dev/${partition_pkname}"
    partprobe "/dev/${partition_pkname}"
    resize2fs "/dev/${partition_name}"
    sync
fi

# Remove script
update-rc.d expand-rootfs.sh remove
EOF

# Install init script to expand the rootfs
chmod +x ${chroot_dir}/etc/init.d/expand-rootfs.sh
chroot ${chroot_dir} /bin/bash -c "update-rc.d expand-rootfs.sh defaults"

# Enable the USB 2.0 port on boot
cat > ${chroot_dir}/etc/init.d/enable-usb2.sh << 'EOF'
#!/bin/bash
### BEGIN INIT INFO
# Provides: enable-usb2.sh
# Required-Start:
# Required-Stop:
# Default-Start: 2 3 4 5 S
# Default-Stop:
# Short-Description: Enable the USB 2.0 port
# Description:
### END INIT INFO

# Enable the USB 2.0 port by setting host mode
if [ "$(cat /sys/kernel/debug/usb/fc000000.usb/mode)" != "host" ]; then
    echo "host" > /sys/kernel/debug/usb/fc000000.usb/mode
fi
EOF

# Install init script to enable the USB 2.0 port
chmod +x ${chroot_dir}/etc/init.d/enable-usb2.sh
chroot ${chroot_dir} /bin/bash -c "update-rc.d enable-usb2.sh defaults"

# Enable rc-local
echo -e '#!/bin/sh -e\n\nexit 0' > ${chroot_dir}/etc/rc.local
chmod +x ${chroot_dir}/etc/rc.local

# Set term for serial tty
mkdir -p ${chroot_dir}/lib/systemd/system/serial-getty@.service.d
echo "[Service]" > ${chroot_dir}/lib/systemd/system/serial-getty@.service.d/10-term.conf
echo "Environment=TERM=linux" >> ${chroot_dir}/lib/systemd/system/serial-getty@.service.d/10-term.conf

# Remove release upgrade motd
rm -f ${chroot_dir}/var/lib/ubuntu-release-upgrader/release-upgrade-available
sed -i 's/^Prompt.*/Prompt=never/' ${chroot_dir}/etc/update-manager/release-upgrades

# Copy the orange pi firmware
cp -r firmware ${chroot_dir}/usr/lib/

# Umount the temporary API filesystems
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
DEBIAN_FRONTEND=noninteractive apt-get -y install ubuntu-desktop dbus-x11

# Firefox has no gpu support 
DEBIAN_FRONTEND=noninteractive apt-get -y purge firefox

# Clean package cache
apt-get -y autoremove && apt-get -y clean && apt-get -y autoclean
EOF

# Enable mpp and rga hardware acceleration
cat > ${chroot_dir}/etc/udev/rules.d/11-rockchip-multimedia.rules << EOF
KERNEL=="mpp_service", MODE="0660", GROUP="video"
KERNEL=="rga", MODE="0660", GROUP="video"
KERNEL=="system-dma32", MODE="0666", GROUP="video"
KERNEL=="system-uncached-dma32", MODE="0666", GROUP="video" RUN+="/usr/bin/chmod a+rw /dev/dma_heap"
EOF

# Enable wayland session
sed -i 's/#WaylandEnable=false/WaylandEnable=true/g' ${chroot_dir}/etc/gdm3/custom.conf

# Use wayland as default desktop session
echo "[User]" > ${chroot_dir}/var/lib/AccountsService/users/ubuntu 
echo "XSession=ubuntu-wayland" >> ${chroot_dir}/var/lib/AccountsService/users/ubuntu 

# Improve mesa performance 
echo "PAN_MESA_DEBUG=gofaster" >> ${chroot_dir}/etc/environment

# Set chromium as default browser
chroot ${chroot_dir} /bin/bash -c "update-alternatives --install /usr/bin/x-www-browser x-www-browser /usr/bin/chromium 500"
chroot ${chroot_dir} /bin/bash -c "update-alternatives --set x-www-browser /usr/bin/chromium"

# Add chromium to favorites bar
chroot ${chroot_dir} /bin/bash -c "sudo -u ubuntu dbus-launch gsettings set org.gnome.shell favorite-apps \
\"['ubiquity.desktop', 'chromium.desktop', 'thunderbird.desktop', 'org.gnome.Nautilus.desktop', \
'rhythmbox.desktop', 'libreoffice-writer.desktop', 'snap-store_ubuntu-software.desktop', 'yelp.desktop']\""

# Umount the temporary API filesystems
umount -lf ${chroot_dir}/dev/pts 2> /dev/null || true
umount -lf ${chroot_dir}/* 2> /dev/null || true

# Tar the entire rootfs
cd ${chroot_dir} && XZ_OPT="-0 -T0" tar -cpJf ../ubuntu-${version}-preinstalled-desktop-arm64-orange-pi5.rootfs.tar.xz . && cd ..
../scripts/build-image.sh ubuntu-${version}-preinstalled-desktop-arm64-orange-pi5.rootfs.tar.xz
