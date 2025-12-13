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

# Clone the kernel repo
if ! git -C linux-rockchip pull; then
    git clone --progress -b "${KERNEL_BRANCH}" "${KERNEL_REPO}" linux-rockchip --depth=2
fi

cd linux-rockchip
git checkout "${KERNEL_BRANCH}"

# Apply custom kernel patches if available
KERNEL_PATCHES_DIR="../../patches/kernel"
if [ -d "${KERNEL_PATCHES_DIR}" ] && [ -f "${KERNEL_PATCHES_DIR}/series" ]; then
    echo "Applying custom kernel patches..."
    while IFS= read -r patch || [ -n "$patch" ]; do
        # Skip empty lines and comments
        [[ -z "$patch" || "$patch" =~ ^# ]] && continue
        patch_file="${KERNEL_PATCHES_DIR}/${patch}"
        if [ -f "$patch_file" ]; then
            echo "Applying patch: $patch"
            if ! git apply --check "$patch_file" 2>/dev/null; then
                echo "Warning: Patch $patch may already be applied or conflicts exist, trying with --reverse check"
                if git apply --reverse --check "$patch_file" 2>/dev/null; then
                    echo "Patch $patch already applied, skipping"
                    continue
                fi
            fi
            git apply "$patch_file" || echo "Warning: Failed to apply $patch"
        else
            echo "Warning: Patch file not found: $patch_file"
        fi
    done < "${KERNEL_PATCHES_DIR}/series"
    echo "Custom kernel patches applied."
fi

# shellcheck disable=SC2046
export $(dpkg-architecture -aarm64)
export CROSS_COMPILE=aarch64-linux-gnu-
export CC=aarch64-linux-gnu-gcc
export LANG=C

# Compile the kernel into a deb package
fakeroot debian/rules clean binary-headers binary-rockchip do_mainline_build=true
