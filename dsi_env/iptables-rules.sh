#!/bin/bash

# Flush existing rules
iptables -F

# Default policies to DROP
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

# Allow loopback access
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Allow SSH communications on eth, wlan and vpn
iptables -A INPUT -p tcp --dport 22 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT

# Allow pings (example: 3g manager connection tests)
iptables -A OUTPUT -p icmp -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p icmp -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

# Allow communication via MQTT over ppp0 (ascending and descending)
iptables -A OUTPUT -o ppp0 -p tcp --dport 8443 -m state --state NEW,ESTABLISHED  -j ACCEPT
iptables -A INPUT -i ppp0 -p tcp --sport 8443 -m state --state ESTABLISHED -j ACCEPT

# Allow communication over VPN
iptables -A OUTPUT -p tcp -m multiport --dports 1194,1195 -j ACCEPT
iptables -A INPUT -p tcp -m multiport --sports 1194,1195 -j ACCEPT

# Allow DHCP requests
iptables -A INPUT -p udp -i wlan --dport 67:68 --sport 67:68 -j ACCEPT
iptables -A OUTPUT -p udp -o wlan --sport 67:68 --dport 67:68 -j ACCEPT

# Allow outbound DNS communication
iptables -A OUTPUT -p udp --dport 53 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A INPUT -p udp --sport 53 -m state --state ESTABLISHED -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A INPUT -p tcp --sport 53 -m state --state ESTABLISHED -j ACCEPT

# Allow NTP communication
iptables -A OUTPUT -p udp --dport 123 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A INPUT -p udp --sport 123 -m state --state ESTABLISHED -j ACCEPT

# Allow access to 3g_manager_rest app
iptables -A INPUT -p tcp --dport 5001 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -p tcp --sport 5001 -m state --state ESTABLISHED -j ACCEPT

# Allow access to Openmuc dashboard
iptables -A INPUT -p tcp --dport 8888 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -p tcp --sport 8888 -m state --state ESTABLISHED -j ACCEPT

# Allow access to modbus table
iptables -A INPUT -p tcp --dport 502 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -p tcp --sport 502 -m state --state ESTABLISHED -j ACCEPT

# Save rules
iptables-save > /etc/iptables/rules.v4
iptables-save > /etc/iptables/rules.v6

exit 0

