#!/bin/bash
### BEGIN INIT INFO
# Provides: enable-usb2.sh
# Required-Start:
# Required-Stop:
# Default-Start: 2 3 4 5 S
# Default-Stop:
# Short-Description: Enable the USB 2.0 port
# Description:
### END INIT INFO

# Enable the USB 2.0 port by setting host mode
echo "host" > /sys/kernel/debug/usb/fc000000.usb/mode
