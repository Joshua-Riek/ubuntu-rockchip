#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

if [ "$(id -u)" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..
mkdir -p build && cd build

if [[ -z ${KERNEL_CONFIG} ]]; then
    echo "Error: KERNEL_CONFIG is not set"
    exit 1
fi

# shellcheck source=/dev/null
source ../config/kernel/"${KERNEL_CONFIG}"

if ! git -C "${KERNEL_CLONE_DIR}" pull; then
    git clone --progress -b "${KERNEL_BRANCH}" "${KERNEL_REPO}" "${KERNEL_CLONE_DIR}" --depth=2
fi

cd "${KERNEL_CLONE_DIR}"
git checkout "${KERNEL_BRANCH}"

if [[ ${DPKG_BUILDPACKAGE} == "Y" ]]; then
    dpkg-buildpackage -a "$(cat debian/arch)" -d -b -nc -uc
else
    echo 1 > .version
    touch .scmversion

    make "${KERNEL_DEFCONFIG}" \
    CROSS_COMPILE=aarch64-linux-gnu- \
    ARCH=arm64 \
    -j "$(nproc)"

    make bindeb-pkg \
    KBUILD_IMAGE="arch/arm64/boot/Image" \
    KDEB_PKGVERSION="$(make kernelversion)-1" \
    KERNELRELEASE="$(make kernelversion)-rockchip" \
    CROSS_COMPILE=aarch64-linux-gnu- \
    ARCH=arm64 \
    -j "$(nproc)"
fi

rm -f ../linux-image-*dbg*.deb ../linux-libc-dev_*.deb ../*.buildinfo ../*.changes ../*.dsc ../*.tar.gz
