set -e
#set -x

# Make sure only user can run our script
if [ "$(id -u)" = "0" ]; then
    echo "This script must *NOT* be run as root" 1>&2
    exit 1
fi

TOOL_VERSION=1.0.13

export SDCARD_ROOTFS=/media/$USER/rootfs

if [ ! -d $SDCARD_ROOTFS ]; then
    echo "Please insert SD card !"
    exit 1
fi

if [ ! -f $SDCARD_ROOTFS/boot/config-4.9.124-fuses+ ]; then
    echo "Specific Debian Stretch version with 'fuse' kernel built for DSI Tools is NOT on SD card !"
    echo "Please launch './compile.sh -fuses' and after './update_rootfs.sh -fuses'"
    exit 1
fi

if [ ! -f $SDCARD_ROOTFS/home/debian/.bashrc ]; then
    echo "Please create 'debian' user on SD card !"
    exit 1
fi

partition=$(lsblk | grep $SDCARD_ROOTFS | awk '{print $1}')
if [ "$partition" = "" ]; then
    echo "Unplug/plug the SD card"
    exit 1
fi
partition=${partition:2} # remove the 2 first char
disk=${partition#*p} # remove 'p'
disk=${disk::-1} # remove the last char

echo "Clean $SDCARD_ROOTFS ..."
sudo rm -rf $SDCARD_ROOTFS/home/debian/BridgeConfiguration
sudo rm -rf $SDCARD_ROOTFS/home/debian/openocd-flash-utility
sudo rm -rf $SDCARD_ROOTFS/home/debian/tests
sudo rm -rf $SDCARD_ROOTFS/home/debian/script
sync

DSI_SRC=$PWD/tools_src
DSI_ENV=$PWD/dsi_env

if [ ! -d $DSI_SRC ]; then
    mkdir -p $DSI_SRC
fi

echo "DSI Tool version $TOOL_VERSION" > $DSI_SRC/version.txt
echo "DSI Module version :" >> $DSI_SRC/version.txt

echo "Get Emmc Flash repository ..."
if [ ! -d $DSI_SRC/Emmc_flash_utility ]; then
    git clone ssh://git@gitlab.dsinstruments.fr:2222/bridge/Emmc_flash_utility.git $DSI_SRC/Emmc_flash_utility
fi
cd $DSI_SRC/Emmc_flash_utility
git pull && git checkout os_debian9 && git submodule update --init --recursive
dsi_git_version=$(git log -n1 --pretty='%h')
echo "Emmc_flash_utility : $dsi_git_version" >> $DSI_SRC/version.txt
cd -
cd $DSI_SRC/Emmc_flash_utility/dsi-storage
dsi_git_version=$(git log -n1 --pretty='%h')
echo "dsi-storage : $dsi_git_version" >> $DSI_SRC/version.txt
cd -
sync

echo "Get Bridge Configuration repository ..."
if [ ! -d $DSI_SRC/BridgeConfiguration ]; then
    git clone ssh://git@gitlab.dsinstruments.fr:2222/bridge/BridgeConfiguration.git $DSI_SRC/BridgeConfiguration
fi
cd $DSI_SRC/BridgeConfiguration
git pull && git checkout development && git submodule update --init --recursive
dsi_git_version=$(git log -n1 --pretty='%h')
echo "BridgeConfiguration : $dsi_git_version" >> $DSI_SRC/version.txt
cd -
sync

echo "Get OpenOCD utility ..."
if [ ! -d $DSI_SRC/openocd-flash-utility ]; then
    git clone ssh://git@gitlab.dsinstruments.fr:2222/bridge/openocd-flash-utility.git $DSI_SRC/openocd-flash-utility
fi
cd $DSI_SRC/openocd-flash-utility
git pull && git checkout master && git submodule update --init --recursive
dsi_git_version=$(git log -n1 --pretty='%h')
echo "openocd-flash-utility : $dsi_git_version" >> $DSI_SRC/version.txt
cd -
sync

echo "Get Bridge Test ..."
if [ ! -d $DSI_SRC/BridgeTest ]; then
    git clone ssh://git@gitlab.dsinstruments.fr:2222/bridge/BridgeTest.git $DSI_SRC/BridgeTest
fi
cd $DSI_SRC/bridge_auto_test
git pull && git checkout development && git submodule update --init --recursive
dsi_git_version=$(git log -n1 --pretty='%h')
echo "bridge_auto_test : $dsi_git_version" >> $DSI_SRC/version.txt
cd -
sync

if [ ! -d $SDCARD_ROOTFS/home/debian/uboot-tools ]; then
    echo "Get UBoot tools ..."
    if [ ! -d $DSI_SRC/u-boot-imx6 ]; then
        pushd $DSI_SRC
        if [ ! -f u-boot-imx6.tar.gz ] ; then
            git clone --branch v2018.01-solidrun-imx6 https://github.com/SolidRun/u-boot.git u-boot-imx6
            pushd u-boot-imx6
            git checkout 457cdd60c331e
            popd
            echo "create tarball u-boot-imx6.tar.gz ..."
            tar -czf u-boot-imx6.tar.gz u-boot-imx6/
        else
            echo "untar u-boot-imx6.tar.gz ..."
            tar -zxf u-boot-imx6.tar.gz
        fi
        popd
    fi
    cp config/config-uboot-silent $DSI_SRC/u-boot-imx6/.
    sed -i "s/-dirty/-dsi/g" $DSI_SRC/u-boot-imx6/scripts/setlocalversion
    sudo cp -rf $DSI_SRC/u-boot-imx6 $SDCARD_ROOTFS/home/debian/.
fi

echo "Update hostname ..."
dsi_hostname=dsi-prod
old_hostname=$(sudo cat $SDCARD_ROOTFS/etc/hostname)
sudo sed -i "s/$old_hostname/$dsi_hostname/g" $SDCARD_ROOTFS/etc/hosts
sudo sed -i "s/$old_hostname/$dsi_hostname/g" $SDCARD_ROOTFS/etc/hostname

echo "Update SDCard ..."
sudo cp -rf $DSI_SRC/BridgeConfiguration $SDCARD_ROOTFS/home/debian/.
sudo cp -rf $DSI_SRC/bridge_auto_test/tests $SDCARD_ROOTFS/home/debian/.

sudo cp -rf $DSI_SRC/openocd-flash-utility $SDCARD_ROOTFS/home/debian/.
sudo cp -f $DSI_SRC/openocd-flash-utility/50-openocd-adapter.rules $SDCARD_ROOTFS/etc/udev/rules.d/.

sudo mkdir -p $SDCARD_ROOTFS/home/debian/firmwares
sudo cp -f dsi_env/RELEASE_IsmMaster* $SDCARD_ROOTFS/home/debian/firmwares/.

if [ -f $SDCARD_ROOTFS/home/debian/version.txt ]; then
    old_version=$(cat $SDCARD_ROOTFS/home/debian/version.txt | grep dsi-storage | awk '{print $3}')
else
    old_version=""
fi
new_version=$(cat $DSI_SRC/version.txt | grep dsi-storage | awk '{print $3}')

if [ "$old_version" != "$new_version" ]; then
    echo "Update SDCard : dsi-storage ..."
    sudo rm -f $SDCARD_ROOTFS/lib/libTO.so $SDCARD_ROOTFS/lib/libTO_i2c_wrapper.so
    sudo rm -rf $SDCARD_ROOTFS/home/debian/dsi-storage && sync
    sudo cp -rf $DSI_SRC/Emmc_flash_utility/dsi-storage $SDCARD_ROOTFS/home/debian/.
    # patch TO136 lib to increase I2C_TIMEOUT
    sudo sed -i "s/#define TO_I2C_TIMEOUT 1000/#define TO_I2C_TIMEOUT 1500/g" $SDCARD_ROOTFS/home/debian/dsi-storage/libto/wrapper/linux_generic.c
fi

sudo sed -i "s/rootfstype=auto/rootfstype=ext4/g" $SDCARD_ROOTFS/boot/extlinux/extlinux.conf
sudo sed -i "s/rootfstype=ext4 rootwait/rootfstype=ext4 console=tty1 rootwait/g" $SDCARD_ROOTFS/boot/extlinux/extlinux.conf
sudo sed -i "s/console=tty1/console=tty2/g" $SDCARD_ROOTFS/boot/extlinux/extlinux.conf

sudo cp -f $DSI_SRC/version.txt $SDCARD_ROOTFS/home/debian/.

sudo mkdir -p $SDCARD_ROOTFS/home/debian/script

sudo cp $DSI_SRC/Emmc_flash_utility/emmc_flash.sh $SDCARD_ROOTFS/home/debian/script/.
sudo cp $DSI_ENV/bridge_config.sh $SDCARD_ROOTFS/home/debian/script/.
sudo cp $DSI_ENV/install_openvpn.sh $SDCARD_ROOTFS/home/debian/script/.
sudo cp $DSI_ENV/launch_openvpn.sh $SDCARD_ROOTFS/home/debian/script/.
sudo cp $DSI_ENV/build_to136.sh $SDCARD_ROOTFS/home/debian/script/.
sudo cp $DSI_ENV/update_openocd.sh $SDCARD_ROOTFS/home/debian/script/.
sudo cp $DSI_ENV/update_ofono.sh $SDCARD_ROOTFS/home/debian/script/.
sudo cp $DSI_ENV/build_hardware_tests.sh $SDCARD_ROOTFS/home/debian/script/.
sudo cp $DSI_ENV/uboot-tools.sh $SDCARD_ROOTFS/home/debian/script/.
sudo cp $DSI_ENV/update_uboot.sh $SDCARD_ROOTFS/home/debian/script/.
sudo cp $DSI_ENV/disk.sh $SDCARD_ROOTFS/home/debian/script/.
sudo cp $DSI_ENV/updatehostmac.sh $SDCARD_ROOTFS/home/debian/script/.
sudo cp $DSI_ENV/resize.service $SDCARD_ROOTFS/lib/systemd/system/resize.service
sudo cp $DSI_ENV/resize $SDCARD_ROOTFS/root/resize
sudo cp $DSI_ENV/99-huawei-dsi.rules $SDCARD_ROOTFS/etc/udev/rules.d/.
sudo cp $DSI_ENV/98-amber-dsi.rules $SDCARD_ROOTFS/etc/udev/rules.d/.

if ! sudo grep -qs '# Add for DSI' $SDCARD_ROOTFS/home/debian/.bashrc ; then
    echo "" | sudo tee -a $SDCARD_ROOTFS/home/debian/.bashrc > /dev/null
    echo "# Add for DSI" | sudo tee -a $SDCARD_ROOTFS/home/debian/.bashrc > /dev/null
    echo "alias ll='ls -laF'" | sudo tee -a $SDCARD_ROOTFS/home/debian/.bashrc > /dev/null
    echo "PATH=\$PATH:/sbin:/usr/sbin/" | sudo tee -a $SDCARD_ROOTFS/home/debian/.bashrc > /dev/null
    echo "complete -cf sudo" | sudo tee -a $SDCARD_ROOTFS/home/debian/.bashrc > /dev/null
    echo "" | sudo tee -a $SDCARD_ROOTFS/home/debian/.bashrc > /dev/null
fi
sync

echo "Create 'install_config_env.sh' ..."

echo "" > $DSI_SRC/install_config_env.sh
echo "# Install OpenVPN" >> $DSI_SRC/install_config_env.sh
echo "bash /home/debian/script/install_openvpn.sh" >> $DSI_SRC/install_config_env.sh
echo "rm -f /home/debian/script/install_openvpn.sh" >> $DSI_SRC/install_config_env.sh

echo "" >> $DSI_SRC/install_config_env.sh
echo "# Build library for TO136" >> $DSI_SRC/install_config_env.sh
echo "bash /home/debian/script/build_to136.sh" >> $DSI_SRC/install_config_env.sh
echo "rm -f /home/debian/script/build_to136.sh" >> $DSI_SRC/install_config_env.sh

echo "" >> $DSI_SRC/install_config_env.sh
echo "# Update OpenOCD" >> $DSI_SRC/install_config_env.sh
echo "bash /home/debian/script/update_openocd.sh" >> $DSI_SRC/install_config_env.sh
echo "rm -f /home/debian/script/update_openocd.sh" >> $DSI_SRC/install_config_env.sh

echo "" >> $DSI_SRC/install_config_env.sh
echo "# Update ofono" >> $DSI_SRC/install_config_env.sh
echo "bash /home/debian/script/update_ofono.sh" >> $DSI_SRC/install_config_env.sh
echo "rm -f /home/debian/script/update_ofono.sh" >> $DSI_SRC/install_config_env.sh

echo "" >> $DSI_SRC/install_config_env.sh
echo "# Build Hardware Test" >> $DSI_SRC/install_config_env.sh
echo "bash /home/debian/script/build_hardware_tests.sh" >> $DSI_SRC/install_config_env.sh
echo "rm -f /home/debian/script/build_hardware_tests.sh" >> $DSI_SRC/install_config_env.sh

echo "" >> $DSI_SRC/install_config_env.sh
echo "# Update usb_modeswitch for Huawei 3G dongle" >> $DSI_SRC/install_config_env.sh
echo "usbmodeswitch=\$(usb_modeswitch --version | grep 'Version 2.5.0')" >> $DSI_SRC/install_config_env.sh
echo "if [ \"\$usbmodeswitch\" = \"\" ]; then" >> $DSI_SRC/install_config_env.sh
echo "    apt-get -y install usb-modeswitch" >> $DSI_SRC/install_config_env.sh
echo "fi" >> $DSI_SRC/install_config_env.sh

echo "" >> $DSI_SRC/install_config_env.sh
echo "# Build UBoot tools" >> $DSI_SRC/install_config_env.sh
echo "bash /home/debian/script/uboot-tools.sh" >> $DSI_SRC/install_config_env.sh
echo "rm -f /home/debian/script/uboot-tools.sh" >> $DSI_SRC/install_config_env.sh

echo "" >> $DSI_SRC/install_config_env.sh
echo "systemctl enable resize.service" >> $DSI_SRC/install_config_env.sh
echo "systemctl disable serial-getty@ttymxc0.service" >> $DSI_SRC/install_config_env.sh
echo "systemctl stop serial-getty@ttymxc0.service" >> $DSI_SRC/install_config_env.sh
echo "sync" >> $DSI_SRC/install_config_env.sh
echo "dsi_hostname=\$(cat /etc/hostname)" >> $DSI_SRC/install_config_env.sh
echo "echo \"BridgeConfig is ready, connect to http://\$dsi_hostname:4242\"" >> $DSI_SRC/install_config_env.sh

sudo cp $DSI_SRC/install_config_env.sh $SDCARD_ROOTFS/home/debian/BridgeConfiguration/install_config_env.sh
sync

echo "Clean $SDCARD_ROOTFS/var/log/ ..."
sudo rm -rf $SDCARD_ROOTFS/var/log/*
sync

echo "Umount SD card ..."
umount $SDCARD_ROOTFS
udisksctl power-off -b /dev/$disk

echo ""
echo "SD card TOOLS ready !"
echo ""
echo "TODO :"
echo "- log on 'debian@$dsi_hostname'"
echo "- launch 'sudo ./build.sh' in '/BridgeConfiguration'"
echo "- connect to 'http://$dsi_hostname:4242'"
echo ""
