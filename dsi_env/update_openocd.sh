# Update OpenOCD
openocd=$(openocd --version 2>&1 >/dev/null | grep 'On-Chip Debugger 0.10.0')
if [ "$openocd" = "" ]; then
    echo "Update OpenOCD ..."
    sudo apt-get install -y git make libtool pkg-config autoconf automake texinfo libusb-1.0-0 libusb-1.0-0-dev
    git clone -b v0.10.0 --recursive https://github.com/ntfreak/openocd.git
    cd openocd
    ./bootstrap
    ./configure
    make
    make install
    cd -
    rm -rf openocd
    sync
fi
