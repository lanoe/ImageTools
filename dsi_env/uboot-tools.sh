# Build UBoot tools
if [ -d /home/debian/u-boot-imx6 ]; then
    echo "Compile UBoot tools ..."
    cd /home/debian/u-boot-imx6
    make mx6cuboxi_defconfig
    diff .config config-uboot-silent
    cp config-uboot-silent .config
    make
    make envtools
    cd -
    if [ ! -d /home/debian/uboot-tools ]; then
        mkdir -p /home/debian/uboot-tools
    fi
    cp -f /home/debian/u-boot-imx6/u-boot.img /home/debian/uboot-tools/u-boot-dsi.img
    cp -f /home/debian/u-boot-imx6/SPL /home/debian/uboot-tools/SPL-dsi
    cp -f /home/debian/u-boot-imx6/tools/env/fw_printenv /home/debian/uboot-tools/.
    cp -f /home/debian/u-boot-imx6/tools/env/fw_printenv /home/debian/uboot-tools/fw_setenv
    echo "/dev/mmcblk0 0xfe000 0x2000" > /home/debian/uboot-tools/fw_env-mSata.config
    echo "/dev/mmcblk2 0xfe000 0x2000" > /home/debian/uboot-tools/fw_env-eMMC.config
    rm -rf /home/debian/u-boot-imx6
    bash /home/debian/script/update_uboot.sh
fi
