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
    git clone --progress -b orange-pi-5.10-rk3588 https://github.com/orangepi-xunlong/linux-orangepi
    git -C linux-orangepi checkout 161606b049488da100e5d7ec95c8997d3b59b20d
    git -C linux-orangepi apply ../../patches/linux-orangepi/0001-debianize-kernel-package.patch
    git -C linux-orangepi apply ../../patches/linux-orangepi/0002-enable-hardware-cursor.patch
    git -C linux-orangepi apply ../../patches/linux-orangepi/0003-hdmi-sound-improvements.patch
    git -C linux-orangepi apply ../../patches/linux-orangepi/0001-dma-buf-add-dma_resv_get_singleton-v2.patch
    git -C linux-orangepi apply ../../patches/linux-orangepi/0002-dma-buf-Add-an-API-for-exporting-sync-files-v14.patch
    git -C linux-orangepi apply ../../patches/linux-orangepi/0003-dma-buf-Add-an-API-for-importing-sync-files-v10.patch
    git -C linux-orangepi apply ../../patches/linux-orangepi/0004-MALI-bifrost-avoid-fence-double-free.patch
    git -C linux-orangepi apply ../../patches/linux-orangepi/0005-drm-rockchip-Re-add-implicit-fencing-support-for-pla.patch
    git -C linux-orangepi apply ../../patches/linux-orangepi/0008-Revert-ANDROID-clk-Enable-writable-debugfs-files.patch
fi
cd linux-orangepi

# Set kernel config 
cp ../../config/linux-rockchip-rk3588-legacy.config .config
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig
./scripts/config --disable CONFIG_DEBUG_INFO
./scripts/config --disable MODULE_SCMVERSION

# Set custom kernel version
./scripts/config --enable CONFIG_LOCALVERSION_AUTO
echo "-orange-pi" > .scmversion
echo "0" > .version

# Compile kernel into deb package
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j "$(nproc)"
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j "$(nproc)" bindeb-pkg
