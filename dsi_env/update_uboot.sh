# https://developer.solid-run.com/knowledge-base/i-mx6-u-boot/
# First Boot Image
SPL=/home/debian/uboot-tools/SPL-dsi
# Second Boot Image
UBOOT=/home/debian/uboot-tools/u-boot-dsi.img
if [ "$1" = "" ]; then
  disk=mmcblk0
else
  disk=$1
fi
# Remove UBoot traces
echo "silent 1" > /tmp/script.txt
# Remove UBoot prompt
echo "bootdelay -2" >> /tmp/script.txt
# Update UBoot variables
if [ "$disk" = "mmcblk0" ]; then
  # set mmcblk0 for sdcard
  /home/debian/uboot-tools/fw_setenv -c /home/debian/uboot-tools/fw_env-mSata.config --script /tmp/script.txt
fi
if [ "$disk" = "mmcblk2" ]; then
  # set mmcblk2 for emmc
  /home/debian/uboot-tools/fw_setenv -c /home/debian/uboot-tools/fw_env-eMMC.config --script /tmp/script.txt
fi
# Update Boot Images
if [ "$disk" = "mmcblk0" ] || [ "$disk" = "mmcblk2" ]; then 
  echo "Write SPL on /dev/$disk ..."
  dd if=$SPL of=/dev/$disk bs=1k seek=1 conv=sync
  echo "Write UBoot on /dev/$disk ..."
  dd if=$UBOOT of=/dev/$disk bs=1k seek=69 conv=sync
else
  echo "Write Boot on /dev/$disk failed !"
fi
