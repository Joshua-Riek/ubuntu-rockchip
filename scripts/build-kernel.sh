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

if [[ -z ${VENDOR} ]]; then
    echo "Error: VENDOR is not set"
    exit 1
fi

if [ ! -d linux-"${VENDOR}" ]; then
    # shellcheck source=/dev/null
    source ../packages/linux-"${VENDOR}"/debian/upstream
    git clone --single-branch --progress -b "${BRANCH}" "${GIT}" linux-"${VENDOR}"
    git -C linux-"${VENDOR}" checkout "${COMMIT}"
    cp -r ../packages/linux-"${VENDOR}"/debian linux-"${VENDOR}"
    for patch in ../packages/linux-"${VENDOR}"/debian/patches/*.patch; do
        git -C linux-"${VENDOR}" apply "$(readlink -f "${patch}")"
    done
fi
cd linux-"${VENDOR}"

# shellcheck disable=SC2046
export $(dpkg-architecture -aarm64)

# Compile kernel into a deb package
ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- ./debian/rules build
ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- ./debian/rules binary-arch

rm -f ../*.buildinfo ../*.changes ../linux-libc-dev*
