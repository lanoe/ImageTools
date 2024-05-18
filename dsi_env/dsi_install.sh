#!/bin/bash

set -e
#set -x

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

echo "Install utilities ..."
apt-get clean
apt-get update
apt-get -y autoremove

apt-get -y install build-essential python-dev python-pip libffi-dev libssl-dev libxml2-dev libxslt1-dev libglib2.0-dev libsqlite3-dev librxtx-java
apt-get -y install net-tools vim usb-modeswitch cryptsetup unzip
apt-get -y install make libtool pkg-config autoconf automake texinfo libusb-1.0-0 libusb-1.0-0-dev git

set +e
echo -e "\n\n" | apt-get -y install iptables-persistent
set -e

pip install --upgrade setuptools
pip install --upgrade pip

echo "Update firmware ..."
apt-get -y install cuboxi-firmware-wireless cuboxi-firmware-wireless-bluetooth cuboxi-firmware-wireless-bluetooth-ti cuboxi-firmware-wireless-wifi cuboxi-firmware-wireless-wifi-config cuboxi-firmware-wireless-wifi-config-ti firmware-ti-connectivity

# for OpenMuc
version=0.17.0
echo "Get OpenMuc-$version ..."
if [ ! -f openmuc-$version.tgz ]; then
    wget https://www.openmuc.org/openmuc/files/releases/openmuc-$version.tgz
fi

echo "Install and/or configure usefull services ..."

if ! which openocd > /dev/null; then
    git clone -b v0.10.0 --recursive https://github.com/ntfreak/openocd.git
    cd openocd
    ./bootstrap
    ./configure
    make
    make install
    cd -
    rm -rf openocd
fi

systemctl stop ofono.service dundee.service
systemctl disable ofono.service dundee.service

apt-get -y install hostapd
systemctl stop hostapd.service
systemctl disable hostapd.service

apt-get -y install rsync
systemctl stop rsync.service
systemctl disable rsync.service

apt-get -y install nginx
systemctl stop nginx.service
systemctl disable nginx.service

apt-get -y install ppp
systemctl stop pppd-dns.service
systemctl disable pppd-dns.service

apt-get -y install openvpn
systemctl stop openvpn.service pcscd.socket
systemctl disable pcscd.socket

apt-get -y install dnsmasq
systemctl stop dnsmasq.service
apt-get -y remove dns-root-data

apt-get -y install telnet

systemctl disable keyboard-setup.service
systemctl disable console-setup.service
systemctl disable apt-daily-upgrade.timer apt-daily.timer

echo "Install JDK ..."
apt -y install default-jdk

if [ "$1" = "-onlytools" ]; then
    echo "Just install required libraries for python ..."
    cd DsiBridgeScript/install_deps/
    ./install_dependencies.sh
    cd -
    version=0
    virgin_hostname=VirginV$version
    old_hostname=$(sudo cat /etc/hostname)
    rm -rf DsiBridgeScript/ 3gManager/ SleepModeService/
    rm -rf WifiManager/ openocd-flash-utility/
    rm -rf firmwares/
    rm -rf /root/version
    sed -i "s/$old_hostname/$virgin_hostname/g" /etc/hosts
    sed -i "s/$old_hostname/$virgin_hostname/g" /etc/hostname
    sync
    echo "Please remove the current file $0"
    exit 0
fi

echo "Set TimeZone to Europe/Paris ..."
timedatectl set-timezone Europe/Paris

echo "Activate watchdog service ..."
sed -i "s/#RuntimeWatchdogSec=0/RuntimeWatchdogSec=20/g" /etc/systemd/system.conf
sed -i "s/#ShutdownWatchdogSec=10min/ShutdownWatchdogSec=10min/g" /etc/systemd/system.conf

echo "Create DsiBridgeScript ..."
cd DsiBridgeScript
./build.sh
cd -

echo "Create 3gManager ..."
cd 3gManager
./build.sh
cd -

echo "Create SleepModeService ..."
cd SleepModeService
./build.sh
cd -

echo "Create WifiManager ..."
cd WifiManager
./build.sh
cd -

if [ -d /home/dsi ]; then
    deluser --remove-home dsi
    sync
fi

echo "Create 'dsi' ..."
set +e
echo -e "dsi2013\ndsi2013\n\n\n\n\n\nY\n" | adduser dsi
set -e
usermod -aG i2c dsi
usermod -aG dialout dsi
usermod -aG sudo dsi
sync

