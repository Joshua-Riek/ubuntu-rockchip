#!/bin/bash
### BEGIN INIT INFO
# Provides: friendlyelec
# Required-Start:
# Required-Stop:
# Default-Start: 2 3 4 5 S
# Default-Stop:
# Short-Description: Initialize onboard network LEDs for FriendlyElec NanoPi R6
# Description:
### END INIT INFO

model=$(tr -d '\0' < /proc/device-tree/model)
if [ "${model}" == "FriendlyElec NanoPi R6C" ] || [ "${model}" == "FriendlyElec NanoPi R6S" ]; then
    if [ -d /sys/class/leds/wan_led ]; then
        echo netdev > /sys/class/leds/wan_led/trigger
        echo eth0 > /sys/class/leds/wan_led/device_name
        echo 1 > /sys/class/leds/wan_led/link
    fi

    if [ -d /sys/class/leds/lan1_led ]; then
        echo netdev > /sys/class/leds/lan1_led/trigger
        echo enP3p49s0 > /sys/class/leds/lan1_led/device_name
        echo 1 > /sys/class/leds/lan1_led/link
    fi

    if [ -d /sys/class/leds/lan2_led ]; then
        echo netdev > /sys/class/leds/lan2_led/trigger
        echo enP4p65s0 > /sys/class/leds/lan2_led/device_name
        echo 1 > /sys/class/leds/lan2_led/link
    fi
fi
