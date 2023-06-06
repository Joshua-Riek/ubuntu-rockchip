## Overview

This project aims to provide a default Ubuntu 22.04 experience for Rockchip RK3588 devices. Get started today with an Ubuntu Server or Desktop image for a familiar environment. For additional information about this project or a specific device, please take a look at the documentation available on the [Wiki](https://github.com/Joshua-Riek/ubuntu-rockchip/wiki).

The supported devices are undergoing continuous development. As a result, you may encounter bugs or missing features. I'll do my best to update this project with the most recent changes and fixes. If you find problems, please report them in the issues or discussions section.

## Highlights

* Package management via apt using the official Ubuntu repositories
* Receive kernel, firmware, and bootloader updates through apt
* Desktop first-run wizard for user setup and configuration
* 3D video hardware acceleration support via panfork
* Fully working GNOME desktop using wayland
* Chromium browser with smooth 4k youtube video playback
* MPV video player capable of smooth 4k video playback
* Gstreamer can be used as an alternative 4k video player from the command line
* 5.10.160 Linux kernel

## Supported Boards

* Orange Pi 5
* Orange Pi 5B
* Orange Pi 5 Plus
* NanoPi R6S
* NanoPi R6C
* NanoPC-T6 (WIP hardware required)
* Rock 5B
* Rock 5A
* Indiedroid Nova

## Installation

Make sure you use a good, reliable, and fast SD card. For example, suppose you encounter boot or stability troubles. Most of the time, this is due to either an insufficient power supply or related to your SD card (bad card, bad card reader, something went wrong when burning the image, or the card is too slow).

Download the Ubuntu image for your specific board from the latest [release](https://github.com/Joshua-Riek/ubuntu-rockchip/releases) on GitHub. Then write the xz compressed image to your SD card using [balenaEtcher](https://www.balena.io/etcher) since, unlike other tools, it can validate burning results, saving you from corrupted SD card contents.

## Boot the System

Insert your SD card into the slot on the board and power on the device. The first boot may take up to two minutes, so please be patient.

## Login Information

For the server image you will be able to login through HDMI or a serial console connection. The predefined user is `ubuntu` and the password is `ubuntu`.

For the desktop image you must connect through HDMI and follow the setup-wizard.
