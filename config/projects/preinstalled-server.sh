# shellcheck shell=bash

package_list=(
    i2c-tools u-boot-tools mmc-utils flash-kernel wpasupplicant linux-firmware psmisc wireless-regdb
    cloud-init landscape-common cloud-initramfs-growroot
)

package_removal_list=(
    cryptsetup needrestart
)

function build_rootfs_hook__preinstalled-server() {
    local task
    local package
    declare -g chroot_dir

    # Query list of default ubuntu packages
    for task in minimal standard server; do
        for package in $(chroot "${chroot_dir}" apt-cache dumpavail | grep-dctrl -nsPackage \( -XFArchitecture arm64 -o -XFArchitecture all \) -a -wFTask "${task}"); do
            package_list+=("${package}")
        done
    done

    # Install packages
    chroot "${chroot_dir}" apt-get install -y "${package_list[@]}"

    # Remove packages
    chroot "${chroot_dir}" apt-get purge -y "${package_removal_list[@]}"

    # Hostname
    echo "ubuntu" > "${chroot_dir}/etc/hostname"

    # DNS
    echo "nameserver 8.8.8.8" > "${chroot_dir}/etc/resolv.conf"

    # Create lxd group for default user
    chroot "${chroot_dir}" addgroup --system --quiet lxd

    # Set term for serial tty
    mkdir -p "${chroot_dir}/lib/systemd/system/serial-getty@.service.d/"
    echo "[Service]" > "${chroot_dir}/usr/lib/systemd/system/serial-getty@.service.d/10-term.conf"
    echo "Environment=TERM=linux" >> "${chroot_dir}/usr/lib/systemd/system/serial-getty@.service.d/10-term.conf"

    # Use gzip compression for the initrd
    mkdir -p "${chroot_dir}/etc/initramfs-tools/conf.d/"
    echo "COMPRESS=gzip" > "${chroot_dir}/etc/initramfs-tools/conf.d/compression.conf"

    # Disable apport bug reporting
    sed -i 's/enabled=1/enabled=0/g' "${chroot_dir}/etc/default/apport"

    # Remove release upgrade motd
    rm -f "${chroot_dir}/var/lib/ubuntu-release-upgrader/release-upgrade-available"
    sed -i 's/Prompt=.*/Prompt=never/g' "${chroot_dir}/etc/update-manager/release-upgrades"

    # Let systemd create machine id on first boot
    rm -f "${chroot_dir}/var/lib/dbus/machine-id"
    true > "${chroot_dir}/etc/machine-id"

    # Flash kernel override
    (
        echo "Machine: *"
        echo "Kernel-Flavors: any"
        echo "Method: pi"
        echo "Boot-Kernel-Path: /boot/firmware/vmlinuz"
        echo "Boot-Initrd-Path: /boot/firmware/initrd.img"
    ) > "${chroot_dir}/etc/flash-kernel/db"

    # Create swapfile on boot
    mkdir -p "${chroot_dir}/usr/lib/systemd/system/swap.target.wants/"
    (
        echo "[Unit]"
        echo "Description=Create the default swapfile"
        echo "DefaultDependencies=no"
        echo "Requires=local-fs.target"
        echo "After=local-fs.target"
        echo "Before=swapfile.swap"
        echo "ConditionPathExists=!/swapfile"
        echo ""
        echo "[Service]"
        echo "Type=oneshot"
        echo "ExecStartPre=fallocate -l 1GiB /swapfile"
        echo "ExecStartPre=chmod 600 /swapfile"
        echo "ExecStart=mkswap /swapfile"
        echo ""
        echo "[Install]"
        echo "WantedBy=swap.target"
    ) > "${chroot_dir}/usr/lib/systemd/system/mkswap.service"
    chroot "${chroot_dir}" /bin/bash -c "ln -s ../mkswap.service /usr/lib/systemd/system/swap.target.wants/"

    # Swapfile service
    (
        echo "[Unit]"
        echo "Description=The default swapfile"
        echo ""
        echo "[Swap]"
        echo "What=/swapfile"
    ) > "${chroot_dir}/usr/lib/systemd/system/swapfile.swap"
    chroot "${chroot_dir}" /bin/bash -c "ln -s ../swapfile.swap /usr/lib/systemd/system/swap.target.wants/"

    # Hosts file
    (
        echo "127.0.0.1 localhost"
        echo ""
        echo "# The following lines are desirable for IPv6 capable hosts"
        echo "::1 ip6-localhost ip6-loopback"
        echo "fe00::0 ip6-localnet"
        echo "ff00::0 ip6-mcastprefix"
        echo "ff02::1 ip6-allnodes"
        echo "ff02::2 ip6-allrouters"
        echo "ff02::3 ip6-allhosts"
    ) > "${chroot_dir}/etc/hosts"

    # Cloud init no cloud config
    (
        echo "# configure cloud-init for NoCloud"
        echo "datasource_list: [ NoCloud, None ]"
        echo "datasource:"
        echo "  NoCloud:"
        echo "    fs_label: system-boot"
    ) > "${chroot_dir}/etc/cloud/cloud.cfg.d/99-fake_cloud.cfg"

    # HACK: lower 120 second timeout to 10 seconds
    mkdir -p "${chroot_dir}/etc/systemd/system/systemd-networkd-wait-online.service.d/"
    (
        echo "[Service]"
        echo "ExecStart="
        echo "ExecStart=/lib/systemd/systemd-networkd-wait-online --timeout=10"
    ) > "${chroot_dir}/etc/systemd/system/systemd-networkd-wait-online.service.d/override.conf"

    return 0
}
