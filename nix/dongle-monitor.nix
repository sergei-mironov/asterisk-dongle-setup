{ pkgs ? import <nixpkgs> {}
, stdenv ? pkgs.stdenv
, secrets
, usb_modeswitch
}:
let
  inherit (secrets) dongle_device_data;
in
pkgs.writeShellScriptBin "dongle-monitor" ''
  try_to_deal_with() {
    vendor="$1"
    product="$2"
    if lsusb | grep -q "$vendor:$product" ; then
      sudo ${usb_modeswitch}/usr/sbin/usb_modeswitch -v "$vendor" -p "$product" -X
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
      sleep 1
      ncheck=`expr $ncheck - 1`
      if test "$ncheck" = "0" ; then
        return 1
      fi
    done
    return 0
  }

  MODE=seek
  DEVICE="${dongle_device_data}"
  while true ; do
    try_to_deal_with "12d1" "1446" && wait_for_chardev "$DEVICE"

    if test -c "$DEVICE" ; then
      if test "$MODE" = "seek" ; then
        echo "Going to standby mode" >&2
      fi
      MODE=standby
      sleep 1
    else
      echo "Can't make $DEVICE to appear. Did you plugg-in the supported GSM "\
           "modem? Consider reviewing and updating this script "\
           "(\`./nix/donlge-monitor.nix\`)." >&2
      sleep 5
      MODE=seek
    fi
  done
''
