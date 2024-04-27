# shellcheck shell=bash

RELASE_NAME="Ubuntu 24.04 LTS (Noble Nombat)"
RELASE_VERSION="24.04"

if [ -z "${KERNEL_TARGET}" ]; then
    KERNEL_TARGET="rockchip-6.1"
fi
