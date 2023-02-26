# Use ubuntu base
FROM ubuntu:22.04 

# Prevent dpkg interactive dialogues
ENV DEBIAN_FRONTEND=noninteractive

# Install required packages
RUN apt-get -y update && apt-get -y upgrade && \
apt-get install -y build-essential gcc-aarch64-linux-gnu bison \
qemu-user-static qemu-system-arm qemu-efi u-boot-tools binfmt-support \
debootstrap flex libssl-dev bc rsync kmod cpio xz-utils fakeroot parted \
udev dosfstools uuid-runtime git-lfs device-tree-compiler python2 python3 \
python-is-python3

# Set the working directory
WORKDIR /opt
