# install expect
expect_verison=$(expect -v 2>&1 >/dev/null | grep 'expect version')
if [ "$expect_version" = "" ]; then
    echo "Install expect ..."
    sudo apt-get install -y expect
fi
# Build Hardware Test
cd /home/debian/tests/hardware_tests
make clean
make
cd -
