#!/bin/bash

set -eE
trap 'echo "Error: in $0 on line $LINENO"' ERR

# Change to the script's directory only once
cd "$(dirname -- "$(readlink -f -- "$0")")"

#######################################
# Display script usage.
#######################################
usage() {
    cat << HEREDOC
Usage: $0 --board=[orangepi-5] --suite=[jammy|noble] --flavor=[server|desktop]

Required arguments:
  -b, --board=BOARD      Target board 
  -s, --suite=SUITE      Ubuntu suite 
  -f, --flavor=FLAVOR    Ubuntu flavor

Optional arguments:
  -h,  --help            Show this help message and exit
  -c,  --clean           Clean the build directory
  -ko, --kernel-only     Only compile the kernel
  -uo, --uboot-only      Only compile u-boot
  -ro, --rootfs-only     Only build the root filesystem
  -l,  --launchpad       Use kernel and u-boot from Launchpad repository
  -v,  --verbose         Increase verbosity of the bash script
HEREDOC
}

#######################################
# Helper function to load suite, flavor, or board
# configurations and handle "help".
# Globals:
#   None
# Arguments:
#   1) config_type: (suite|flavor|board)
#   2) config_value: e.g. jammy, server, orangepi-5
#######################################
load_config() {
    local config_type="$1"
    local config_value="$2"
    local config_path=""

    case "$config_type" in
        suite)  config_path="config/suites"  ;;
        flavor) config_path="config/flavors" ;;
        board)  config_path="config/boards"  ;;
        *)      echo "Internal Error: Unknown config_type $config_type" >&2; exit 1 ;;
    esac

    if [[ "$config_value" == "help" ]]; then
        for file in "$config_path"/*; do
            basename "${file%.sh}"
        done
        exit 0
    fi

    if [[ -n "$config_value" ]]; then
        while :; do
            for file in "$config_path"/*; do
                if [[ "$config_value" == "$(basename "${file%.sh}")" ]]; then
                    # shellcheck source=/dev/null
                    source "$file"
                    break 2
                fi
            done
            echo "Error: \"${config_value}\" is an unsupported ${config_type}"
            exit 1
        done
    fi
}

#######################################
# Check for root privileges.
#######################################
if [[ "$(id -u)" -ne 0 ]]; then
    echo "Error: Please run as root"
    exit 1
fi

#######################################
# Parse command line arguments.
#######################################
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -b=*|--board=*)
            export BOARD="${1#*=}"
            shift
            ;;
        -b|--board)
            export BOARD="$2"
            if ! shift 2; then
                echo "Invalid shift argument"
                exit 1
            fi
            ;;
        -s=*|--suite=*)
            export SUITE="${1#*=}"
            shift
            ;;
        -s|--suite)
            export SUITE="$2"
            shift 2
            ;;
        -f=*|--flavor=*)
            export FLAVOR="${1#*=}"
            shift
            ;;
        -f|--flavor)
            export FLAVOR="$2"
            shift 2
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

#######################################
# Load suite, flavor, and board configs
# (handles the "help" subcommands)
#######################################
load_config "suite"  "${SUITE}"
load_config "flavor" "${FLAVOR}"
load_config "board"  "${BOARD}"

#######################################
# Clean build directory, if requested.
#######################################
if [[ "${CLEAN}" == "Y" ]]; then
    if [[ -d build/rootfs ]]; then
        umount -lf build/rootfs/dev/pts 2>/dev/null || true
        umount -lf build/rootfs/* 2>/dev/null || true
    fi
    rm -rf build
fi

#######################################
# Redirect all script output to a log file.
#######################################
mkdir -p build/logs
exec > >(tee "build/logs/build-$(date +"%Y%m%d%H%M%S").log") 2>&1

#######################################
# Early-exit scenarios for partial builds.
#######################################
if [[ "${KERNEL_ONLY}" == "Y" ]]; then
    if [[ -z "${SUITE}" ]]; then
        usage
        exit 1
    fi
    ./scripts/build-kernel.sh
    exit 0
fi

if [[ "${ROOTFS_ONLY}" == "Y" ]]; then
    if [[ -z "${SUITE}" || -z "${FLAVOR}" ]]; then
        usage
        exit 1
    fi
    ./scripts/build-rootfs.sh
    exit 0
fi

if [[ "${UBOOT_ONLY}" == "Y" ]]; then
    if [[ -z "${BOARD}" ]]; then
        usage
        exit 1
    fi
    ./scripts/build-u-boot.sh
    exit 0
fi

#######################################
# Require board, suite, and flavor for full build.
#######################################
if [[ -z "${BOARD}" || -z "${SUITE}" || -z "${FLAVOR}" ]]; then
    usage
    exit 1
fi

#######################################
# Build Kernel if not found (and if not using Launchpad).
#######################################
if [[ "${LAUNCHPAD}" != "Y" ]]; then
    # Check if we already have kernel .deb files
    if [[ ! -e "$(find build/linux-image-*.deb 2>/dev/null | sort | tail -n1)" ||
          ! -e "$(find build/linux-headers-*.deb 2>/dev/null | sort | tail -n1)" ]]; then
        ./scripts/build-kernel.sh
    fi
fi

#######################################
# Build U-Boot if not found (and if not using Launchpad).
#######################################
if [[ "${LAUNCHPAD}" != "Y" ]]; then
    # Check if we already have the correct U-Boot .deb
    if [[ ! -e "$(find build/u-boot-${BOARD}_*.deb 2>/dev/null | sort | tail -n1)" ]]; then
        ./scripts/build-u-boot.sh
    fi
fi

#######################################
# Create the root filesystem.
#######################################
./scripts/build-rootfs.sh

#######################################
# Create the disk image.
#######################################
./scripts/config-image.sh

exit 0
