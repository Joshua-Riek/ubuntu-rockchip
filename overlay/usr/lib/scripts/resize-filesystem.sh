#!/bin/bash

# Get the root partition
partition_root="$(findmnt -n -o SOURCE /)"
partition_name="$(lsblk -no name "${partition_root}")"
partition_pkname="$(lsblk -no pkname "${partition_root}")"
partition_num="$(echo "${partition_name}" | grep -Eo '[0-9]+$')"

# Get size of disk and root partition
partition_start="$(cat /sys/block/${partition_pkname}/${partition_name}/start)"
partition_end="$(( partition_start + $(cat /sys/block/${partition_pkname}/${partition_name}/size)))"
partition_newend="$(( $(cat /sys/block/${partition_pkname}/size) - 8))"

# Resize partition and filesystem
if [ "${partition_newend}" -gt "${partition_end}" ]; then
    sgdisk -e "/dev/${partition_pkname}"
    sgdisk -d "${partition_num}" "/dev/${partition_pkname}"
    sgdisk -N "${partition_num}" "/dev/${partition_pkname}"
    partprobe "/dev/${partition_pkname}"
    resize2fs "/dev/${partition_name}"

    sync --file-system
    sync
fi

systemctl disable resize-filesystem
