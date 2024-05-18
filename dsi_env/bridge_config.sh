#!/bin/bash

set -e 
#set -x

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
    echo "Failed : This script must be run as root" 1>&2
    exit 1
fi

mount_path=/media/emmc_rootfs
openvpn_path=$mount_path/etc/openvpn/

board_type=$1     # 'BLETranslator' or 'Bridge'
serial_number=$2  # [0-9]
configure_vpn=$3  # 'true'

if [ "$board_type" != "BLETranslator" ] && [ "$board_type" != "Bridge" ]; then
   echo "Failed : Invalid board type '$board_type' !"
   exit 1
fi

# Check Bridge Informations
if [ "$board_type" = "Bridge" ]; then
   if [ ! -f /tmp/bridge_info.json ]; then
      echo "Failed : No bridge infos !"
      exit 1
   else
      dsiSN=$(grep -Po '"dsiSN":.*?[^\\],' /tmp/bridge_info.json) && dsiSN=${dsiSN::-1}
      dsiSN=$(echo "${dsiSN/:/ }" | awk '{ print $2 }') && dsiSN=$(echo "${dsiSN//\"}")
      jwt=$(grep -Po '"jwt":.*?[^\\],' /tmp/bridge_info.json) && jwt=${jwt::-1}
      jwt=$(echo "${jwt/:/ }" | awk '{ print $2 }') && jwt=$(echo "${jwt//\"}")
      id=$(grep -Po '"id":.*?[^\\],' /tmp/bridge_info.json) && id=${id::-1}
      id=$(echo "${id/:/ }" | awk '{ print $2 }') && id=$(echo "${id//\"}")

      if [ "$dsiSN" != "$serial_number" ]; then
         echo "Failed : Invalid bridge serial number ! '$dsiSN' or '$serial_number' ?"
         exit 1
      fi
   fi
fi

# Check Hardware version
check_hardware=$(lsusb | grep "04b4:6572 Cypress Semiconductor" | awk '{print $6 $7 $8}')
if [ "$check_hardware" = "04b4:6572CypressSemiconductor" ]; then
   echo "Configure $board_type (hardware v3) with SN=$serial_number ..."
   hardware_version="v3"
else
   echo "Configure $board_type with SN=$serial_number ..."
   hardware_version=""
fi

