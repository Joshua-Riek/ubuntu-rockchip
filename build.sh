#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

cd "$(dirname -- "$(readlink -f -- "$0")")"

usage() {
cat << HEREDOC
Usage: $0 --board=[orangepi-5] --project=[preinstalled-desktop] --release=[jammy] --kernel=[bsp]

Required arguments:
  -b, --board=BOARD      target board 
  -r, --release=RELEASE  ubuntu release
  -p, --project=PROJECT  ubuntu project
  -k, --kernel=KERNEL    kernel target

Optional arguments:
  -h,  --help            show this help message and exit
  -c,  --clean           clean the build directory
  -d,  --docker          use docker to build
  -ko,  --kernel-only    only compile the kernel
  -uo,  --uboot-only     only compile uboot
  -ro, --rootfs-only     only build rootfs
  -so, --server-only     only build server image
  -do, --desktop-only    only build desktop image
  -m,  --mainline        use mainline linux sources
  -l,  --launchpad       use kernel and uboot from launchpad repo
  -v,  --verbose         increase the verbosity of the bash script
HEREDOC
}

if [ "$(id -u)" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

cd "$(dirname -- "$(readlink -f -- "$0")")"

while [ "$#" -gt 0 ]; do
    case "${1}" in
        -h|--help)
            usage
            exit 0
            ;;
        -b=*|--board=*)
            export BOARD="${1#*=}"
            shift
            ;;
        -b|--board)
            export BOARD="${2}"
            shift 2
            ;;
        -r=*|--release=*)
            export RELEASE="${1#*=}"
            shift
            ;;
        -r|--release)
            export RELEASE="${2}"
            shift 2
            ;;
        -p=*|--project=*)
            export PROJECT="${1#*=}"
            shift
            ;;
        -p|--project)
            export PROJECT="${2}"
            shift 2
            ;;
        -k=*|--kernel=*)
            export KERNEL_TARGET="${1#*=}"
            shift
            ;;
        -k|--kernel)
            export KERNEL_TARGET="${2}"
            shift 2
            ;;
        -d|--docker)
            DOCKER="docker run --privileged --network=host --rm -it -v \"$(pwd)\":/opt -e BOARD -e VENDOR -e LAUNCHPAD -e MAINLINE -e SERVER_ONLY -e DESKTOP_ONLY -e KERNEL_ONLY -e UBOOT_ONLY ubuntu-rockchip-build /bin/bash"
            docker build -t ubuntu-rockchip-build docker
            shift
            ;;
        -ko|--kernel-only)
            export KERNEL_ONLY=Y
            shift
            ;;
        -uo|--uboot-only)
            export UBOOT_ONLY=Y
            shift
            ;;
        -ro|--rootfs-only)
            export ROOTFS_ONLY=Y
            shift
            ;;
        -do|--desktop-only)
            export DESKTOP_ONLY=Y
            shift
            ;;
        -so|--server-only)
            export SERVER_ONLY=Y
            shift
            ;;
        -l|--launchpad)
            export LAUNCHPAD=Y
            shift
            ;;
        -c|--clean)
            export CLEAN=Y
            shift
            ;;
        -v|--verbose)
            set -x
            shift
            ;;
        -*)
            echo "Error: unknown argument \"${1}\""
            exit 1
            ;;
        *)
            shift
            ;;
    esac
done

if [ "${BOARD}" == "help" ]; then
    for file in config/boards/*; do
        basename "${file%.conf}"
    done
    exit 0
fi

if [ -n "${BOARD}" ]; then
    while :; do
        for file in config/boards/*; do
            if [ "${BOARD}" == "$(basename "${file%.conf}")" ]; then
                # shellcheck source=/dev/null
                set -o allexport && source "${file}" && set +o allexport
                break 2
            fi
        done
        echo "Error: \"${BOARD}\" is an unsupported board"
        exit 1
    done
fi

if [ "${KERNEL_TARGET}" == "help" ]; then
    for file in config/kernels/*; do
        basename "${file%.conf}"
    done
    exit 0
fi

if [ -n "${KERNEL_TARGET}" ]; then
    while :; do
        for file in config/kernels/*; do
            if [ "${KERNEL_TARGET}" == "$(basename "${file%.conf}")" ]; then
                # shellcheck source=/dev/null
                set -o allexport && source "${file}" && set +o allexport
                break 2
            fi
        done
        echo "Error: \"${KERNEL_TARGET}\" is an unsupported kernel"
        exit 1
    done
fi


if [ "${RELEASE}" == "help" ]; then
    for file in config/releases/*; do
        basename "${file%.sh}"
    done
    exit 0
fi

if [ -n "${RELEASE}" ]; then
    while :; do
        for file in config/releases/*; do
            if [ "${RELEASE}" == "$(basename "${file%.sh}")" ]; then
                # shellcheck source=/dev/null
                source "${file}"
                break 2
            fi
        done
        echo "Error: \"${RELEASE}\" is an unsupported release"
        exit 1
    done
fi

# No board param passed
if [ -z "${BOARD}" ] || [ -z "${KERNEL_TARGET}" ] || [ -z "${RELEASE}" ]; then
    usage
    exit 1
fi

# Clean the build directory
if [[ ${CLEAN} == "Y" ]]; then
    if [ -d build/rootfs ]; then
        umount -lf build/rootfs/dev/pts 2> /dev/null || true
        umount -lf build/rootfs/* 2> /dev/null || true
    fi
    rm -rf build
fi

# Start logging the build process
mkdir -p build/logs && exec > >(tee "build/logs/build-$(date +"%Y%m%d%H%M%S").log") 2>&1

# Build only the Linux kernel then exit
if [[ ${KERNEL_ONLY} == "Y" ]]; then
    eval "${DOCKER}" ./scripts/build-kernel.sh
    exit 0
fi

# Build only U-Boot then exit
if [[ ${UBOOT_ONLY} == "Y" ]]; then
    eval "${DOCKER}" ./scripts/build-u-boot.sh
    exit 0
fi

# Build only the rootfs then exit
if [[ ${ROOTFS_ONLY} == "Y" ]]; then
    eval "${DOCKER}" ./scripts/build-rootfs.sh
    exit 0
fi

# Build the Linux kernel if not found
if [[ ${LAUNCHPAD} != "Y" ]]; then
    if [[ ! -e "$(find build/linux-image-*.deb | sort | tail -n1)" || ! -e "$(find build/linux-headers-*.deb | sort | tail -n1)" ]]; then
        eval "${DOCKER}" ./scripts/build-kernel.sh
    fi
fi

# Build U-Boot if not found
if [[ ${LAUNCHPAD} != "Y" ]]; then
    if [[ ! -e "$(find build/u-boot-"${BOARD}"_*.deb | sort | tail -n1)" ]]; then
        eval "${DOCKER}" ./scripts/build-u-boot.sh
    fi
fi

# Create the root filesystem
eval "${DOCKER}" ./scripts/build-rootfs.sh

# Create the disk image
eval "${DOCKER}" ./scripts/config-image.sh

exit 0
