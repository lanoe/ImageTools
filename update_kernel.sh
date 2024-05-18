#!/bin/bash

set -e
#set -x

# Make sure only user can run our script
if [ "$(id -u)" = "0" ]; then
   echo "This script must *NOT* be run as root" 1>&2
   exit 1
fi

export SDCARD_ROOTFS=/media/$USER/rootfs

# For tests
#sudo rm -rf rootfs/
#mkdir -p rootfs/boot/extlinux/
#mkdir -p rootfs/lib/modules/
#export SDCARD_ROOTFS=$PWD/rootfs

if [ ! -f $SDCARD_ROOTFS/boot/config-3.14.79-fslc-imx6-sr ] && [ ! -f $SDCARD_ROOTFS/boot/config-4.9.124-imx6-sr ]; then
  echo "Debian version is NOT on SD card !"
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

if [ "$1" = "" ] || [ "$1" = "-fuses" ] || [ "$1" = "-traces" ] || [ "$1" = "-jessie" ] ; then

  echo "Update kernel ..."

  export KERNEL_V=$(cat build$1/include/config/kernel.release)

  sudo rm -f $SDCARD_ROOTFS/boot/zImage-$KERNEL_V
  sudo rm -f $SDCARD_ROOTFS/boot/config-$KERNEL_V
  sudo rm -f $SDCARD_ROOTFS/boot/System.map-$KERNEL_V

  if [ "$1" = "-jessie" ] ; then
    if [ ! -f $SDCARD_ROOTFS/boot/config-3.14.79-fslc-imx6-sr ]; then
        echo "Debian version on SDCard is not Jessie version !"
        exit 1
    fi
    pushd linux-fslc$1
  else
    if [ ! -f $SDCARD_ROOTFS/boot/config-4.9.124-imx6-sr ]; then
        echo "Debian version on SDCard is not Stretch version !"
        exit 1
    fi
    pushd linux-fslc
  fi

  sudo make O=../build$1 INSTALL_PATH=$SDCARD_ROOTFS/boot ARCH=arm install
  popd
  sudo rm -f $SDCARD_ROOTFS/boot/vmlinuz-$KERNEL_V

  sudo cp build$1/arch/arm/boot/zImage $SDCARD_ROOTFS/boot/zImage-$KERNEL_V
  sudo rm -f $SDCARD_ROOTFS/boot/zImage && cd $SDCARD_ROOTFS/boot/ && sudo ln -s zImage-$KERNEL_V zImage && cd -

  sudo rm -rf $SDCARD_ROOTFS/$KERNEL_V && sudo rm -rf $SDCARD_ROOTFS/lib/firmware/$KERNEL_V && sudo rm -rf $SDCARD_ROOTFS/lib/modules/$KERNEL_V
  sudo mkdir -p $SDCARD_ROOTFS/$KERNEL_V && sudo mkdir -p $SDCARD_ROOTFS/lib/firmware/$KERNEL_V
  if [ "$1" = "-jessie" ] ; then
    pushd linux-fslc$1
  else
    pushd linux-fslc
  fi
  sudo make O=../build$1 INSTALL_MOD_PATH=$SDCARD_ROOTFS/$KERNEL_V ARCH=arm modules_install
  popd
  sudo mv $SDCARD_ROOTFS/$KERNEL_V/lib/modules/$KERNEL_V -t $SDCARD_ROOTFS/lib/modules/.
  sudo cp -rf $SDCARD_ROOTFS/$KERNEL_V/lib/firmware/. $SDCARD_ROOTFS/lib/firmware/$KERNEL_V/.
  sudo rm -rf $SDCARD_ROOTFS/$KERNEL_V

  if [ "$1" = "-jessie" ] ; then
    echo "Update for Jessie ..."
    sudo cp $SDCARD_ROOTFS/boot/dtb/imx6dl-cubox-i-som-v15.dtb $SDCARD_ROOTFS/boot/imx6dl-dsibridge-som-v15.dtb
    echo "fdt_file=imx6dl-dsibridge-som-v15.dtb" > uEnv.txt
    echo "mmcroot=/dev/mmcblk0p1 rootwait rw" >> uEnv.txt
    echo "mmcargs=setenv bootargs console=ttymxc0,115200n8 console=tty root=\${mmcroot} quiet" >> uEnv.txt
    echo "bootloader-knows-about-dtb-subfolder=yes" >> uEnv.txt
    sudo cp uEnv.txt $SDCARD_ROOTFS/boot/.
  else
    echo "Update for Stretch ..."

    sudo cp build$1/arch/arm/boot/dts/imx6dl-bridge-som-v15.dtb $SDCARD_ROOTFS/boot/.
#    if [ "$1" = "-fuses" ] ; then
#      echo "# https://wiki.solid-run.com/doku.php?id=products:imx6:microsom:imx6-fuse-developers&s[]=efuses" > fuse_boot_from_sdcard.sh
#      echo "echo 0x2840 > /sys/fsl_otp/HW_OCOTP_CFG4" >> fuse_boot_from_sdcard.sh
#      echo "echo 0x10 > /sys/fsl_otp/HW_OCOTP_CFG5" >> fuse_boot_from_sdcard.sh
#      sudo cp fuse_boot_from_sdcard.sh $SDCARD_ROOTFS/root/.
#    fi

    echo "TIMEOUT 0" > extlinux.conf
    echo "LABEL default" >> extlinux.conf
    echo "	LINUX ../zImage" >> extlinux.conf
    echo "	INITRD ../initrd" >> extlinux.conf
    echo "	FDT /boot/imx6dl-bridge-som-v15.dtb" >> extlinux.conf

    current_uuid=$(sudo blkid | sudo grep /dev/$partition | sudo awk '{print $3}')
    current_uuid=${current_uuid:6:-1}

    if [ "$1" = "-traces" ] ; then
      echo "	APPEND root=UUID=$current_uuid rootfstype=auto rootwait debug" >> extlinux.conf
      sudo sed -i "s/kernel.printk = 3 4 1 3/kernel.printk = 7 4 1 3/g" $SDCARD_ROOTFS/etc/sysctl.conf 
    else
      echo "	APPEND root=UUID=$current_uuid rootfstype=auto rootwait quiet" >> extlinux.conf
    fi
    sudo cp extlinux.conf $SDCARD_ROOTFS/boot/extlinux/.

    if ! grep -qs $current_uuid $SDCARD_ROOTFS/etc/fstab ; then
        echo "!!! ERROR !!! UUID=$current_uuid is not set in $SDCARD_ROOTFS/etc/fstab ..."
    fi
  fi

  sync
  umount $SDCARD_ROOTFS
  udisksctl power-off -b /dev/$disk
  echo "sdcard ready !"
else
  echo "wrong param"
fi
