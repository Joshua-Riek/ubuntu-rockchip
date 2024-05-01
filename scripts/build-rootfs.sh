#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

if [ "$(id -u)" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..
mkdir -p build && cd build

if [[ -z ${RELEASE} ]]; then
    echo "Error: RELEASE is not set"
    exit 1
fi

# shellcheck source=/dev/null
source "../config/releases/${RELEASE}.sh"

if [[ -z ${PROJECT} ]]; then
    echo "Error: PROJECT is not set"
    exit 1
fi

# shellcheck source=/dev/null
source "../config/projects/${PROJECT}.sh"

if [[ -f ubuntu-${RELASE_VERSION}-${PROJECT}-arm64.rootfs.tar.xz ]]; then
    exit 0
fi

git clone https://github.com/Joshua-Riek/ubuntu-live-build.git
cd ubuntu-live-build
docker build -t livecd-rootfs docker
docker run --privileged -v /dev:/dev --rm -v "$(pwd)":/opt livecd-rootfs bash ./build.sh "--${PROJECT//preinstalled-}" "--${RELEASE}"
mv "./build/ubuntu-${RELASE_VERSION}-${PROJECT}-arm64.rootfs.tar.xz" ../
