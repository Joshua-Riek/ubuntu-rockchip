# Kernel Patches for 4K@120Hz Support

This directory contains kernel patches to enable 4K@120Hz HDMI output on RK3588-based boards.

## Problem

The VOP2 driver in the Rockchip BSP kernel 6.1 limits the maximum display clock to 600 MHz:

```c
#define VOP2_MAX_DCLK_RATE    600000  // KHz = 600 MHz
```

This limits video output to 4K@60Hz (594 MHz pixel clock). 4K@120Hz requires ~1188 MHz.

## Solution

### Patch 0001: Increase VOP2_MAX_DCLK_RATE

Increases the maximum display clock limit from 600 MHz to 1200 MHz:

```c
#define VOP2_MAX_DCLK_RATE    1200000  // KHz = 1200 MHz
```

This allows the driver to accept 4K@120Hz modes. For clocks above 600 MHz, the driver
automatically uses the System CRU as clock source instead of the HDMI PHY PLL.

### Patch 0002: Prefer YCbCr 4:2:0 for High Bandwidth

Adds a helper to prefer YCbCr 4:2:0 output format for modes requiring > 600 MHz pixel clock.
YCbCr 4:2:0 halves the chroma bandwidth, making 4K@120Hz achievable within HDMI 2.0 bandwidth.

**Note:** Your TV must advertise YCbCr 4:2:0 support for 4K@120Hz in its EDID (typically VIC 118).

## Affected Boards

All RK3588-based boards with HDMI 2.1 output:

- Orange Pi 5 Max
- Orange Pi 5 Plus  
- Orange Pi 5 Pro
- Rock 5B / 5B Plus
- NanoPC-T6
- Radxa CM5
- And others

## How Patches Are Applied

The `scripts/build-kernel.sh` script automatically applies patches from this directory
during the kernel build process. Patches are applied in the order specified in the `series` file.

## Building

```bash
# Build full image with patched kernel
sudo ./build.sh --board=orangepi-5-max --suite=noble --flavor=desktop

# Or kernel only
sudo ./build.sh --suite=noble --kernel-only
```

## Testing

After installing the new kernel:

```bash
# Check kernel version
uname -r

# Check available modes
drm_info | grep -A 50 "HDMI-A-2"

# Look for 4K@120Hz
drm_info | grep "3840x2160" | grep "120"

# Check kernel messages
dmesg | grep -i "vop2\|hdmi"
```

## Troubleshooting

### 4K@120Hz mode not appearing

1. Check TV EDID supports VIC 118 (4K@120Hz YCbCr 4:2:0):
   ```bash
   sudo cat /sys/class/drm/card*/card*-HDMI-A-*/edid | edid-decode
   ```

2. Ensure HDMI cable is Ultra High Speed certified (48 Gbps)

3. Check TV is in "Enhanced HDMI" or "HDMI 2.1" mode (in TV settings)

### Display artifacts or instability

1. Try a certified Ultra High Speed HDMI cable
2. Test at 4K@60Hz first to confirm stability
3. Check kernel logs for errors: `dmesg | grep -i error`

## References

- [VOP2 Display Modes Handling (Collabora)](https://www.mail-archive.com/dri-devel@lists.freedesktop.org/msg528037.html)
- [RK3588 HDMI TX Controller Support](https://lwn.net/Articles/986173/)
- [Rockchip RK3588 Datasheet](https://rockchips.net/)
