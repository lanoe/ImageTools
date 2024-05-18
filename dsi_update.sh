set -e
#set -x

# Make sure only user can run our script
if [ "$(id -u)" = "0" ]; then
    echo "This script must *NOT* be run as root" 1>&2
    exit 1
fi

export SDCARD_ROOTFS=/media/$USER/rootfs

if [ ! -f $SDCARD_ROOTFS/boot/config-3.14.79-fslc-imx6-sr ] && [ ! -f $SDCARD_ROOTFS/boot/config-4.9.124-imx6-sr ]; then
    echo "Please plug SD card with Debian !"
    exit 1
fi

if [ ! -f $SDCARD_ROOTFS/boot/config-3.14.79-fslc-imx6-sr+ ] && [ ! -f $SDCARD_ROOTFS/boot/config-4.9.124-imx6-sr+ ]; then
    echo "Specific Debian version built for DSI is NOT on SD card !"
    if [ -f $SDCARD_ROOTFS/boot/config-3.14.79-fslc-imx6-sr ]; then
        echo "Please launch './compile.sh -jessie' and after './update_rootfs.sh -jessie'"
    else
        echo "Please launch './compile.sh' and after './update_rootfs.sh'"
    fi
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
sudo rm -rf $SDCARD_ROOTFS/home/debian/BRIDGE_SYSTEM_VERSION
sudo rm -rf $SDCARD_ROOTFS/home/debian/DsiBridgeScript
sudo rm -rf $SDCARD_ROOTFS/home/debian/3gManager
sudo rm -rf $SDCARD_ROOTFS/home/debian/WifiManager
sudo rm -rf $SDCARD_ROOTFS/home/debian/SleepModeService
sudo rm -rf $SDCARD_ROOTFS/home/debian/openocd-flash-utility
sudo rm -rf $SDCARD_ROOTFS/home/debian/firmwares
sudo rm -rf $SDCARD_ROOTFS/home/debian/dsi_env

DSI_SRC=$PWD/dsi_src
mkdir -p $DSI_SRC

echo "Get BridgeSystemVersion ..."
rm -rf $DSI_SRC/bridge_system_version/BRIDGE_SYSTEM_VERSION/version
sync
if [ ! -d $DSI_SRC/bridge_system_version ]; then
    git clone ssh://git@gitlab.dsinstruments.fr:2222/bridge/bridge_system_version.git $DSI_SRC/bridge_system_version
fi
mkdir -p $DSI_SRC/bridge_system_version/BRIDGE_SYSTEM_VERSION/version
cd $DSI_SRC/bridge_system_version
git checkout master
dsi_git_version=$(git log -n1 --pretty='%h')
touch $DSI_SRC/bridge_system_version/BRIDGE_SYSTEM_VERSION/version/bridge_system_version-$dsi_git_version
cd -
sync

echo "Update host name ..."
dsi_hostname=Bridge_$(cat $DSI_SRC/bridge_system_version/BRIDGE_SYSTEM_VERSION/version.txt | sed 's/\./-/g')
old_hostname=$(sudo cat $SDCARD_ROOTFS/etc/hostname)
sudo sed -i "s/$old_hostname/$dsi_hostname/g" $SDCARD_ROOTFS/etc/hosts
sudo sed -i "s/$old_hostname/$dsi_hostname/g" $SDCARD_ROOTFS/etc/hostname

echo "Get DsiBridgeScript ..."
if [ ! -d $DSI_SRC/DsiBridgeScript ]; then
    git clone ssh://git@gitlab.dsinstruments.fr:2222/bridge/DsiBridgeScript.git $DSI_SRC/DsiBridgeScript
fi
cd $DSI_SRC/DsiBridgeScript
git checkout master
dsi_git_version=$(git log -n1 --pretty='%h')
dsi_tag_version=$(git describe --tags $dsi_git_version)
touch $DSI_SRC/bridge_system_version/BRIDGE_SYSTEM_VERSION/version/DsiBridgeScript-$dsi_tag_version-$dsi_git_version
cd -
sudo cp -rf $DSI_SRC/DsiBridgeScript $SDCARD_ROOTFS/home/debian/.
sync

