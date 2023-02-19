#!/bin/bash

# Hack for GDM to restart on first HDMI hotplug
if systemctl is-active --quiet gdm && grep -Fxq "WaylandEnable=true" /etc/gdm3/custom.conf; then
    if [ ! -f /tmp/gdm-wayland-session-hack.lock ]; then
        touch /tmp/gdm-wayland-session-hack.lock && sleep 2 && pidof gdm-x-session > /dev/null && systemctl restart gdm
    fi
fi
