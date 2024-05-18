# Update OpenVPN
if ! which openvpn > /dev/null; then
    echo "Install OpenVPN ..."
    apt-get -y install openvpn
    ssh-keyscan serv-dev4.dsinstruments.fr >> $HOME/.ssh/known_hosts
fi
openvpn=$(openvpn --version | grep OpenVPN | grep OpenSSL | awk '{print $2}')
echo "OpenVPN version : $openvpn"

