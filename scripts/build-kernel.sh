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

if [[ "${BOARD}" =~ orangepi5|orangepi5b ]]; then
    GIT_DEBIAN=https://github.com/Joshua-Riek/linux-orangepi-debian.git
    DEBIAN_COMMIT=544677b6f204afd1095d844da2584a8da925d490
    VENDOR=orangepi
elif [[ "${BOARD}" =~ rock5b|rock5a ]]; then
    GIT_DEBIAN=https://github.com/Joshua-Riek/linux-radxa-debian.git
    DEBIAN_COMMIT=cffe1e86090c4dddcbb5d1e201b5cca5e83caeb0
    VENDOR=radxa
else
    echo "Error: \"${BOARD}\" is an unsupported board"
    exit 1
fi

if [ ! -d linux-"${VENDOR}" ]; then
    git clone "${GIT_DEBIAN}" linux-"${VENDOR}"-debian
    git -C linux-"${VENDOR}"-debian checkout "${DEBIAN_COMMIT}"

    # shellcheck source=/dev/null
    source linux-"${VENDOR}"-debian/upstream
    git clone --single-branch --progress -b "${BRANCH}" "${GIT}" linux-"${VENDOR}"
    git -C linux-"${VENDOR}" checkout "${COMMIT}"
    mv linux-"${VENDOR}"-debian linux-"${VENDOR}"/debian
    for patch in linux-"${VENDOR}"/debian/patches/*.patch; do
        git -C linux-"${VENDOR}" apply "$(readlink -f "${patch}")"
    done
fi
cd linux-"${VENDOR}"

# Compile kernel into a deb package
ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- ./debian/rules build
ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- ./debian/rules binary-arch

rm -f ../*.buildinfo ../*.changes ../linux-libc-dev*
