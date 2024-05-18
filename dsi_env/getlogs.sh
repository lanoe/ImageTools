bridge=$(cat /etc/hostname)
current=$PWD
cd /var/log/.
tar -cvf $current/logs-$bridge.tar --absolute-names *
cd $current
cat BRIDGE_SYSTEM_VERSION/version.txt > infos.log
uname -a >> infos.log
timedatectl >> infos.log
lsblk --fs >> infos.log
cat /boot/extlinux/extlinux.conf >> infos.log
df -h >> infos.log
ip link >> infos.log
ifconfig >> infos.log
lsusb >> infos.log
lsmod >> infos.log
rfkill list >> infos.log
systemctl status >> infos.log
ps -aux >> infos.log
free >> infos.log
tar -uvf logs-$bridge.tar --absolute-names *log
gzip -f logs-$bridge.tar
rm -f infos.log
