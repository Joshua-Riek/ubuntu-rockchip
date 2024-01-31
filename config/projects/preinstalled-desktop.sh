# shellcheck shell=bash

package_list=(
    oem-config-gtk ubiquity-frontend-gtk ubiquity-slideshow-ubuntu language-pack-en-base mpv dbus-x11
    i2c-tools u-boot-tools mmc-utils flash-kernel wpasupplicant linux-firmware psmisc wireless-regdb
    cloud-initramfs-growroot
)

package_removal_list=(
    cryptsetup-initramfs
)

function build_rootfs_hook__preinstalled-desktop() {
    local task
    local package
    declare -g chroot_dir

    # Query list of default ubuntu packages
    for task in minimal standard ubuntu-desktop; do
        for package in $(chroot "${chroot_dir}" apt-cache dumpavail | grep-dctrl -nsPackage \( -XFArchitecture arm64 -o -XFArchitecture all \) -a -wFTask "${task}"); do
            package_list+=("${package}")
        done
    done

    # Install packages
    chroot "${chroot_dir}" apt-get install -y "${package_list[@]}"

    # Remove packages
    chroot "${chroot_dir}" apt-get purge -y "${package_removal_list[@]}"

    chroot "${chroot_dir}" apt-get install -y pulseaudio pavucontrol
    
    # Create files/dirs Ubiquity requires
    mkdir -p "${chroot_dir}/var/log/installer"
    chroot "${chroot_dir}" touch /var/log/installer/debug
    chroot "${chroot_dir}" touch /var/log/syslog
    chroot "${chroot_dir}" chown syslog:adm /var/log/syslog

    # Create the oem user account
    chroot "${chroot_dir}" /usr/sbin/useradd -d /home/oem -G adm,sudo -m -N -u 29999 oem
    chroot "${chroot_dir}" /usr/sbin/oem-config-prepare --quiet
    chroot "${chroot_dir}" touch /var/lib/oem-config/run

    rm -rf "${chroot_dir}/boot/grub/"

    # Hostname
    echo "localhost.localdomain" > "${chroot_dir}/etc/hostname"

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
        echo "127.0.0.1	localhost.localdomain	localhost"
        echo "::1		localhost6.localdomain6	localhost6"
        echo ""
        echo "# The following lines are desirable for IPv6 capable hosts"
        echo "::1     localhost ip6-localhost ip6-loopback"
        echo "fe00::0 ip6-localnet"
        echo "ff02::1 ip6-allnodes"
        echo "ff02::2 ip6-allrouters"
        echo "ff02::3 ip6-allhosts"
    ) > "${chroot_dir}/etc/hosts"

    # Have plymouth use the framebuffer
    mkdir -p "${chroot_dir}/etc/initramfs-tools/conf-hooks.d"
    (
        echo "if which plymouth >/dev/null 2>&1; then"
        echo "    FRAMEBUFFER=y"
        echo "fi"
    ) > "${chroot_dir}/etc/initramfs-tools/conf-hooks.d/plymouth"

    # Mouse lag/stutter (missed frames) in Wayland sessions
    # https://bugs.launchpad.net/ubuntu/+source/mutter/+bug/1982560
    (
        echo "MUTTER_DEBUG_ENABLE_ATOMIC_KMS=0"
        echo "MUTTER_DEBUG_FORCE_KMS_MODE=simple"
        echo "CLUTTER_PAINT=disable-dynamic-max-render-time"
    ) >> "${chroot_dir}/etc/environment"

    # Enable wayland session
    sed -i 's/#WaylandEnable=false/WaylandEnable=true/g' "${chroot_dir}/etc/gdm3/custom.conf"

    # Use NetworkManager by default
    mkdir -p "${chroot_dir}/etc/netplan"
    (
        echo "# Let NetworkManager manage all devices on this system"
        echo "network:"
        echo "  version: 2"
        echo "  renderer: NetworkManager"
    ) > "${chroot_dir}/etc/netplan/01-network-manager-all.yaml"

    # Networking interfaces
    (
        echo "[main]"
        echo "plugins=ifupdown,keyfile"
        echo "dhcp=internal"
        echo ""
        echo "[ifupdown]"
        echo "managed=true"
        echo ""
        echo "[device]"
        echo "wifi.scan-rand-mac-address=no"
    ) > "${chroot_dir}/etc/NetworkManager/NetworkManager.conf"

    # Manage network interfaces
    (
        echo "[keyfile]"
        echo "unmanaged-devices=*,except:type:wifi,except:type:ethernet,except:type:gsm,except:type:cdma"
    ) > "${chroot_dir}/usr/lib/NetworkManager/conf.d/10-globally-managed-devices.conf"

    # Disable random wifi mac address
    (
        echo "[connection]"
        echo "wifi.mac-address-randomization=1"
        echo ""
        echo "[device]"
        echo "wifi.scan-rand-mac-address=no"
    ) > "${chroot_dir}/usr/lib/NetworkManager/conf.d/10-globally-managed-devices.conf"

    # Disable wifi powersave
    (
        echo "[connection]"
        echo "wifi.powersave = 2"
    ) > "${chroot_dir}/usr/lib/NetworkManager/conf.d/20-override-wifi-powersave-disable.conf"

    return 0
}
