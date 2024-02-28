#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

if [ "$(id -u)" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..
mkdir -p build && cd build

if [[ -z ${KERNEL_TARGET} ]]; then
    echo "Error: KERNEL_TARGET is not set"
    exit 1
fi

# shellcheck source=/dev/null
source ../config/kernels/"${KERNEL_TARGET}.conf"

# Clone the kernel repo
if ! git -C "${KERNEL_CLONE_DIR}" pull; then
    git clone --progress -b "${KERNEL_BRANCH}" "${KERNEL_REPO}" "${KERNEL_CLONE_DIR}" --depth=2
fi

cd "${KERNEL_CLONE_DIR}"
git checkout "${KERNEL_BRANCH}"

if [[ ${DPKG_BUILDPACKAGE} == "Y" ]]; then
    dpkg-buildpackage -a "$(cat debian/arch)" -d -b -nc -uc
else
    # Create the kernel config
    make "${KERNEL_DEFCONFIG}" \
    CROSS_COMPILE=aarch64-linux-gnu- \
    ARCH=arm64 \
    -j "$(nproc)"

    # Set kernel build number
    echo "1" > .version
    touch .scmversion

    # Compile the kernel into a deb package
    make bindeb-pkg \
    KBUILD_IMAGE="arch/arm64/boot/Image" \
    KDEB_PKGVERSION="$(make kernelversion)-rockchip-1" \
    KERNELRELEASE="$(make kernelversion)-rockchip" \
    CROSS_COMPILE=aarch64-linux-gnu- \
    ARCH=arm64 \
    -j "$(nproc)"
fi

# Cleanup garbage
rm -f ../linux-image-*dbg*.deb ../linux-libc-dev_*.deb ../*.buildinfo ../*.changes ../*.dsc ../*.tar.gz
