#!/bin/bash

rfkill unblock all
/usr/bin/hciattach -s 1500000 /dev/ttyS1 any 1500000 flow nosleep
sleep 2

while read -r; do
    echo "bt_test > $REPLY"
    case "$(tr -d '\r' <<< "$REPLY")" in
        "hci recv thread ready (nil)")
            echo "Device reset successfully."
            exit 0
            ;;
        "dev_open fail")
            echo "Unable to open /dev/ttyS1. Is Bluetooth already up?"
            exit 1
            ;;
    esac
done < <(timeout 1 bt_test -s uart 1500000 "/dev/ttyS1")

echo "Command timed out."
exit 2
