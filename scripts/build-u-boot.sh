#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..
mkdir -p build && cd build

# Download rockchip firmware and tool binarys
if [ ! -d rkbin ]; then
    git clone --progress -b master https://github.com/rockchip-linux/rkbin.git
    git -C rkbin checkout b0c100f1a260d807df450019774993c761beb79d
fi

# Download and build u-boot
if [ ! -d u-boot-orangepi ]; then
    git clone --progress -b v2017.09-rk3588 https://github.com/orangepi-xunlong/u-boot-orangepi.git
    git -C u-boot-orangepi checkout 6534133f97a8e4fb6db83e58dbde23aec6041ec2
fi
cd u-boot-orangepi

# Set u-boot config
sed -i 's/# CONFIG_CMD_UNZIP is not set/CONFIG_CMD_UNZIP=y/' configs/orangepi_5_defconfig
make ARCH=arm CROSS_COMPILE=aarch64-linux-gnu- orangepi_5_defconfig

# Compile u-boot binary
make ARCH=arm CROSS_COMPILE=aarch64-linux-gnu- -j "$(nproc)"

# Create u-boot binary with atf
cp "../rkbin/$(sed -n '/_bl31_/s/PATH=//p' ../rkbin/RKTRUST/RK3588TRUST.ini | tr -d '\r')" bl31.elf
make ARCH=arm CROSS_COMPILE=aarch64-linux-gnu- -j "$(nproc)" u-boot.itb

# Create secondary program loader
./tools/mkimage -n rk3588 -T rksd -d "../rkbin/$(sed -n '/_ddr_/s/FlashData=//p' ../rkbin/RKBOOT/RK3588MINIALL.ini | tr -d '\r')":spl/u-boot-spl.bin idbloader.img