echo "Get 3gManager ..."
if [ ! -d $DSI_SRC/3gManager ]; then
    git clone ssh://git@gitlab.dsinstruments.fr:2222/dsi/3gManager.git $DSI_SRC/3gManager
    sed -i "s/compile_mitm/#compile_mitm/g" $DSI_SRC/3gManager/build.sh
    sed -i "s/ #compile_mitm/ compile_mitm/g" $DSI_SRC/3gManager/build.sh
    sed -i "s/compile_cmux/#compile_cmux/g" $DSI_SRC/3gManager/build.sh
    sed -i "s/ #compile_cmux/ compile_cmux/g" $DSI_SRC/3gManager/build.sh
    cd $DSI_SRC/3gManager
    git checkout master
    git submodule update --init --recursive
    cd -
fi
cd $DSI_SRC/3gManager
dsi_git_version=$(git log -n1 --pretty='%h')
dsi_tag_version=$(git describe --tags $dsi_git_version)
touch $DSI_SRC/bridge_system_version/BRIDGE_SYSTEM_VERSION/version/3gManager-$dsi_tag_version-$dsi_git_version
cd -
sudo cp -rf $DSI_SRC/3gManager $SDCARD_ROOTFS/home/debian/.
sync

echo "Get SleepModeService ..."
if [ ! -d $DSI_SRC/SleepModeService ]; then
    git clone ssh://git@gitlab.dsinstruments.fr:2222/bridge/SleepModeService.git $DSI_SRC/SleepModeService
    cd $DSI_SRC/SleepModeService
    git checkout master
    git submodule update --init --recursive
    cd -
fi
cd $DSI_SRC/SleepModeService
dsi_git_version=$(git log -n1 --pretty='%h')
dsi_tag_version=$(git describe --tags $dsi_git_version)
touch $DSI_SRC/bridge_system_version/BRIDGE_SYSTEM_VERSION/version/SleepModeService-$dsi_tag_version-$dsi_git_version
cd -
sudo cp -rf $DSI_SRC/SleepModeService $SDCARD_ROOTFS/home/debian/.
sync

echo "Get WifiManager ..."
if [ ! -d $DSI_SRC/WifiManager ]; then
    git clone ssh://git@gitlab.dsinstruments.fr:2222/bridge/WifiManager.git $DSI_SRC/WifiManager
    cd $DSI_SRC/WifiManager
    git checkout master
    git submodule update --init --recursive
    cd -
fi
cd $DSI_SRC/WifiManager
dsi_git_version=$(git log -n1 --pretty='%h')
dsi_tag_version=$(git describe --tags $dsi_git_version)
touch $DSI_SRC/bridge_system_version/BRIDGE_SYSTEM_VERSION/version/WifiManager-$dsi_tag_version-$dsi_git_version
cd -
sudo cp -rf $DSI_SRC/WifiManager $SDCARD_ROOTFS/home/debian/.
sync

echo "Get openOCD ..."
if [ ! -d $DSI_SRC/openocd-flash-utility ]; then
    git clone ssh://git@gitlab.dsinstruments.fr:2222/bridge/openocd-flash-utility.git $DSI_SRC/openocd-flash-utility
    cd $DSI_SRC/openocd-flash-utility
    git checkout master
    cd -
fi
cd $DSI_SRC/openocd-flash-utility
dsi_git_version=$(git log -n1 --pretty='%h')
touch $DSI_SRC/bridge_system_version/BRIDGE_SYSTEM_VERSION/version/openocd-flash-utility-$dsi_git_version
cd -
sudo cp -rf $DSI_SRC/openocd-flash-utility $SDCARD_ROOTFS/home/debian/.
sync

echo "Update BRIDGE_SYSTEM_VERSION ..."
sudo cp -rf $DSI_SRC/bridge_system_version/BRIDGE_SYSTEM_VERSION $SDCARD_ROOTFS/home/debian/.

echo "Get dsi-storage script ..."
if [ ! -d $DSI_SRC/dsi-storage ]; then
    git clone ssh://git@gitlab.dsinstruments.fr:2222/to136/dsi-storage.git $DSI_SRC/dsi-storage
    cd $DSI_SRC/dsi-storage
    git checkout master
    cd -
fi
cd $DSI_SRC/dsi-storage
dsi_git_version=$(git log -n1 --pretty='%h')
touch $DSI_SRC/bridge_system_version/BRIDGE_SYSTEM_VERSION/version/dsi-storage-$dsi_git_version
cd -
sudo cp -f $DSI_SRC/dsi-storage/dsi-storage $SDCARD_ROOTFS/root/.
sync

