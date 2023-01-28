#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

if [ "$(id -u)" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

if [ $# -ne 1 ]; then
    echo "Usage: $0 [focal|jammy]"
    exit 1
fi

if [ "$1" == "focal" ]; then
    release="focal"
elif [ "$1" == "jammy" ]; then
    release="jammy"
else
    echo "Usage: $0 [focal|jammy]"
    exit 1
fi

# Build the U-Boot bootloader
./scripts/build-u-boot.sh

# Build the Linux kernel and Device Tree Blobs
./scripts/build-kernel.sh

# Build the root file system
./scripts/build-rootfs.sh ${release}
