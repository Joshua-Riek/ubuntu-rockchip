#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

if [ "$(id -u)" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..
mkdir -p build && cd build

if [ ! -d linux-rockchip ]; then
    git clone --single-branch --progress -b "linux-5.10-gen-rkr4" "https://github.com/Joshua-Riek/linux-rockchip" linux-rockchip
fi
cd linux-rockchip

# Compile kernel into a deb package
dpkg-buildpackage -a "$(cat debian/arch)" -d -b -nc -uc

rm -f ../*.buildinfo ../*.changes
