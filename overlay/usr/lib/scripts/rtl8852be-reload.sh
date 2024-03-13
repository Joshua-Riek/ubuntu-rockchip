#!/bin/bash

if modinfo rtw89_8852be >/dev/null 2>/dev/null && ! modprobe -n --first-time rtw89_8852be 2>/dev/null; then
    modprobe -r rtw89_8852be && modprobe -i rtw89_8852be
elif modinfo 8852be >/dev/null 2>/dev/null && ! modprobe -n --first-time 8852be 2>/dev/null; then
    modprobe -r 8852be && modprobe -i 8852be
fi
