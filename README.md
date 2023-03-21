## Overview

This repository provides a pre-installed Ubuntu 22.04 desktop/server image for the [Orange Pi 5](http://www.orangepi.org/html/hardWare/computerAndMicrocontrollers/details/Orange-Pi-5.html), offering a default Ubuntu experience. With this port, you can experience the power and stability of Ubuntu on your Orange Pi 5, making it an excellent choice for a wide range of projects and applications.

This device is still new and undergoing continuous development. As a result, you may encounter bugs or missing features. I'll do my best to update this project with the most recent changes and fixes. If you find problems, please report them in the issues section, and I will be happy to assist!

<img src="https://i.imgur.com/eQnRu1t.png" width="400">

## Highlights

* Package management via apt using the official Ubuntu repositories
* Uses the 5.10.110 Linux kernel
* Boot from [SD Card, USB, NVMe or SATA SSD](#flash-bootloader-to-spi)
* 3D video hardware acceleration support via panfork
* Fully working GNOME desktop using wayland
* Chromium browser with smooth 4k youtube video playback
* MPV video player capable of smooth 4k video playback
* Gstreamer can be used as an alternative 4k video player from the command line
* Working Bluetooth and WiFi from the [Orange Pi5 PCIe WiFi 6.0 module (AP6275P)](#pcie-wifi-60-module-ap6275p)
* RTC synchronization on startup and shutdown
* On board Microphone
* Audio over HDMI

## Prepare an SD Card

Make sure you use a good, reliable, and fast SD card. For example, suppose you encounter boot or stability troubles. Most of the time, this is due to either an insufficient power supply or related to your SD card (bad card, bad card reader, something went wrong when burning the image, or the card is too slow).

Download your preferred version of Ubuntu from the latest [release](https://github.com/Joshua-Riek/ubuntu-orange-pi5/releases) on GitHub. Then write the xz compressed image to your SD card using [balenaEtcher](https://www.balena.io/etcher) since, unlike other tools, it can validate burning results, saving you from corrupted SD card contents.

## Boot the System

Insert your SD card into the slot on the board and power on the device. The first boot may take up to two minutes, so please be patient.

## Login Information

You will be able to login through HDMI or a serial console connection.

There are two predefined users: `ubuntu` and `root`. The password for each is `ubuntu`.

```
Ubuntu 22.04.2 TLS ubuntu tty1

ubuntu login: ubuntu
Password: ubuntu
```

## Flash Bootloader to SPI

Booting directly from a USB, NVMe or SATA SSD requires flashing U-Boot to the SPI.

For a **NVMe** SSD, please use the below comand:
```
sudo dd if=/usr/share/orangepi/rkspi_loader.img of=/dev/mtdblock0 conv=notrunc
```

For a **SATA** SSD, please use the below comands:
```
sudo dd if=/usr/share/orangepi/rkspi_loader_sata.img of=/dev/mtdblock0 conv=notrunc 
echo "overlays=ssd-sata" | sudo tee /boot/firmware/overlays.txt
```

## PCIe WiFi 6.0 module (AP6275P)

To enable, please use the below command and reboot your system:
```
echo "overlays=wifi-ap6275p" | sudo tee /boot/firmware/overlays.txt
```

## Build Requirements

To to set up the build environment, please use a Ubuntu 22.04 machine, then install the below packages:

```
sudo apt-get install -y build-essential gcc-aarch64-linux-gnu bison \
qemu-user-static qemu-system-arm qemu-efi u-boot-tools binfmt-support \
debootstrap flex libssl-dev bc rsync kmod cpio xz-utils fakeroot parted \
udev dosfstools uuid-runtime git-lfs device-tree-compiler python2 python3 \
python-is-python3 fdisk
```

## Building

To checkout the source and build:

```
git clone https://github.com/Joshua-Riek/ubuntu-orange-pi5.git
cd ubuntu-orange-pi5
sudo ./build.sh
```

## Known Limitations

1. A number of packages are installed and held to enable hardware acceleration. So please don't remove them and re-install with apt-get.
2. The Vulkan graphics API is not supported due to driver limitations.
3. HDR video playback currently does not work.
