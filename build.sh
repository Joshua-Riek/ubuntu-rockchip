#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

if [[ -z ${BOARD} ]]; then
    echo "Usage: BOARD=[orangepi5|orangepi5b] $0 "
    exit 1
fi

if [[ ! ${BOARD} =~ orangepi5|orangepi5b ]]; then
    echo "Error: \"${BOARD}\" is an unsupported board"
    exit 1
fi

if [ "$(id -u)" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

# Build the U-Boot bootloader
./scripts/build-u-boot.sh

# Build the Linux kernel and Device Tree Blobs
./scripts/build-kernel.sh

# Build the root file system
./scripts/build-rootfs.sh
