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
    git -C u-boot-orangepi checkout 7103c6a88178f2ed12ef578c49b71a54ec80b4a1
fi
cd u-boot-orangepi

# Set u-boot config with sata support
make ARCH=arm CROSS_COMPILE=aarch64-linux-gnu- orangepi_5_sata_defconfig

# Set custom u-boot version
sed -i 's/CONFIG_LOCALVERSION=""/CONFIG_LOCALVERSION="-orange-pi"/g' .config
touch .scmversion

# Create u-boot binary with atf
make ARCH=arm CROSS_COMPILE=aarch64-linux-gnu- -j "$(nproc)" BL31=../rkbin/bin/rk35/rk3588_bl31_v1.27.elf spl/u-boot-spl.bin u-boot.dtb u-boot.itb

# Create secondary program loader
./tools/mkimage -n rk3588 -T rksd -d ../rkbin/bin/rk35/rk3588_ddr_lp4_2112MHz_lp5_2736MHz_v1.08.bin:spl/u-boot-spl.bin idbloader.img

# Create spi bootloader image with sata support 
dd if=/dev/zero of=rkspi_loader_sata.img bs=1M count=0 seek=16
parted -s rkspi_loader_sata.img mklabel gpt
parted -s rkspi_loader_sata.img unit s mkpart idbloader 64 7167
parted -s rkspi_loader_sata.img unit s mkpart vnvm 7168 7679
parted -s rkspi_loader_sata.img unit s mkpart reserved_space 7680 8063
parted -s rkspi_loader_sata.img unit s mkpart reserved1 8064 8127
parted -s rkspi_loader_sata.img unit s mkpart uboot_env 8128 8191
parted -s rkspi_loader_sata.img unit s mkpart reserved2 8192 16383
parted -s rkspi_loader_sata.img unit s mkpart uboot 16384 32734
dd if=idbloader.img of=rkspi_loader_sata.img seek=64 conv=notrunc
dd if=u-boot.itb of=rkspi_loader_sata.img seek=16384 conv=notrunc

# Set u-boot config
make ARCH=arm CROSS_COMPILE=aarch64-linux-gnu- orangepi_5_defconfig

# Set custom u-boot version
sed -i 's/CONFIG_LOCALVERSION=""/CONFIG_LOCALVERSION="-orange-pi"/g' .config
touch .scmversion

# Create u-boot binary with atf
make ARCH=arm CROSS_COMPILE=aarch64-linux-gnu- -j "$(nproc)" BL31=../rkbin/bin/rk35/rk3588_bl31_v1.27.elf spl/u-boot-spl.bin u-boot.dtb u-boot.itb

# Create secondary program loader
./tools/mkimage -n rk3588 -T rksd -d ../rkbin/bin/rk35/rk3588_ddr_lp4_2112MHz_lp5_2736MHz_v1.08.bin:spl/u-boot-spl.bin idbloader.img

# Create spi bootloader image
dd if=/dev/zero of=rkspi_loader.img bs=1M count=0 seek=16
parted -s rkspi_loader.img mklabel gpt
parted -s rkspi_loader.img unit s mkpart idbloader 64 7167
parted -s rkspi_loader.img unit s mkpart vnvm 7168 7679
parted -s rkspi_loader.img unit s mkpart reserved_space 7680 8063
parted -s rkspi_loader.img unit s mkpart reserved1 8064 8127
parted -s rkspi_loader.img unit s mkpart uboot_env 8128 8191
parted -s rkspi_loader.img unit s mkpart reserved2 8192 16383
parted -s rkspi_loader.img unit s mkpart uboot 16384 32734
dd if=idbloader.img of=rkspi_loader.img seek=64 conv=notrunc
dd if=u-boot.itb of=rkspi_loader.img seek=16384 conv=notrunc
