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
    # shellcheck source=/dev/null
    source ../packages/linux-rockchip/debian/upstream
    git clone --single-branch --progress -b "${BRANCH}" "${GIT}" linux-rockchip
    git -C linux-rockchip checkout "${COMMIT}"
    cp -r ../packages/linux-rockchip/debian linux-rockchip
fi
cd linux-rockchip

# Compile kernel into a deb package
dpkg-buildpackage -a "$(cat debian/arch)" -d -b -nc -uc

rm -f ../*.buildinfo ../*.changes ../linux-libc-dev*
