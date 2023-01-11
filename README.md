## Overview

This is a collection of scripts that are used to build a Ubuntu 20.04 preinstalled desktop/server image for the Orange Pi5.

![Raspberry Pi 4](https://th.bing.com/th/id/R.a1de27bd2ebe148e76a874c99ad788c5?rik=Nk7xAorX4wMWfA&riu=http%3a%2f%2fwww.orangepi.cn%2fimg%2fpi-5-banner-img.png&ehk=iprwYnSrqqCCG8u9JLNVxxnIy9rza138h65C3rXhC4c%3d&risl=&pid=ImgRaw&r=0)

## Recommended Hardware

To setup the build environment for the Ubuntu 20.04 image creation, a Linux host with the following configuration is recommended. A host machine with adequate processing power and disk space is ideal as the build process can be severial gigabytes in size and can take alot of time.

* Intel Core i7 CPU (>= 8 cores)
* Strong internet connection
* 30 GB free disk space
* 16 GB RAM

## Requirements

Please install the below packages on your host machine:

```
sudo apt-get install -y build-essential gcc-aarch64-linux-gnu bison \
qemu-user-static qemu-system-arm qemu-efi u-boot-tools binfmt-support \
debootstrap flex libssl-dev bc rsync kmod cpio xz-utils fakeroot parted \
udev dosfstools uuid-runtime grub-pc
```

## Building

To checkout the source and build:

```
git clone https://github.com/Joshua-Riek/ubuntu-orange-pi5.git
cd ubuntu-orange-pi5
sudo ./build.sh
```

## Virtual Machine

To run the Ubuntu 20.04 preinstalled image in a virtual machine:

```
sudo ./qemu.sh images/ubuntu-20.04-preinstalled-server-arm64-orange-pi5.img.xz
```

## Login

There are two predefined users on the system: `ubuntu` and `root`. The password for each is `root`. 

```
Ubuntu 20.04.5 TLS orange-pi tty1

orange-pi login: root
Password: root
```

## Flash Removable Media

To flash the Ubuntu 20.04 preinstalled image to removable media:

```
xz -dc images/ubuntu-20.04-preinstalled-server-arm64-orange-pi5.img.xz | sudo dd of=/dev/sdX bs=4k
```

> This assumes that the removable media is added as /dev/sdX and all it’s partitions are unmounted.
