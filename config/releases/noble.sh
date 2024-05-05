# shellcheck shell=bash

export RELASE_NAME="Ubuntu 24.04 LTS (Noble Nombat)"
export RELASE_VERSION="24.04"
if [ -z "${KERNEL_TARGET}" ]; then
    export KERNEL_TARGET="rockchip-6.1"
fi
