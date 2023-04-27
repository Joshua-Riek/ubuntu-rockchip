#!/bin/bash

bt_status=$(cat /proc/device-tree/wireless-bluetooth/status)
if [[ ${bt_status} == "okay" ]]; then
    rfkill unblock all
    brcm_patchram_plus --enable_hci --no2bytes --use_baudrate_for_download --tosleep 200000 \
        --baudrate 1500000 --patchram /lib/firmware/ap6275p/BCM4362A2.hcd /dev/ttyS9 &
fi