# Update VPN
if [ "$configure_vpn" != "" ]; then
  echo "Ask for VPN keys generation ..."
  server=serv-prod1.dsinstruments.fr
  user=vpncreator
  ssh_command="/opt/vpn_tcp/make_openvpn_key.sh Bridge_$serial_number"
  known_server=$(cat /root/.ssh/known_hosts | grep $server)
  if [ "$known_server" = "" ]; then
     ssh-keyscan >> /root/.ssh/known_hosts  
  fi
  ssh $user@$server $ssh_command
  echo "Get VPN client keys ..."
  mkdir -p /tmp/Bridge_$serial_number
  scp $user@$server:/opt/vpn_tcp/Bridge_$serial_number/* /tmp/Bridge_$serial_number/.
fi

bash /home/debian/script/disk.sh mount

if [ "$configure_vpn" != "" ]; then
  echo "Configure VPN client ..."
  if [ ! -d $openvpn_path ]; then
    echo "Failed : no path to $openvpn_path !"
    exit 1
  fi
  echo "Copy VPN keys ..."
  cp -f /tmp/Bridge_$serial_number/* $openvpn_path/.
  sync
  if [ ! -f $openvpn_path/Bridge_$serial_number.crt ]; then
    echo "Failed : No file $openvpn_path/Bridge_$serial_number.crt"
  fi
  if [ ! -f $openvpn_path/Bridge_$serial_number.csr ]; then
    echo "Failed : No file $openvpn_path/Bridge_$serial_number.csr"
  fi
  if [ ! -f $openvpn_path/Bridge_$serial_number.key ]; then
    echo "Failed : No file $openvpn_path/Bridge_$serial_number.key"
  fi
  if [ ! -f $openvpn_path/ca.crt ]; then
    echo "Failed : No file $openvpn_path/ca.crt"
  fi
  if [ ! -f $openvpn_path/client.conf ]; then
    echo "Failed : No file $openvpn_path/client.conf"
  fi
  #echo "Activate VPN client services ..."
  #cd $mount_path/etc/systemd/system/multi-user.target.wants
  #ln -s openvpn@client.service openvpn.service
else
  if [ -d $openvpn_path ]; then
      echo "Remove VPN client files ..."
      rm -f $openvpn_path/Bridge_*
      rm -f $openvpn_path/ca.crt
      rm -f $openvpn_path/client.conf
  fi
  #echo "Desactivate VPN client services ..."
  #cd $mount_path/etc/systemd/system/multi-user.target.wants
  #rm -f openvpn@client.service openvpn.service
fi

# Update Hostname
old_hostname=$(cat $mount_path/etc/hostname)
new_hostname=$board_type$serial_number
echo "Update 'hostname' to '$new_hostname' ..." 
sed -i "s/$old_hostname/$new_hostname/g" $mount_path/etc/hosts
sed -i "s/$old_hostname/$new_hostname/g" $mount_path/etc/hostname

# Update Bridge config
if [ "$board_type" = "Bridge" ]; then
  echo "Update $mount_path/home/dsi/DsiBridge/config/default.conf ..."
  cd $mount_path/home/dsi/DsiBridge/config/
  if [ ! -f default.old ]; then 
    cp default.cfg default.old
  fi

  bridge_id=$(cat /tmp/bridge.cfg | grep bridge_id | awk '{ print $3 }')
  echo "Set 'bridge_id' to '$bridge_id' ..."
  if [ "$id" != "$bridge_id" ]; then
     echo "Failed : Invalid bridge guid ! '$id' or '$bridge_id' ?"
     exit 1
  fi
  sed -i "s/\(bridge_id *= *\).*/\1$bridge_id/g" default.cfg

  ip_address=$(cat /tmp/bridge.cfg | grep ip_address | awk '{ print $3 }')
  echo "Set 'ip_address' to '$ip_address' ..."
  sed -i "s/\(ip_address *= *\).*/\1$ip_address/g" default.cfg

  polling_interval=$(cat /tmp/bridge.cfg | grep polling_interval | awk '{ print $3 }')
  echo "Set 'polling_interval' to '$polling_interval' ..."
  sed -i "s/\(polling_interval *= *\).*/\1$polling_interval/g" default.cfg

  # Update Amber port selection
  read_from_amber_dongle=$(cat /tmp/bridge.cfg | grep read_from_amber_dongle | awk '{ print $3 }')
  echo "Set 'read_from_amber_dongle' to '$read_from_amber_dongle' ..."
  sed -i "s/\(read_from_amber_dongle *= *\).*/\1$read_from_amber_dongle/g" default.cfg

  # Update Amber port
  amber_port=$(cat /tmp/bridge.cfg | grep amber_dongle_port | awk '{ print $3 }')
  echo "Set 'amber_dongle_port' to '$amber_port' ..."
  amber_dongle_port=$(echo "${amber_port//\//\\/}") # replace '/' by '\/' for sed
  sed -i "s/\(amber_dongle_port *= *\).*/\1$amber_dongle_port/g" default.cfg
  check=$(cat default.cfg | grep amber_dongle_port | awk '{ print $3 }')
  if [ "$check" != "$amber_port" ]; then
    echo "Failed to change 'amber_dongle_port' write '$check' instead of '$amber_port' !"
    exit 1
  fi

  if [ "$read_from_amber_dongle" = "True" ]; then
    echo "Configure Amber on $amber_port ..."
    echo "Set RF_Channel to 2"
    /home/debian/tests/hardware_tests/testAmber $amber_port 60 2
    echo "Set Mode_Preselect to 8"
    /home/debian/tests/hardware_tests/testAmber $amber_port 70 8
    echo "Set UART_CMD_Out_enable to 0"
    /home/debian/tests/hardware_tests/testAmber $amber_port 5 0
    echo "Set RSSI_Enable to 1"
    /home/debian/tests/hardware_tests/testAmber $amber_port 69 1
    echo $amber_port > /tmp/amber_interface
  fi

  # Update jwt password
  pwd_jwt=$(cat /tmp/bridge.cfg | grep password | awk '{ print $3 }')
  echo "Set jwt 'password' to '$pwd_jwt' ..."
  if [ "$jwt" != "$pwd_jwt" ]; then
     echo "Failed : Invalid jwt ! '$jwt' or '$password' ?"
     exit 1
  fi
  password=$(echo "${pwd_jwt//\//\\/}") # replace '/' by '\/' for sed
  password=$(echo "${password//$/\\$}") # replace '$' by '\$' for sed
  sed -i "s/authentication_password/authentication_pwd/g" default.cfg
  sed -i "s/\(password *= *\).*/\1$password/g" default.cfg
  check=$(cat default.cfg | grep password | awk '{ print $3 }')
  sed -i "s/authentication_pwd/authentication_password/g" default.cfg
  if [ "$check" != "$pwd_jwt" ]; then
     echo "Failed to change 'password' write '$check' instead of '$pwd_jwt' !"
     exit 1
  fi
  sync
  #diff default.cfg default.old
