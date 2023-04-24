#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

usage() {
cat << HEREDOC
Usage: $0 --board=[orangepi5|orangepi5b]

Required arguments:
  -b, --board=BOARD     target board 

Optional arguments:
  -h, --help            show this help message and exit
  -d, --docker          use docker to build
  -k, --kernel-only     only compile the kernel
  -u, --uboot-only      only compile uboot
  -l, --launchpad       use kernel and uboot from launchpad repo
  -v, --verbose         increase the verbosity of the bash script
HEREDOC
}

if [ "$(id -u)" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

cd "$(dirname -- "$(readlink -f -- "$0")")"

for i in "$@"; do
    case $i in
        -h|--help)
            usage
            exit 0
            ;;
        -b=*|--board=*)
            export BOARD="${i#*=}"
            shift
            ;;
        -b|--board)
            export BOARD="${2}"
            shift
            ;;
        -d|--docker)
            DOCKER="docker run --privileged --network=host --rm -it -v \"$(pwd)\":/opt -e BOARD -e LAUNCHPAD ubuntu-orange-pi5-build /bin/bash"
            docker build -t ubuntu-orange-pi5-build docker
            shift
            ;;
        -k|--kernel-only)
            KERNEL_ONLY=Y
            shift
            ;;
        -u|--uboot-only)
            UBOOT_ONLY=Y
            shift
            ;;
        -l|--launchpad)
            export LAUNCHPAD=Y
            shift
            ;;
        -v|--verbose)
            set -x
            shift
            ;;
        -*)
            echo "Error: unknown argument \"$i\""
            exit 1
            ;;
        *)
            ;;
    esac
done

if [[ -z ${BOARD} ]]; then
    usage
    exit 1
fi

if [[ ! ${BOARD} =~ orangepi5|orangepi5b ]]; then
    echo "Error: \"${BOARD}\" is an unsupported board"
    exit 1
fi

if [[ ${KERNEL_ONLY}  == "Y" ]]; then
    eval "${DOCKER}" ./scripts/build-kernel.sh
    exit 0
fi

if [[ ${UBOOT_ONLY}  == "Y" ]]; then
    eval "${DOCKER}" ./scripts/build-u-boot.sh
    exit 0
fi

if [[ ${LAUNCHPAD} != "Y" ]]; then
    eval "${DOCKER}" ./scripts/build-kernel.sh
fi

if [[ ${LAUNCHPAD} != "Y" ]]; then
    eval "${DOCKER}" ./scripts/build-u-boot.sh
fi

eval "${DOCKER}" ./scripts/build-rootfs.sh

exit 0
