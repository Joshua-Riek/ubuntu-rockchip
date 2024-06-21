## Overview

[![Latest GitHub Release](https://img.shields.io/github/release/Joshua-Riek/ubuntu-rockchip.svg?label=Latest%20Release)](https://github.com/Joshua-Riek/ubuntu-rockchip/releases/latest)
[![Total Github Downloads](https://img.shields.io/github/downloads/Joshua-Riek/ubuntu-rockchip/total.svg?&color=E95420&label=Total%20Downloads)](https://github.com/Joshua-Riek/ubuntu-rockchip/releases)

This project aims to provide a default Ubuntu experience for Rockchip RK3588 devices. Get started today with an Ubuntu Server or Desktop image for a familiar environment. For additional information about this project or a specific device, please take a look at the documentation available on the [Wiki](https://github.com/Joshua-Riek/ubuntu-rockchip/wiki).

The supported devices are undergoing continuous development. As a result, you may encounter bugs or missing features. I'll do my best to update this project with the most recent changes and fixes. If you find problems, please report them in the issues or discussions section.

## Highlights

* Available for both Ubuntu 22.04 LTS (with Rockchip Linux 5.10) and Ubuntu 24.04 LTS (with Rockchip Linux 6.1)
* Package management via apt using the official Ubuntu repositories
* Receive all updates and changes through through apt
* Desktop first-run wizard for user setup and configuration
* 3D hardware acceleration support via panfork
* Fully working GNOME desktop using wayland
* Chromium browser with smooth 4k youtube video playback
* MPV video player capable of smooth 4k video playback

## Installation

Make sure you use a good, reliable, and fast SD card. For example, suppose you encounter boot or stability troubles. Most of the time, this is due to either an insufficient power supply or related to your SD card (bad card, bad card reader, something went wrong when burning the image, or the card is too slow).

Download the Ubuntu image for your specific board from the latest [release](https://github.com/Joshua-Riek/ubuntu-rockchip/releases) on GitHub or from the dedicated download [website](https://joshua-riek.github.io/ubuntu-rockchip-download/). Then write the xz compressed image to your SD card using [balenaEtcher](https://www.balena.io/etcher) since, unlike other tools, it can validate burning results, saving you from corrupted SD card contents.

## Boot the System

Insert your SD card into the slot on the board and power on the device. The first boot may take up to two minutes, so please be patient.

## Login Information

For Ubuntu Server you will be able to login through HDMI, a serial console connection, or SSH. The predefined user is `ubuntu` and the password is `ubuntu`.

For Ubuntu Desktop you must connect through HDMI and follow the setup-wizard.

## Support the Project

There are a few things you can do to support the project:

* Star the repository and follow me on GitHub
* Share and upvote on sites like Twitter, Reddit, and YouTube
* Report any bugs, glitches, or errors that you find (some bugs I may not be able to fix)
* Sponsor me on GitHub; any contribution will be greatly appreciated

These things motivate me to continue development and provide validation that my work is appreciated. Thanks in advance!
