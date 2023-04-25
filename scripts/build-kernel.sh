#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

if [ "$(id -u)" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..
mkdir -p build && cd build

if [[ -z ${BOARD} ]]; then
    echo "Error: BOARD is not set"
    exit 1
fi

# Download the linux kernel source and debian package template
if [[ "${BOARD}" =~ orangepi5|orangepi5b ]]; then
    if [ ! -d linux-orangepi ]; then
        git clone https://github.com/Joshua-Riek/linux-orangepi-debian.git
        git -C linux-orangepi-debian checkout 544677b6f204afd1095d844da2584a8da925d490

        # shellcheck source=/dev/null
        source linux-orangepi-debian/upstream
        git clone --single-branch --progress -b "${BRANCH}" "${GIT}"
        git -C linux-orangepi checkout "${COMMIT}"
        mv linux-orangepi-debian linux-orangepi/debian
        for patch in linux-orangepi/debian/patches/*.patch; do
            git -C linux-orangepi apply "$(readlink -f "${patch}")"
        done
    fi
    cd linux-orangepi
else
    echo "Error: \"${BOARD}\" is an unsupported board"
    exit 1
fi

# Compile kernel into a deb package
ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- ./debian/rules build
ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- ./debian/rules binary-arch

rm -f ../*.buildinfo ../*.changes ../linux-libc-dev*
