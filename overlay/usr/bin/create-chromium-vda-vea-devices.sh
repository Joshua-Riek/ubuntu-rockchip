#!/bin/bash
echo dec > /dev/video-dec0
chown root:video /dev/video-dec0
chmod 0660 /dev/video-dec0
echo enc > /dev/video-enc0
chown root:video /dev/video-enc0
chmod 0660 /dev/video-enc0