echo "Install OpenMuc ..."
rm -rf openmuc-$version/ 
tar -xzf openmuc-$version.tgz
mv openmuc openmuc-$version
cd openmuc-$version/framework
cp ../dependencies/j2mod/j2mod-r100.jar bundle/.
cp ../dependencies/rxtx/jrxtx-1.0.1.jar bundle/.
rm -f bundle/openmuc-app-simpledemo-$version.jar
rm -f bundle/openmuc-datalogger-ascii-$version.jar
rm -f bundle/openmuc-datalogger-slotsdb-$version.jar
cp ../build/libs-all/openmuc-driver-wmbus-$version.jar bundle/.
cp ../build/libs-all/openmuc-driver-iec60870-$version.jar bundle/.
cp ../build/libs-all/openmuc-driver-iec61850-$version.jar bundle/.
cp ../build/libs-all/openmuc-driver-iec62056p21-$version.jar bundle/.
cp ../build/libs-all/openmuc-driver-knx-$version.jar bundle/.
cp ../build/libs-all/openmuc-driver-mbus-$version.jar bundle/.
cp ../build/libs-all/openmuc-driver-modbus-$version.jar bundle/.
cp ../build/libs-all/openmuc-driver-wmbus-$version.jar bundle/.
cp ../build/libs-all/openmuc-server-modbus-$version.jar bundle/.
unzip -e ../dependencies/rxtx/rxtx-2.2pre2-bins.zip
cp rxtx-2.2pre2-bins/RXTXcomm.jar bundle/.
rm -rf rxtx-2.2pre2-bins/
rm -f bundle/slf4j-api-1.7.25.jar
cd -
mkdir -p /home/dsi/openmuc-$version
cp -rf openmuc-$version/framework /home/dsi/openmuc-$version/.
sync

echo "Install Bridge System Version..."
cp -rf BRIDGE_SYSTEM_VERSION /home/dsi/.
sync

echo "Install DsiBridgeScript ..."
cd DsiBridgeScript/dsibridge_script_install/.
set +e
echo -e "2\n" | bash ./install.sh
set -e
cd -

sed -i "s/stress-test/fake/g" /home/dsi/DsiBridge/config/default.cfg
sed -i "s/serial = \/dev\/ttyACM0/serial = \/dev\/ttymxc2/g" /home/dsi/DsiBridge/config/default.cfg
sed -i "s/location = \/home\/vsaindon\/Work_Area\/openmuc_v0.17.0/location = \/home\/dsi\/openmuc-$version/g" /home/dsi/DsiBridge/config/default.cfg
sed -i "s/xml_config_file = \/home\/vsaindon\/Work_Area\/openmuc_v0.17.0\/framework\/conf\/channels.xml/xml_config_file = \/home\/dsi\/openmuc-$version\/framework\/conf\/channels.xml/g" /home/dsi/DsiBridge/config/default.cfg

echo "Install 3gManager ..."
cd 3gManager/3g_manager_install/.
set +e
if [ "$1" = "-debug" ]; then
    # enable "Orange Reunion" if '-debug' param
    echo -e "1\n2\n" | bash ./install.sh
else
    echo -e "4\n2\n" | bash ./install.sh
fi
set -e
cd -

echo "Install SleepModeService ..."
cd SleepModeService/SleepMode_install/.
bash ./install.sh
cd -
systemctl disable sleepmode.service

echo "Install WifiManager ..."
cd WifiManager/WifiManager_install/.
bash ./install.sh
cd -

# Update WifiManager to start wifi AP
if ! grep -qs 'systemctl start hostapd.service' /usr/bin/dsi/WifiManager/wifi_manager ; then
    sed -i "s/printToLog \"WIFI MANAGER | SERVICE START\"/printToLog \"WIFI MANAGER | SERVICE START\"\n\nsystemctl start hostapd.service\nsleep 1800\nsystemctl stop hostapd.service\n\n/g" /usr/bin/dsi/WifiManager/wifi_manager
fi

echo "Update dsi-storage service ..."
chmod 700 /root/dsi-storage

echo "[Unit]" > /lib/systemd/system/dsi-storage.service
echo "Description=Service to mount dsi storage" >> /lib/systemd/system/dsi-storage.service
echo "" >> /lib/systemd/system/dsi-storage.service
echo "[Service]" >> /lib/systemd/system/dsi-storage.service
echo "Type=oneshot" >> /lib/systemd/system/dsi-storage.service
echo "ExecStart=/bin/bash /root/dsi-storage /home" >> /lib/systemd/system/dsi-storage.service
echo "" >> /lib/systemd/system/dsi-storage.service
echo "[Install]" >> /lib/systemd/system/dsi-storage.service
echo "WantedBy=multi-user.target" >> /lib/systemd/system/dsi-storage.service

systemctl enable dsi-storage.service

echo "Install openocd-flash-utility ..."
cp -rf openocd-flash-utility /home/dsi/.
sync

echo "Update firmwares file ..."
cp -rf firmwares /home/dsi/.
sync

