# Update ofono
target_ofono=1.28
current_ofono=$(ofonod --version)
if [ "$target_ofono" != "$current_ofono" ]; then
    echo "Update ofono version $target_ofono ..."
    apt-get -y update
    git clone git://git.kernel.org/pub/scm/libs/ell/ell.git
    git clone git://git.kernel.org/pub/scm/network/ofono/ofono.git
    cd ofono
    git checkout tags/$target_ofono
    apt install -y automake build-essential libtool mobile-broadband-provider-info glib2.0 libdbus-1-dev libudev-dev
    ./bootstrap
    ./configure --enable-debug --prefix=/usr --mandir=/usr/share/man --sysconfdir=/etc --localstatedir=/var --enable-test --enable-tools --enable-provision
    make
    make install
    cd -
    rm -rf ell ofono
    #sed -i "s/After=dbus.service network-pre.target systemd-sysusers.service/After=dbus.service network-pre.target systemd-sysusers.service ofono.service/g" /lib/systemd/system/connman.service
    sed -i "s/After=dbus.service network-pre.target systemd-sysusers.service ofono.service/After=dbus.service network-pre.target systemd-sysusers.service/g" /lib/systemd/system/connman.service
    sed -i "s/StandardError=null/StandardError=null\nRestart=always/g" /lib/systemd/system/ofono.service
    sync
    systemctl disable ofono.service
    #systemctl enable ofono.service
    systemctl stop ofono.service
    #systemctl start ofono.service
fi
