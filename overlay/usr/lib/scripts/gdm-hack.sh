#!/bin/bash

# Hack for GDM to restart on first HDMI hotplug
if systemctl is-active --quiet gdm && grep -Fxq "WaylandEnable=true" /etc/gdm3/custom.conf; then
    if [ ! -f /tmp/gdm-wayland-session-hack.lock ]; then
        pidof gdm-x-session > /dev/null && systemctl restart gdm && touch /tmp/gdm-wayland-session-hack.lock
    fi
fi
