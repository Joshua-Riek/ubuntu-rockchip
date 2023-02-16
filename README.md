## Overview

This repository provides a pre-installed Ubuntu 20.04 and 22.04 desktop/server image for the Orange Pi 5, offering a default Ubuntu experience. With this port, you can experience the power and stability of Ubuntu on your Orange Pi 5, making it an excellent choice for a wide range of projects and applications. If you find problems, please report them in the issues section, and I will be happy to assist!

<img src="https://th.bing.com/th/id/R.a1de27bd2ebe148e76a874c99ad788c5?rik=Nk7xAorX4wMWfA&riu=http%3a%2f%2fwww.orangepi.cn%2fimg%2fpi-5-banner-img.png&ehk=iprwYnSrqqCCG8u9JLNVxxnIy9rza138h65C3rXhC4c%3d&risl=&pid=ImgRaw&r=0" width="400"/>

## Highlights

* Package management via apt using the official Ubuntu repositories
* Uses the 5.10.110 Linux kernel built with arm64 flags
* Boot from an SD Card or NVMe SSD
* 3D video hardware acceleration support via panfork
* Fully working GNOME desktop using wayland
* Chromium browser with smooth 4k video playback
* Working Bluetooth and WiFi from the Orange Pi5 PCIe WiFi 6.0 module (AP6275P)
* On board Microphone
* Audio over HDMI

## Prepare an SD Card

Make sure you use a good, reliable, and fast SD card. For example, suppose you encounter boot or stability troubles. Most of the time, this is due to either an insufficient power supply or related to your SD card (bad card, bad card reader, something went wrong when burning the image, or the card is too slow). 

Download your preferred version of Ubuntu from the latest [release](https://github.com/Joshua-Riek/ubuntu-orange-pi5/releases) on GitHub. Then write the xz compressed image to your SD card using [balenaEtcher](https://www.balena.io/etcher) since, unlike other tools, it can validate burning results, saving you from corrupted SD card contents.

## Boot the System

Insert your SD card into the slot on the board and power on the device. The first boot may take up to two minutes, so please be patient.

## Login Information

You will be able to login through HDMI or a serial console connection.

There are two predefined users: `ubuntu` and `root`. The password for each is `root`. 

```
Ubuntu 22.04.1 TLS orange-pi5 tty1

orange-pi5 login: root
Password: root
```

## Build Requirements

To to set up the build environment, please use a Ubuntu 20.04 machine, then install the below packages:

```
sudo apt-get install -y build-essential gcc-aarch64-linux-gnu bison \
qemu-user-static qemu-system-arm qemu-efi u-boot-tools binfmt-support \
debootstrap flex libssl-dev bc rsync kmod cpio xz-utils fakeroot parted \
udev dosfstools uuid-runtime git-lfs python
```

## Building

To checkout the source and build:

```
git clone https://github.com/Joshua-Riek/ubuntu-orange-pi5.git
cd ubuntu-orange-pi5
sudo ./build.sh jammy
```

## Known Limitations and Bugs

1. A number of packages are installed and held to enable hardware acceleration. So please don't remove them and re-install with apt-get.

2. Kernel warnings plague dmesg in the Ubuntu 22.04 release.