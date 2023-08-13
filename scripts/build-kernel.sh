#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

if [ "$(id -u)" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..
mkdir -p build && cd build

if [[ 1 == 1 ]]; then
    test -d linux-rockchip || git clone --single-branch --progress -b  linux-5.10-gen-rkr4 https://github.com/Joshua-Riek/linux-rockchip.git linux-rockchip
    cd linux-rockchip

    # Compile kernel into a deb package
    dpkg-buildpackage -a "$(cat debian/arch)" -d -b -nc -uc

    rm -f ../*.buildinfo ../*.changes
else
    test -d linux ||  git clone --single-branch --progress -b rk3588-test https://github.com/Joshua-Riek/linux.git --depth=100
    cd linux

    make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- linux-rockchip-rk3588-collabora_defconfig
    ./scripts/config --disable CONFIG_DEBUG_INFO
    ./scripts/config --disable DEBUG_INFO

    echo "0" > .version
    echo "" > .scmversion
    make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- bindeb-pkg -j16

    rm -f ../linux-image-*dbg*.deb
    rm -f ../linux-libc-dev_*.deb
    rm -f ../*.buildinfo ../*.changes ../*.dsc ../*.tar.gz
fi
