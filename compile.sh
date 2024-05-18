#!/bin/bash

set -e
#set -x

# Script used to compile linux kernel, module and device-tree
# './compile.sh' to build the kernel and the device-tree
# './compile.sh -jessie to build the kernel for jessie
# './compile.sh zImage' to rebuild the kernel
# './compile.sh dtb' to rebuild the device-tree

# Make sure only user can run our script
if [ "$(id -u)" = "0" ]; then
   echo "This script must *NOT* be run as root" 1>&2
   exit 1
fi

if [ "$1" = "-jessie" ]; then
  if [ ! -f linux-fslc$1/.git/config ]; then
    # source code
    if [ ! -f linux-fslc$1.tar.gz ]; then
      git clone -b 3.14-1.0.x-mx6-sr-next https://github.com/SolidRun/linux-fslc.git linux-fslc$1
      pushd linux-fslc$1
      git checkout 5027a7f8df6fe
      popd
      echo "create tarball linux-fslc$1.tar.gz ..."
      tar -czf linux-fslc$1.tar.gz linux-fslc$1/
    else
      echo "untar linux-fslc$1.tar.gz ..."
      tar -zxf linux-fslc$1.tar.gz
    fi
    pushd linux-fslc$1
    echo "apply patch ..." 
    git apply ../patch/i2c-timeout-jessie.patch
    popd
  fi
  if [ -d build$1 ]; then
    pushd linux-fslc$1
    make O=../build$1 ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- mrproper
    popd
  else
    mkdir build$1
  fi
  pushd linux-fslc$1
  make O=../build$1 ARCH=arm imx_v7_cbi_hb_defconfig
  cp ../config/config-3.14.79-fslc-imx6-sr ../build$1/.config
  sed -i "s/# CONFIG_RTC_SYSTOHC is not set/CONFIG_RTC_SYSTOHC=y\nCONFIG_RTC_SYSTOHC_DEVICE=\"rtc0\"/g" ../build$1/.config
  make -j4 O=../build$1 ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- zImage modules
  popd
  echo "compilation done in /build$1"
  exit 0
fi

if [ "$1" = "" ] || [ "$1" = "-fuses" ] || [ "$1" = "-traces" ] || [ "$1" = "zImage" ] || [ "$1" = "dtb" ] ; then

  if [ "$1" = "-fuses" ] || [ "$1" = "-traces" ] ; then
    param1=$1
  else
    param1=""
  fi

  if [ ! -f linux-fslc/.git/config ] ; then
    # source code
    if [ ! -f linux-fslc.tar.gz ] ; then
      git clone -b solidrun-imx_4.9.x_1.0.0_ga https://github.com/SolidRun/linux-fslc.git
      pushd linux-fslc
      git checkout 3b4f1a2b7c57f
      popd
      echo "create tarball linux-fslc.tar.gz ..."
      tar -czf linux-fslc.tar.gz linux-fslc/
    else
      echo "untar linux-fslc.tar.gz ..."
      tar -zxf linux-fslc.tar.gz
    fi
  fi

  if [ ! -f linux-fslc/arch/arm/boot/dts/imx6dl-bridge-som-v15.dts ] ; then
    cp device-tree/imx6*bridge* linux-fslc/arch/arm/boot/dts/
    # apply patch
    pushd linux-fslc
    git apply ../patch/i2c-timeout.patch
    git apply ../patch/ble-timeout.patch
    git apply ../patch/dts-makefile-dsi.patch
    popd
  fi

  pushd linux-fslc
  if [ ! -f ../build$param1/arch/arm/boot/zImage ] || [ "$1" = "zImage" ] || [ "$2" = "zImage" ] ; then
    if [ ! -f ../build$param1/arch/arm/boot/zImage ] || [ "$2" = "all" ] || [ "$3" = "all" ] ; then
      make O=../build$param1 ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- mrproper
      make O=../build$param1 ARCH=arm imx_v7_cbi_hb_defconfig
      cp ../config/config-4.9.124-imx6-sr ../build$param1/.config
      sed -i "s/# CONFIG_RTC_SYSTOHC is not set/CONFIG_RTC_SYSTOHC=y\nCONFIG_RTC_SYSTOHC_DEVICE=\"rtc0\"/g" ../build$param1/.config
      sed -i "s/CONFIG_CMDLINE=\"noinitrd console=ttymxc0,115200\"/CONFIG_CMDLINE=\"noinitrd\"/g" ../build$param1/.config
    fi
    if [ "$param1" = "-fuses" ] ; then
      sed -i "s/CONFIG_LOCALVERSION=\"-imx6-sr\"/CONFIG_LOCALVERSION=\"-fuses\"/g" ../build$param1/.config
      sed -i "s/# CONFIG_FSL_OTP_RW is not set/CONFIG_FSL_OTP_RW=y/g" ../build$param1/.config
    fi
    if [ "$param1" = "-traces" ] ; then
        cp ../config/config-4.9.124-traces ../build$param1/.config
    fi
    make -j4 O=../build$param1 ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- zImage modules
  fi
  if [ ! -f ../build$param1/arch/arm/boot/dts/imx6dl-bridge-som-v15.dtb ] || [ "$1" = "dtb" ] || [ "$2" = "dtb" ] ; then
    if [ "$1" = "dtb" ] || [ "$2" = "dtb" ] ; then
      cp ../device-tree/imx6*bridge* arch/arm/boot/dts/
    fi
    make O=../build$param1 ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- imx6dl-bridge-som-v15.dtb
  fi
  popd
  echo "compilation done in 'build$param1/' !"
else
  echo "wrong param"
fi
