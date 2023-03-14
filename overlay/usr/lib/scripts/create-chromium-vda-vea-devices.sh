#!/bin/bash

{
    echo "type=dec"
    echo "codecs=VP8:VP9:H.264:H.265:AV1"
    echo "max-width=7680"
    echo "max-height=4320"
} > /dev/video-dec0
chown root:video /dev/video-dec0
chmod 0660 /dev/video-dec0
echo enc > /dev/video-enc0
chown root:video /dev/video-enc0
chmod 0660 /dev/video-enc0
