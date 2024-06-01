# Target platforms supported by u-boot.
# debian/rules includes this Makefile snippet.

u-boot-rockchip_platforms += rock-5b-rk3588
rock-5b-rk3588_ddr := rk3588_ddr_lp4_2112MHz_lp5_2400MHz_v1.16.bin
rock-5b-rk3588_bl31 := rk3588_bl31_v1.45.elf
rock-5b-rk3588_pkg := rock-5b

u-boot-rockchip_platforms += rock-5b-plus-rk3588
rock-5b-plus-rk3588_ddr := rk3588_ddr_lp4_2112MHz_lp5_2400MHz_v1.16.bin
rock-5b-plus-rk3588_bl31 := rk3588_bl31_v1.45.elf
rock-5b-plus-rk3588_pkg := rock-5b-plus

u-boot-rockchip_platforms += rock-5a-rk3588s
rock-5a-rk3588s_ddr := rk3588_ddr_lp4_2112MHz_lp5_2400MHz_v1.16.bin
rock-5a-rk3588s_bl31 := rk3588_bl31_v1.45.elf
rock-5a-rk3588s_pkg := rock-5a

u-boot-rockchip_platforms += rock-5a-spi-rk3588s
rock-5a-spi-rk3588s_ddr := rk3588_ddr_lp4_2112MHz_lp5_2400MHz_v1.16.bin
rock-5a-spi-rk3588s_bl31 := rk3588_bl31_v1.45.elf
rock-5a-spi-rk3588s_pkg := rock-5a-spi

u-boot-rockchip_platforms += rock-5d-rk3588s
rock-5d-rk3588s_ddr := rk3588_ddr_lp4_2112MHz_lp5_2400MHz_v1.16.bin
rock-5d-rk3588s_bl31 := rk3588_bl31_v1.45.elf
rock-5d-rk3588s_pkg := rock-5d

u-boot-rockchip_platforms += rock-5c-rk3588s
rock-5c-rk3588s_ddr := rk3588_ddr_lp4_2112MHz_lp5_2400MHz_v1.16.bin
rock-5c-rk3588s_bl31 := rk3588_bl31_v1.45.elf
rock-5c-rk3588s_pkg := rock-5c

u-boot-rockchip_platforms += rock-5-itx-rk3588
rock-5-itx-rk3588_ddr := rk3588_ddr_lp4_2112MHz_lp5_2400MHz_v1.16.bin
rock-5-itx-rk3588_bl31 := rk3588_bl31_v1.45.elf
rock-5-itx-rk3588_pkg := rock-5-itx

u-boot-rockchip_platforms += radxa-cm5-io-rk3588s
radxa-cm5-io-rk3588s_ddr := rk3588_ddr_lp4_2112MHz_lp5_2400MHz_v1.16.bin
radxa-cm5-io-rk3588s_bl31 := rk3588_bl31_v1.45.elf
radxa-cm5-io-rk3588s_pkg := radxa-cm5-io

u-boot-rockchip_platforms += radxa-nx5-io-rk3588s
radxa-nx5-io-rk3588s_ddr := rk3588_ddr_lp4_2112MHz_lp5_2400MHz_v1.16.bin
radxa-nx5-io-rk3588s_bl31 := rk3588_bl31_v1.45.elf
radxa-nx5-io-rk3588s_pkg := radxa-nx5-io

u-boot-rockchip_platforms += nanopi-r6s-rk3588s
nanopi-r6s-rk3588s_ddr := rk3588_ddr_lp4_2112MHz_lp5_2736MHz_v1.11.bin
nanopi-r6s-rk3588s_bl31 := rk3588_bl31_v1.38.elf
nanopi-r6s-rk3588s_pkg := nanopi-r6s

u-boot-rockchip_platforms += nanopi-r6c-rk3588s
nanopi-r6c-rk3588s_ddr := rk3588_ddr_lp4_2112MHz_lp5_2736MHz_v1.11.bin
nanopi-r6c-rk3588s_bl31 := rk3588_bl31_v1.38.elf
nanopi-r6c-rk3588s_pkg := nanopi-r6c

u-boot-rockchip_platforms += nanopc-t6-rk3588
nanopc-t6-rk3588_ddr := rk3588_ddr_lp4_2112MHz_lp5_2736MHz_v1.11.bin
nanopc-t6-rk3588_bl31 := rk3588_bl31_v1.38.elf
nanopc-t6-rk3588_pkg := nanopc-t6

u-boot-rockchip_platforms += lubancat-4-rk3588s
lubancat-4-rk3588s_ddr := rk3588_ddr_lp4_2112MHz_lp5_2736MHz_v1.11.bin
lubancat-4-rk3588s_bl31 := rk3588_bl31_v1.38.elf
lubancat-4-rk3588s_pkg := lubancat-4

u-boot-rockchip_platforms += indiedroid-nova-rk3588s
indiedroid-nova-rk3588s_ddr := rk3588_ddr_lp4_2112MHz_lp5_2736MHz_v1.11.bin
indiedroid-nova-rk3588s_bl31 := rk3588_bl31_v1.38.elf
indiedroid-nova-rk3588s_pkg := indiedroid-nova

u-boot-rockchip_platforms += armsom-w3-rk3588
armsom-w3-rk3588_ddr := rk3588_ddr_lp4_2112MHz_lp5_2736MHz_v1.11.bin
armsom-w3-rk3588_bl31 := rk3588_bl31_v1.38.elf
armsom-w3-rk3588_pkg := armsom-w3

u-boot-rockchip_platforms += armsom-sige7-rk3588
armsom-sige7-rk3588_ddr := rk3588_ddr_lp4_2112MHz_lp5_2736MHz_v1.11.bin
armsom-sige7-rk3588_bl31 := rk3588_bl31_v1.38.elf
armsom-sige7-rk3588_pkg := armsom-sige7

u-boot-rockchip_platforms += roc-rk3588s-pc-rk3588s
roc-rk3588s-pc-rk3588s_ddr := rk3588_ddr_lp4_2112MHz_lp5_2736MHz_v1.11.bin
roc-rk3588s-pc-rk3588s_bl31 := rk3588_bl31_v1.38.elf
roc-rk3588s-pc-rk3588s_pkg := roc-rk3588s-pc

u-boot-rockchip_platforms += mixtile-core3588e-rk3588
mixtile-core3588e-rk3588_ddr := rk3588_ddr_lp4_2112MHz_lp5_2736MHz_v1.11.bin
mixtile-core3588e-rk3588_bl31 := rk3588_bl31_v1.38.elf
mixtile-core3588e-rk3588_pkg := mixtile-core3588e
