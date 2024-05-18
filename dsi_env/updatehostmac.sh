#!/bin/bash

set -e 
#set -x

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

echo "--> CHECK ETHERNET MAC ADDRESS ..."

HW_OCOTP_CFG4=$(cat /sys/fsl_otp/HW_OCOTP_CFG4)
HW_OCOTP_CFG5=$(cat /sys/fsl_otp/HW_OCOTP_CFG5)
echo "HW_OCOTP_CFG4=$HW_OCOTP_CFG4 / HW_OCOTP_CFG5=$HW_OCOTP_CFG5"

if [ "$HW_OCOTP_CFG4" = "0x1060" ] ; then
  echo "fuses emmc"
  /home/debian/uboot-tools/fw_setenv -c /home/debian/uboot-tools/fw_env-eMMC.config ethaddr
fi

if [ "$HW_OCOTP_CFG4" = "0x2840" ] ; then
  echo "fuses sdcard"
  /home/debian/uboot-tools/fw_setenv -c /home/debian/uboot-tools/fw_env-mSATA.config ethaddr
fi

if [ "$HW_OCOTP_CFG4" = "0x0" ] ; then
  echo "no fuses"
  /home/debian/uboot-tools/fw_setenv -c /home/debian/uboot-tools/fw_env-eMMC.config ethaddr
  /home/debian/uboot-tools/fw_setenv -c /home/debian/uboot-tools/fw_env-mSata.config ethaddr
fi

HW_OCOTP_MAC0=$(cat /sys/fsl_otp/HW_OCOTP_MAC0)
HW_OCOTP_MAC1=$(cat /sys/fsl_otp/HW_OCOTP_MAC1)

echo "HW_OCOTP_MAC0=$HW_OCOTP_MAC0 / HW_OCOTP_MAC1=$HW_OCOTP_MAC1"

if [ "$HW_OCOTP_MAC0" = "0x0" ] ; then
  echo "--> UPDATE ETHERNET MAC ADDRESS ..."
  hexchars="0123456789ABCDEF"
  mac_rand=$( for i in {1..6} ; do echo -n ${hexchars:$(( $RANDOM % 16 )):1} ; done | sed -e 's/\(..\)/\1/g' )
  mac_end="0xB4$mac_rand"
  echo "MAC_RAND=$mac_rand"
  echo "0xD063" > /sys/fsl_otp/HW_OCOTP_MAC1
  echo "$mac_end" > /sys/fsl_otp/HW_OCOTP_MAC0
  HW_OCOTP_MAC0=$(cat /sys/fsl_otp/HW_OCOTP_MAC0)
  HW_OCOTP_MAC1=$(cat /sys/fsl_otp/HW_OCOTP_MAC1)
fi

echo "--> UPDATE HOSTNAME ..."
HW_OCOTP_MAC0=${HW_OCOTP_MAC0#*0x} # remove '0x'
HW_OCOTP_MAC1=${HW_OCOTP_MAC1#*0x} # remove '0x'
mac="$HW_OCOTP_MAC1$HW_OCOTP_MAC0"
mac_rand=${mac:6:6}

old_hostname=$(sudo cat /etc/hostname)
new_hostname="dsi-$mac_rand"
sed -i "s/$old_hostname/$new_hostname/g" /etc/hosts
sed -i "s/$old_hostname/$new_hostname/g" /etc/hostname

echo "-----------------------------------------------------------"
echo " ETHERNET MAC ADDRESS : $mac"
echo "-----------------------------------------------------------"
echo " HOSTNAME : $new_hostname"
echo "-----------------------------------------------------------"
echo " ! Please restart the board !"
echo " > connect with command 'ssh debian@$new_hostname'"
echo " > check the mac address with command 'ifconfig' on eth0 ! "
echo "-----------------------------------------------------------"
