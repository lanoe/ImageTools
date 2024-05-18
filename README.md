# DsiConfigTools

The script "**compile.sh**" cross-compile the official kernel from SolidRun with DemandSideInstruments needs.

--The directory "device-tree" contains the device-tree for DemandSideInstruments.

--The directory "patch" contains the kernel patches.

--The directory "config" contains the kernel config file.

After compilation :

--The directory "linux-fslc" contains the kernel sources.

--The directory "build" is the output dir of compilation.

The script "**update_kernel.sh**" update the SD card (plugged on the host machine) with the new kernel.

Previouly, the SD card have to be flashed with the following Debian Stretch :

```
     wget wget https://images.solid-run.com/IMX6/Debian/sr-imx6-debian-stretch-cli-20180916.img.xz
     unxz sr-imx6-debian-stretch-cli-20180916.img.xz
     sudo dd if=sr-imx6-debian-stretch-cli-20180916.img of=/dev/<sdcard_device> conv=fsync
```

The script "**dsi_update.sh**" update the SD card with DemandSideInstruments tools needed to install the DemandSideInstruments middleware.

The followings DSI modules are pull from git in dsi_src/ :

-- bridge_system_version/

-- 3gManager/

-- DsiBridgeScript/

-- dsi-storage/

-- openocd-flash-utility/

-- SleepModeService/

-- WifiManager/

And the git hash version of each DSI modules are store in bridge_system_version/BRIDGE_SYSTEM_VERSION/version


Once the SD Card is plugged on the board and once your are connected to the board with the user 'debian' (via ssh or serial link), 
you have to launch the script 'dsi_install.sh' to install the whole DemandSideInstruments solution.

After the installation, you have to remove the user 'debian' (deluser --remove-home debian) once connected on the 'dsi' user.


The script "**tools_update.sh**" update the SD card with DemandSideInstruments tools needed to flash and configure the eMMC.


### Dependencies

```
     sudo apt-get install gcc-arm-linux-gnueabihf
```
