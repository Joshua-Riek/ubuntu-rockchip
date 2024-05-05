# shellcheck shell=bash

export RELASE_NAME="Ubuntu 22.04 LTS (Jammy Jellyfish)"
export RELASE_VERSION="22.04"
if [ -z "${KERNEL_TARGET}" ]; then
    export KERNEL_TARGET="rockchip-5.10"
fi
