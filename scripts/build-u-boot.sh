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

# Download the orangepi u-boot source
if [ ! -d u-boot-orangepi ]; then
    git clone https://github.com/Joshua-Riek/u-boot-orangepi-debian.git
    git -C u-boot-orangepi-debian checkout 53ec02881ff0a48719fb0b0c636eb43e657eeb6d

    # shellcheck source=/dev/null
    source u-boot-orangepi-debian/upstream
    git clone --single-branch --progress -b "${BRANCH}" "${GIT}"
    git -C u-boot-orangepi checkout "${COMMIT}"
    mv u-boot-orangepi-debian u-boot-orangepi/debian
    for patch in u-boot-orangepi/debian/patches/*.patch; do
        git -C u-boot-orangepi apply "$(readlink -f "${patch}")"
    done
fi
cd u-boot-orangepi

# shellcheck disable=SC2046
export $(dpkg-architecture -aarm64)

# Compile u-boot into a deb package
CROSS_COMPILE=aarch64-linux-gnu- ./debian/rules build-"${BOARD}"
CROSS_COMPILE=aarch64-linux-gnu- ./debian/rules binary-"${BOARD}"
