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
fi
cd linux-"${VENDOR}"

# Compile kernel into a deb package
CROSS_COMPILE=aarch64-linux-gnu- dpkg-buildpackage -a "$(cat debian/arch)" -d -b -nc -uc

rm -f ../*.buildinfo ../*.changes ../linux-libc-dev*