echo "Customize 'debian' user ..."

if ! sudo grep -qs '# Add for DSI' $SDCARD_ROOTFS/home/debian/.bashrc ; then
    echo "" | sudo tee -a $SDCARD_ROOTFS/home/debian/.bashrc > /dev/null 
    echo "# Add for DSI" | sudo tee -a $SDCARD_ROOTFS/home/debian/.bashrc > /dev/null 
    echo "alias ll='ls -laF'" | sudo tee -a $SDCARD_ROOTFS/home/debian/.bashrc > /dev/null
    echo "PATH=\$PATH:/sbin:/usr/sbin/" | sudo tee -a $SDCARD_ROOTFS/home/debian/.bashrc > /dev/null
    echo "complete -cf sudo" | sudo tee -a $SDCARD_ROOTFS/home/debian/.bashrc > /dev/null
    echo "" | sudo tee -a $SDCARD_ROOTFS/home/debian/.bashrc > /dev/null 
fi

sudo sed -i "s/rootfstype=ext4 console=tty1/rootfstype=auto/g" $SDCARD_ROOTFS/boot/extlinux/extlinux.conf

if sudo grep -qs '# DSI network configuration' $SDCARD_ROOTFS/etc/network/interfaces ; then
    sudo sed -i "s/# DSI network configuration/# DEBIAN network configuration/g" $SDCARD_ROOTFS/etc/network/interfaces
    sudo sed -i "s/#iface eth inet dhcp/iface eth inet dhcp/g" $SDCARD_ROOTFS/etc/network/interfaces
    sudo sed -i "s/iface eth inet static/#iface eth inet static/g" $SDCARD_ROOTFS/etc/network/interfaces
    sudo sed -i "s/address 192.168.0.2/#address 192.168.22.2/g" $SDCARD_ROOTFS/etc/network/interfaces
    sudo sed -i "s/address 192.168.22.2/#address 192.168.22.2/g" $SDCARD_ROOTFS/etc/network/interfaces
    sudo sed -i "s/netmask 255.255.255.0/#netmask 255.255.255.0/g" $SDCARD_ROOTFS/etc/network/interfaces
    sudo sed -i "s/auto wlan/#auto wlan/g" $SDCARD_ROOTFS/etc/network/interfaces
    sudo sed -i "s/iface wlan inet static/#iface wlan inet static/g" $SDCARD_ROOTFS/etc/network/interfaces
    sudo sed -i "s/address 192.168.32.42/#address 192.168.32.42/g" $SDCARD_ROOTFS/etc/network/interfaces
    sudo sed -i "s/gateway 192.168.32.1/#gateway 192.168.32.1/g" $SDCARD_ROOTFS/etc/network/interfaces
    sudo sed -i "s/broadcast 192.168.32.255/#broadcast 192.168.32.255/g" $SDCARD_ROOTFS/etc/network/interfaces
fi

echo "Copy 'dsi_install.sh' script and 'dsi_env' files ..."
sudo mkdir -p $SDCARD_ROOTFS/home/debian/firmwares
sudo cp -rf dsi_env $SDCARD_ROOTFS/home/debian/.
sudo mv $SDCARD_ROOTFS/home/debian/dsi_env/dsi_install.sh $SDCARD_ROOTFS/home/debian/dsi_install.sh
sudo mv $SDCARD_ROOTFS/home/debian/dsi_env/iptables-rules.sh $SDCARD_ROOTFS/home/debian/iptables-rules.sh
sudo mv $SDCARD_ROOTFS/home/debian/dsi_env/RELEASE_IsmMaster_2018_07_27_revision_1_2_12.hex $SDCARD_ROOTFS/home/debian/firmwares/.
sudo chmod 775 $SDCARD_ROOTFS/home/debian/dsi_install.sh

echo "Clean $SDCARD_ROOTFS/var/log/ ..."
sudo rm -rf $SDCARD_ROOTFS/var/log/*

echo "Umount SD card ..."
sync
umount $SDCARD_ROOTFS
udisksctl power-off -b /dev/$disk
echo ""
echo "SD card ready to install DSI environment !"
echo ""
echo "TODO : log on 'debian@$dsi_hostname' and launch 'sudo ./dsi_install.sh'"
echo ""
