#!/bin/sh

set -e -x

ME=`basename $0`

nix-build -A asterisk -o result-asterisk -K
nix-build -A asterisk-conf -o result-conf

try_to_deal_with() {
  vendor="$1"
  product="$2"
  if lsusb | grep -q "$vendor:$product" ; then
    sudo ./result-modeswitch/usr/sbin/usb_modeswitch -v "$vendor" -p "$product" -X
    sleep 0.5
    return 0
  else
    return 1
  fi
}

wait_for_chardev() {
  device=$1
  ncheck=10
  while ! test -c "$device" ; do
    echo -n .
    sleep 0.5
    ncheck=`expr $ncheck - 1`
    if test "$ncheck" = "0" ; then
      return 1
    fi
  done
  return 0
}

DEVICE="/dev/ttyUSB0"
try_to_deal_with "12d1" "1446" && wait_for_chardev "$DEVICE"

if ! test -c "$DEVICE" ; then
  echo "Can't make $DEVICE to appear. Did you plugged-in the supported GSM "\
       "modem? Consider reviewing and updating this script (\`$0\`)."
  exit 1
fi

sudo rm -rf /tmp/asterisk || true
sudo mkdir /tmp/asterisk

sudo ./result-asterisk/bin/asterisk -C `pwd`/result-conf/etc/asterisk/asterisk.conf -c -f -vvvvvvvvv
# ltrace -s 500 -A 1000 ./result-asterisk/bin/asterisk -C `pwd`/result-conf/etc/asterisk/asterisk.conf -f -ddd 2> ltrace.log
# ./result-asterisk/bin/asterisk -C `pwd`/asterisk.conf -c -f -ddd