echo "Add udev rules for openocd ..."
cp openocd-flash-utility/50-openocd-adapter.rules /etc/udev/rules.d/.
sync

if [ "$1" = "-debug" ]; then
    echo "Debug configure file for openvpn ..."
    cp dsi_env/dev4.conf /etc/openvpn/dev4.conf
else
    rm -f /etc/openvpn/dev4.conf
fi

echo "Update network ..."

systemctl disable connman.service
systemctl disable connman-wait-online.service
if [ -f /usr/lib/tmpfiles.d/connman_resolvconf.conf ]; then
    mv /usr/lib/tmpfiles.d/connman_resolvconf.conf /usr/lib/tmpfiles.d/connman_resolvconf.saved
fi

echo "KERNEL==\"eth*\", NAME=\"eth\"" > /etc/udev/rules.d/90-dsi-net.rules
echo "KERNEL==\"wlan*\", NAME=\"wlan\"" >> /etc/udev/rules.d/90-dsi-net.rules

if grep -qs '# DEBIAN network configuration' /etc/network/interfaces ; then
    sed -i "s/# DEBIAN network configuration/# DSI network configuration/g" /etc/network/interfaces
    sed -i "s/iface eth inet dhcp/#iface eth inet dhcp/g" /etc/network/interfaces
    sed -i "s/#iface eth inet static/iface eth inet static/g" /etc/network/interfaces
    sed -i "s/#address 192.168.0.2/address 192.168.22.2/g" /etc/network/interfaces
    sed -i "s/#address 192.168.22.2/address 192.168.22.2/g" /etc/network/interfaces
    sed -i "s/#netmask 255.255.255.0/netmask 255.255.255.0/g" /etc/network/interfaces
    sed -i "s/#auto wlan/auto wlan/g" /etc/network/interfaces
    sed -i "s/#iface wlan inet static/iface wlan inet static/g" /etc/network/interfaces
    sed -i "s/#address 192.168.32.42/address 192.168.32.42/g" /etc/network/interfaces
    sed -i "s/#netmask 255.255.255.0/netmask 255.255.255.0/g" /etc/network/interfaces
    sed -i "s/#gateway 192.168.32.1/gateway 192.168.32.1/g" /etc/network/interfaces
    sed -i "s/#broadcast 192.168.32.255/broadcast 192.168.32.255/g" /etc/network/interfaces
fi

if ! grep -qs '# DSI network configuration' /etc/network/interfaces ; then
    echo "" >> /etc/network/interfaces
    echo "# DSI network configuration" >> /etc/network/interfaces
    echo "" >> /etc/network/interfaces
    echo "allow-hotplug eth" >> /etc/network/interfaces
    echo "auto eth" >> /etc/network/interfaces
    echo "#iface eth inet dhcp" >> /etc/network/interfaces
    echo "iface eth inet static" >> /etc/network/interfaces
    echo "address 192.168.22.2" >> /etc/network/interfaces
    echo "netmask 255.255.255.0" >> /etc/network/interfaces
    echo "" >> /etc/network/interfaces
    echo "auto wlan" >> /etc/network/interfaces
    echo "iface wlan inet static" >> /etc/network/interfaces
    echo "address 192.168.32.42" >> /etc/network/interfaces
    echo "netmask 255.255.255.0" >> /etc/network/interfaces
    echo "gateway 192.168.32.1" >> /etc/network/interfaces
    echo "broadcast 192.168.32.255" >> /etc/network/interfaces
    echo "#post-up systemctl restart hostapd.service" >> /etc/network/interfaces
fi

dsi_wifi_version=$(cat /etc/hostname)
dsi_wifi_version=${dsi_wifi_version:6} # remove 'Bridge'
dsi_wifi_version=`echo $dsi_wifi_version | sed -e "s/-//g"` # remove '-'

echo "interface=wlan" > /etc/hostapd/hostapd.conf
echo "driver=nl80211" >> /etc/hostapd/hostapd.conf
echo "ssid=BNet_usineInit$dsi_wifi_version" >> /etc/hostapd/hostapd.conf
echo "hw_mode=g" >> /etc/hostapd/hostapd.conf
echo "channel=1" >> /etc/hostapd/hostapd.conf
echo "auth_algs=1" >> /etc/hostapd/hostapd.conf
echo "beacon_int=100" >> /etc/hostapd/hostapd.conf
echo "dtim_period=2" >> /etc/hostapd/hostapd.conf
echo "max_num_sta=255" >> /etc/hostapd/hostapd.conf
echo "rts_threshold=2347" >> /etc/hostapd/hostapd.conf
echo "fragm_threshold=2346" >> /etc/hostapd/hostapd.conf
echo "wpa=1" >> /etc/hostapd/hostapd.conf
echo "wpa_passphrase=wifi@D\$iusineInit$dsi_wifi_version" >> /etc/hostapd/hostapd.conf
echo "wpa_key_mgmt=WPA-PSK" >> /etc/hostapd/hostapd.conf
echo "wpa_pairwise=TKIP" >> /etc/hostapd/hostapd.conf

