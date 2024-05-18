# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

if [ "$1" = "" ]; then
    echo "Failed : the script need a param !"
else
    if [ ! -f /etc/openvpn/client/$1.conf ]; then
      # get certificate from dev4
      scp vpnclient@serv-dev4.dsinstruments.fr:/usr/share/vpnclient/$1.conf /etc/openvpn/client/$1.conf
    fi
    # launch openVPN client
    systemctl start openvpn-client@$1
    ip=$(ifconfig tap0 | grep broadcast | awk '{ print $2 }')
    echo "IP ADDRESS : $ip"
fi


