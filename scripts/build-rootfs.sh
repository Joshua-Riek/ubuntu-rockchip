#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

if [ "$(id -u)" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..
mkdir -p build && cd build

if [[ -z ${SUITE} ]]; then
    echo "Error: SUITE is not set"
    exit 1
fi

# shellcheck source=/dev/null
source "../config/suites/${SUITE}.sh"

if [[ -z ${FLAVOR} ]]; then
    echo "Error: FLAVOR is not set"
    exit 1
fi

# shellcheck source=/dev/null
source "../config/flavors/${FLAVOR}.sh"

if [[ -f ubuntu-${RELASE_VERSION}-preinstalled-${FLAVOR}-arm64.rootfs.tar.xz ]]; then
    exit 0
fi

git clone https://github.com/Joshua-Riek/ubuntu-live-build.git
cd ubuntu-live-build
bash ./docker/build-livecd-rootfs.sh
bash ./build.sh "--${FLAVOR}" "--${SUITE}"
mv "./build/ubuntu-${RELASE_VERSION}-preinstalled-${FLAVOR}-arm64.rootfs.tar.xz" ../