fi

# Update Bridge V3
if [ "$hardware_version" = "v3" ]; then
  echo "Update specific v3 gpio in $mount_path/home/dsi/DsiBridge/config/default.conf ..."
  cd $mount_path/home/dsi/DsiBridge/config/
  if [ ! -f default.new ]; then 
    cp default.cfg default.new
  fi
  dongle_master_gpio=70
  echo "Set 'dongle_master_gpio' to '$dongle_master_gpio' ..."
  sed -i "s/\(dongle_master_gpio *= *\).*/\1$dongle_master_gpio/g" default.cfg

  dongle_master_reset_gpio=73
  echo "Set 'dongle_master_reset_gpio' to '$dongle_master_reset_gpio' ..."
  sed -i "s/\(dongle_master_reset_gpio *= *\).*/\1$dongle_master_reset_gpio/g" default.cfg

  usb_port_1_2_gpio=86
  echo "Set 'usb_port_1_2_gpio' to '$usb_port_1_2_gpio' ..."
  sed -i "s/\(usb_port_1_2_gpio *= *\).*/\1$usb_port_1_2_gpio/g" default.cfg
  sync
  #diff default.cfg default.new
fi

# Update BLE Translator
if [ "$board_type" = "BLETranslator" ]; then
  echo "Update Lora config file $mount_path/home/dsi/DsiBridge/test_application/control_lora.cfg ..."
  cd $mount_path/home/dsi/DsiBridge/test_application/
  if [ ! -f control_lora.old ]; then
    cp control_lora.cfg control_lora.old
  fi

  PowerLevel=14
  echo "Set 'PowerLevel' to '$PowerLevel' ..."
  sed -i "s/\(PowerLevel *= *\).*/\1$PowerLevel/g" control_lora.cfg
  sync
  #diff control_lora.cfg control_lora.old

  echo "Update services ..."
  cd $mount_path/etc/systemd/system/multi-user.target.wants
  echo "Remove link to Bridge services (3g_manager/BNM/DsiBridge/Gateway/SystemWatchdog/VersionServer) ..."
  rm -f 3g_manager_rest.service 3g_manager.service BNM.service DsiBridge.service Gateway.service SystemWatchdog.service VersionServer.service 
  if [ ! -L BLETranslator.service ]; then
    echo "Create link to BLETranslator.service ..."
    ln -s /etc/systemd/system/BLETranslator.service BLETranslator.service
  fi
  echo "Desactivate VPN client services ..."
  rm -f openvpn@client.service openvpn.service
  sync
fi

# Update WifiAP

echo "Update Wifi Access Point file $mount_path/etc/hostapd/hostapd.conf ..."
cd $mount_path/etc/hostapd/
if [ ! -f hostapd.old ]; then
  cp hostapd.conf hostapd.old
fi

ssid="BNet_$board_type$serial_number"
echo "Set 'ssid' to '$ssid' ..."
sed -i "s/\(ssid *= *\).*/\1$ssid/g" hostapd.conf

wpa_passphrase="wifi@D\$i$board_type$serial_number"
echo "Set 'wpa_passphrase' to '$wpa_passphrase' ..."
sed -i "s/\(wpa_passphrase *= *\).*/\1$wpa_passphrase/g" hostapd.conf
sync

#diff hostapd.conf hostapd.old

cd /home/debian
bash /home/debian/script/disk.sh umount

echo "Configuration done !"
