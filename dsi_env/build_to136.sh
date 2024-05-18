# Build library for TO136
if [ ! -f /lib/libTO.so ] || [ ! -f /lib/libTO_i2c_wrapper.so ]; then
    echo "Update TO136 library ..."
    cd /home/debian/dsi-storage/libto
    rm -rf build; mkdir build
    autoreconf -f -i
    cd build
    ../configure i2c=linux_generic i2c_dev=/dev/i2c-2 --prefix=/
    make
    make install
    cd /home/debian
fi