sed -i "s/#DAEMON_CONF=\"\"/DAEMON_CONF=\"\/etc\/hostapd\/hostapd.conf\"/g" /etc/default/hostapd

if ! grep -qs '# DSI dhcp server configuration' /etc/dnsmasq.conf ; then
    sed -i "s/#port=5353/port=0/g" /etc/dnsmasq.conf
    sed -i "s/#interface=/interface=wlan/g" /etc/dnsmasq.conf
    sed -i "s/#dhcp-authoritative/dhcp-authoritative/g" /etc/dnsmasq.conf
    sed -i "s/#domain=example.com/domain=dsibridge/g" /etc/dnsmasq.conf
    sed -i "s/#dhcp-range=192.168.0.50,192.168.0.150,255.255.255.0,12h/dhcp-range=192.168.32.50,192.168.32.100,1h/g" /etc/dnsmasq.conf
    echo "" >> /etc/dnsmasq.conf
    echo "# DSI dhcp server configuration" >> /etc/dnsmasq.conf
    echo "" >> /etc/dnsmasq.conf
    echo "# Set Subnet Mask" >> /etc/dnsmasq.conf
    echo "dhcp-option=1,255.255.255.0" >> /etc/dnsmasq.conf
    echo "# Set DNS" >> /etc/dnsmasq.conf
    echo "dhcp-option=6,192.168.32.42" >> /etc/dnsmasq.conf
    echo "# Set Gateway" >> /etc/dnsmasq.conf
    echo "dhcp-option=3,192.168.32.42" >> /etc/dnsmasq.conf
    echo "# Set Router" >> /etc/dnsmasq.conf
    echo "dhcp-option=option:router,192.168.32.42" >> /etc/dnsmasq.conf
    echo "# Set Domain Name" >> /etc/dnsmasq.conf
    echo "dhcp-option=15,dsibridge" >> /etc/dnsmasq.conf
    echo "# Set Broadcast Address" >> /etc/dnsmasq.conf
    echo "dhcp-option=28,192.168.32.255" >> /etc/dnsmasq.conf
    sed -i "s/CONFIG_DIR=\/etc\/dnsmasq.d,.dpkg-dist,.dpkg-old,.dpkg-new/#CONFIG_DIR=\/etc\/dnsmasq.d,.dpkg-dist,.dpkg-old,.dpkg-new/g" /etc/default/dnsmasq
fi

if [ -f /etc/resolv.conf ]; then
   if [ ! -L /etc/resolv.conf ]; then
      chattr -i /etc/resolv.conf
   fi
   rm -f /etc/resolv.conf
fi
echo "nameserver 1.1.1.1" > /etc/resolv.conf
echo "nameserver 8.8.8.8" >> /etc/resolv.conf
chattr +i /etc/resolv.conf
sync

if [ "$1" != "-debug" ]; then
   # disable serial prompt and serial traces
   sed -i "s/rootfstype=auto/rootfstype=ext4 console=tty1/g" /boot/extlinux/extlinux.conf
   sed -i "s/console=tty1/console=tty2/g" /boot/extlinux/extlinux.conf
else
   # enable prompt and traces if '-debug' param
   sed -i "s/rootfstype=ext4 console=tty1/rootfstype=auto/g" /boot/extlinux/extlinux.conf
   sed -i "s/rootfstype=ext4 console=tty2/rootfstype=auto/g" /boot/extlinux/extlinux.conf
fi

if [ -f /home/dsi/.bashrc ]; then
   if ! grep -qs '# Add for DSI' /home/dsi/.bashrc ; then
      echo "" >> /home/dsi/.bashrc
      echo "# Add for DSI" >> /home/dsi/.bashrc
      echo "alias ll='ls -laF'" >> /home/dsi/.bashrc
      echo "PATH=\$PATH:/sbin:/usr/sbin/" >> /home/dsi/.bashrc
      echo "complete -cf sudo" >> /home/dsi/.bashrc
      echo "" >> /home/dsi/.bashrc
   fi
fi
sync

apt-get -y autoremove
apt-get clean

rfkill unblock all

if systemctl list-unit-files | grep enabled | grep serial-getty ; then
    systemctl disable serial-getty@ttymxc0.service
fi

if [ "$1" != "-debug" ]; then
    echo "Update iptable ..."
    bash ./iptables-rules.sh
fi
sync

echo ""
echo "DSI environment ready !"
echo ""
echo "TODO : reboot, log on 'dsi@192.168.22.2' and launch 'sudo deluser --remove-home debian'"
echo ""
