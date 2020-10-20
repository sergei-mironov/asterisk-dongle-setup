#!/bin/sh

set -e -x

nix-build -A asterisk -o result-asterisk -K
nix-build -A asterisk-conf -o result-conf

sudo rm -rf /tmp/asterisk || true
sudo mkdir /tmp/asterisk

sudo ./result-asterisk/bin/asterisk -C `pwd`/result-conf/etc/asterisk/asterisk.conf -c -f -ddddddd -vvvvvvvvv
# ltrace -s 500 -A 1000 ./result-asterisk/bin/asterisk -C `pwd`/result-conf/etc/asterisk/asterisk.conf -f -ddd 2> ltrace.log
# ./result-asterisk/bin/asterisk -C `pwd`/asterisk.conf -c -f -ddd
