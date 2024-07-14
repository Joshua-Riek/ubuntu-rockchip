## Overview

[![Latest GitHub Release](https://img.shields.io/github/release/Joshua-Riek/ubuntu-rockchip.svg?label=Latest%20Release)](https://github.com/Joshua-Riek/ubuntu-rockchip/releases/latest)
[![Total GitHub Downloads](https://img.shields.io/github/downloads/Joshua-Riek/ubuntu-rockchip/total.svg?&color=E95420&label=Total%20Downloads)](https://github.com/Joshua-Riek/ubuntu-rockchip/releases)
[![Nightly GitHub Build](https://github.com/Joshua-Riek/ubuntu-rockchip/actions/workflows/nightly.yml/badge.svg)](https://github.com/Joshua-Riek/ubuntu-rockchip/actions/workflows/nightly.yml)

Ubuntu Rockchip is a community project porting Ubuntu to Rockchip hardware with the goal of providing a stable and fully functional environment.

## Highlights

* Available for both Ubuntu 22.04 LTS (with Rockchip Linux 5.10) and Ubuntu 24.04 LTS (with Rockchip Linux 6.1)
* Package management via apt using the official Ubuntu repositories
* Receive all updates and changes through apt
* Desktop first-run wizard for user setup and configuration
* 3D hardware acceleration support via panfork
* Fully working GNOME desktop using wayland
* Chromium browser with smooth 4k youtube video playback
* MPV video player capable of smooth 4k video playback

## Installation

Make sure you use a good, reliable, and fast SD card. For example, suppose you encounter boot or stability troubles. Most of the time, this is due to either an insufficient power supply or related to your SD card (bad card, bad card reader, something went wrong when burning the image, or the card is too slow).

Download the Ubuntu image for your specific board from the latest [release](https://github.com/Joshua-Riek/ubuntu-rockchip/releases) on GitHub or from the dedicated download [website](https://joshua-riek.github.io/ubuntu-rockchip-download/). Then write the xz compressed image (no previous unpacking necessary) to your SD card using [USBimager](https://bztsrc.gitlab.io/usbimager/) or [balenaEtcher](https://www.balena.io/etcher) since, unlike other tools, these can validate burning results, saving you from corrupted SD card contents.

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

---
> Ubuntu is a trademark of Canonical Ltd. Rockchip is a trademark of Fuzhou Rockchip Electronics Co., Ltd. The Ubuntu Rockchip project is not affiliated with Canonical Ltd or Fuzhou Rockchip Electronics Co., Ltd. All other product names, logos, and brands are property of their respective owners. The Ubuntu name is owned by [Canonical Limited](https://ubuntu.com/).
