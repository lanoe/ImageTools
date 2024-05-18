#!/usr/bin/env bash
# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

power_on() {
  echo 0 > /sys/class/gpio/gpio86/value
  echo 0 > /sys/class/gpio/gpio90/value
  echo 1 > /sys/class/gpio/gpio86/value
  echo 1 > /sys/class/gpio/gpio90/value
  sleep 4
}

power_off() {
  echo 1 > /sys/class/gpio/gpio86/value
  echo 1 > /sys/class/gpio/gpio90/value
  echo 0 > /sys/class/gpio/gpio86/value
  echo 0 > /sys/class/gpio/gpio90/value
  sleep 1
}

if [ ! -L /sys/class/gpio/gpio86 ] && [ ! -L /sys/class/gpio/gpio90 ]; then
  echo 86 > /sys/class/gpio/export
  echo 90 > /sys/class/gpio/export
  echo out > /sys/class/gpio/gpio86/direction
  echo out > /sys/class/gpio/gpio90/direction
fi

case "$1" in 
  on)   power_on ;;
  off)  power_off ;;
  *) echo "usage: $0 on|off" >&2
    exit 1
    ;;
esac
