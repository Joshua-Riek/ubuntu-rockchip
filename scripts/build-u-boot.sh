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
    GIT_DEBIAN=https://github.com/Joshua-Riek/u-boot-orangepi-debian.git
    DEBIAN_COMMIT=e3ef77a112d2bc05ee66500a367b8bcc03e8db10
    VENDOR=orangepi
elif [[ "${BOARD}" =~ rock5b|rock5a ]]; then
    GIT_DEBIAN=https://github.com/Joshua-Riek/u-boot-radxa-debian.git
    DEBIAN_COMMIT=110c1f92c5fed038a2d883a527dd870c20dc38dc
    VENDOR=radxa
else
    echo "Error: \"${BOARD}\" is an unsupported board"
    exit 1
fi

if [ ! -d u-boot-"${VENDOR}" ]; then
    git clone "${GIT_DEBIAN}" u-boot-"${VENDOR}"-debian
    git -C u-boot-"${VENDOR}"-debian checkout "${DEBIAN_COMMIT}"

    # shellcheck source=/dev/null
    source u-boot-"${VENDOR}"-debian/upstream
    git clone --single-branch --progress -b "${BRANCH}" "${GIT}" u-boot-"${VENDOR}"
    git -C u-boot-"${VENDOR}" checkout "${COMMIT}"
    mv u-boot-"${VENDOR}"-debian u-boot-"${VENDOR}"/debian
    for patch in u-boot-"${VENDOR}"/debian/patches/*.patch; do
        git -C u-boot-"${VENDOR}" apply "$(readlink -f "${patch}")"
    done
fi
cd u-boot-"${VENDOR}"

# shellcheck disable=SC2046
export $(dpkg-architecture -aarm64)

# Compile u-boot into a deb package
CROSS_COMPILE=aarch64-linux-gnu- ./debian/rules build-"${BOARD}"
CROSS_COMPILE=aarch64-linux-gnu- ./debian/rules binary-"${BOARD}"
