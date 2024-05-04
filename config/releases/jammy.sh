# shellcheck shell=bash

RELASE_NAME="Ubuntu 22.04 LTS (Jammy Jellyfish)"
RELASE_VERSION="22.04"
if [ -z "${KERNEL_TARGET}" ]; then
    KERNEL_TARGET="rockchip-5.10"
fi
