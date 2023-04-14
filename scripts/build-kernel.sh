#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

if [ "$(id -u)" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..
mkdir -p build && cd build

# Download and patch the orange pi linux kernel source
if [ ! -d linux-orangepi ]; then
    git clone --progress -b orange-pi-5.10-rk3588 https://github.com/Joshua-Riek/linux-orangepi.git
    #git -C linux-orangepi fetch --all --tags
    #git -C linux-orangepi checkout 5.10.110-5
fi
cd linux-orangepi

# Compile kernel into deb package
ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- ./debian/rules build
ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- ./debian/rules binary-arch

rm -f ../*.buildinfo ../*.changes ../linux-libc-dev*
