#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..
mkdir -p build && cd build

# Download and build u-boot
if [ ! -d u-boot-orangepi ]; then
    git clone --progress -b v2017.09-rk3588 https://github.com/Joshua-Riek/u-boot-orangepi.git
    git -C u-boot-orangepi checkout 475ee26c3cc3697109ef459004836fb45f105716
fi
cd u-boot-orangepi

# shellcheck disable=SC2046
export $(dpkg-architecture -aarm64)

# Compile u-boot into a deb package
CROSS_COMPILE=aarch64-linux-gnu- ./debian/rules clean
CROSS_COMPILE=aarch64-linux-gnu- ./debian/rules build
CROSS_COMPILE=aarch64-linux-gnu- ./debian/rules binary-arch
