# Use ubuntu base
FROM ubuntu:22.04 

# Prevent dpkg interactive dialogues
ENV DEBIAN_FRONTEND=noninteractive

# Install required packages
RUN apt-get update && apt-get install -y \
    bc \
    binfmt-support \
    bison \
    build-essential \
    cpio \
    debootstrap \
    debhelper \
    device-tree-compiler \
    dosfstools \
    fakeroot \
    fdisk \
    flex \
    gcc-aarch64-linux-gnu \
    git-lfs \
    kmod \
    libssl-dev \
    parted \
    python-is-python3 \
    python2 \
    python3 \
    qemu-efi \
    qemu-system-arm \
    qemu-user-static \
    rsync \
    u-boot-tools \
    udev \
    uuid-runtime \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Set the working directory
WORKDIR /opt
