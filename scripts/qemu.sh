#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

if test "$#" -ne 1; then
    echo "Usage: $0 filename.img.xz"
    exit 1
fi

img="$(readlink -f "$1")"
if [ ! -f "${img}" ]; then
    echo "Error: $1 does not exist"
    exit 1
fi

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..
mkdir -p build && cd build && mkdir -p qemu

# Decompress xz archive
filename="$(basename "${img}")"
if [ "${filename##*.}" == "xz" ]; then
    xz -dc -T0 "${img}" > "${img%.*}"
    img="$(readlink -f "${img%.*}")"
fi

# Ensure img file
filename="$(basename "${img}")"
if [ "${filename##*.}" != "img" ]; then
    echo "Error: ${filename} must be an disk image file"
    exit 1
fi

# UEFI firmware
if [ ! -f qemu/flash0.img ]; then
    dd if=/dev/zero of=qemu/flash0.img bs=1M count=64
    dd if=/usr/share/qemu-efi/QEMU_EFI.fd of=qemu/flash0.img conv=notrunc
fi

# UEFI variable store
if [ ! -f qemu/flash1.img ]; then
    dd if=/dev/zero of=qemu/flash1.img bs=1M count=64
fi

# Start qemu vm
qemu-system-aarch64 \
-smp 4 \
-m 4096M \
-machine virt \
-cpu cortex-a57 \
-device qemu-xhci \
-device usb-kbd \
-device usb-mouse \
-device virtio-gpu-pci \
-device virtio-net-pci,netdev=vnet \
-device virtio-rng-pci,rng=rng0 \
-device virtio-blk,drive=drive0,bootindex=0 \
-netdev user,id=vnet,hostfwd=:127.0.0.1:0-:22 \
-object rng-random,filename=/dev/urandom,id=rng0 \
-drive file="${img}",format=raw,if=none,id=drive0,cache=writeback \
-drive file=qemu/flash0.img,format=raw,if=pflash \
-drive file=qemu/flash1.img,format=raw,if=pflash 
