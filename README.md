## Overview

[![Latest GitHub Release](https://img.shields.io/github/release/Joshua-Riek/ubuntu-rockchip.svg?label=Latest%20Release)](https://github.com/Joshua-Riek/ubuntu-rockchip/releases/latest)
[![Total Github Downloads](https://img.shields.io/github/downloads/Joshua-Riek/ubuntu-rockchip/total.svg?&color=E95420&label=Total%20Downloads)](https://github.com/Joshua-Riek/ubuntu-rockchip/releases)

This project aims to provide a default Ubuntu experience for Rockchip RK3588 devices. Get started today with an Ubuntu Server or Desktop image for a familiar environment. For additional information about this project or a specific device, please take a look at the documentation available on the [Wiki](https://github.com/Joshua-Riek/ubuntu-rockchip/wiki).

The supported devices are undergoing continuous development. As a result, you may encounter bugs or missing features. I'll do my best to update this project with the most recent changes and fixes. If you find problems, please report them in the issues or discussions section.

## Highlights

* Package management via apt using the official Ubuntu repositories
* Receive kernel, firmware, and bootloader updates through apt
* Desktop first-run wizard for user setup and configuration
* 3D hardware acceleration support via panfork
* Fully working GNOME desktop using wayland
* Chromium browser with smooth 4k youtube video playback
* MPV video player capable of smooth 4k video playback
* Gstreamer can be used as an alternative 4k video player from the command line
* Ubuntu 22.04 LTS with Rockchip Linux 5.10
* Ubuntu 24.04 LTS with Rockchip Linux 6.1

## Supported Boards

* [ArmSoM-Sige7](https://docs.armsom.org/docs/category/sige7-1)
* [ArmSoM-w3](http://wiki.armsom.org/index.php/ArmSoM-w3)
* [Indiedroid Nova](https://indiedroid.us)
* [ROC-RK3588S-PC](https://en.t-firefly.com/product/industry/rocrk3588spc)
* [LubanCat 4](https://doc.embedfire.com/products/link/zh/latest/linux/ebf_lubancat.html)
* [Mixtile Blade 3](https://www.mixtile.com/blade-3)
* [Mixtile Core 3588E](https://www.mixtile.com/core-3588e/)
* [NanoPC T6](https://wiki.friendlyelec.com/wiki/index.php/NanoPC-T6)
* [NanoPi R6C](https://wiki.friendlyelec.com/wiki/index.php/NanoPi_R6C)
* [NanoPi R6S](https://wiki.friendlyelec.com/wiki/index.php/NanoPi_R6S)
* [Orange Pi 5 Plus](http://www.orangepi.org/html/hardWare/computerAndMicrocontrollers/details/Orange-Pi-5-plus.html)
* [Orange Pi 5 Pro](http://www.orangepi.org/html/hardWare/computerAndMicrocontrollers/details/Orange-Pi-5-Pro.html)
* [Orange Pi 5B](http://www.orangepi.org/html/hardWare/computerAndMicrocontrollers/details/Orange-Pi-5B.html)
* [Orange Pi 5](http://www.orangepi.org/html/hardWare/computerAndMicrocontrollers/details/Orange-Pi-5.html)
* [Orange Pi 3B](http://www.orangepi.org/html/hardWare/computerAndMicrocontrollers/details/Orange-Pi-3B.html)
* [Radxa CM5 IO](https://radxa.com/products/compute-module/cm5)
* [Radxa NX5 IO](https://radxa.com/products/compute-module/nx5)
* [Radxa ROCK 5 ITX](https://radxa.com/products)
* [Radxa ROCK 5A](https://radxa.com/products/rock5/5a/)
* [Radxa ROCK 5B](https://radxa.com/products/rock5/5b/)
* [Radxa Zero 3](https://radxa.com/products/zeros/zero3w/)
* [Turing RK1](https://turingpi.com/product/turing-rk1)

## Installation

Make sure you use a good, reliable, and fast SD card. For example, suppose you encounter boot or stability troubles. Most of the time, this is due to either an insufficient power supply or related to your SD card (bad card, bad card reader, something went wrong when burning the image, or the card is too slow).

Download the Ubuntu image for your specific board from the latest [release](https://github.com/Joshua-Riek/ubuntu-rockchip/releases) on GitHub. Then write the xz compressed image to your SD card using [balenaEtcher](https://www.balena.io/etcher) since, unlike other tools, it can validate burning results, saving you from corrupted SD card contents.

## Boot the System

Insert your SD card into the slot on the board and power on the device. The first boot may take up to two minutes, so please be patient.

## Login Information

For the server image you will be able to login through HDMI, a serial console connection, or SSH. The predefined user is `ubuntu` and the password is `ubuntu`.

For the desktop image you must connect through HDMI and follow the setup-wizard.

## Support the Project

There are a few things you can do to support the project:

* Star the repository and follow me on GitHub
* Share and upvote on sites like Twitter, Reddit, and YouTube
* Report any bugs, glitches, or errors that you find (some bugs I may not be able to fix)
* Sponsor me on GitHub; any contribution will be greatly appreciated

These things motivate me to continue development and provide validation that my work is appreciated. Thanks in advance!
