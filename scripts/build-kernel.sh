#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

if [ "$(id -u)" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..
mkdir -p build && cd build

# Download the orange pi linux kernel source
if [ ! -d linux-orangepi ]; then
    git clone --progress -b orange-pi-5.10-rk3588 https://github.com/orangepi-xunlong/linux-orangepi.git
    git -C linux-orangepi checkout 88961a71100e64a97124a674eff8b71863d4cbbc
    git -C linux-orangepi apply ../../patches/linux-orangepi/0001-Revert-ANDROID-clk-Enable-writable-debugfs-files.patch
    git -C linux-orangepi apply ../../patches/linux-orangepi/0002-debianize-kernel-package.patch
    git -C linux-orangepi apply ../../patches/linux-orangepi/0003-hdmi-sound-improvements.patch
    git -C linux-orangepi apply ../../patches/linux-orangepi/0004-fix-dw-dp-warning-msg.patch
fi
cd linux-orangepi

# Set kernel config 
cp ../../config/linux-rockchip-rk3588-legacy.config .config
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig
./scripts/config --disable CONFIG_DEBUG_INFO
./scripts/config --disable CONFIG_MODULE_SCMVERSION

# Set custom kernel version
./scripts/config --enable CONFIG_LOCALVERSION_AUTO
echo "-rockchip-rk3588" > .scmversion
echo "0" > .version

# Compile kernel into deb package
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j "$(nproc)"
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j "$(nproc)" bindeb-pkg
