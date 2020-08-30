Asterisk-dongle-setup
=====================

In this playground project we try to setup Asterisk server to work with
[GSM-modem dongle](https://github.com/wdoekes/asterisk-chan-dongle) using
[Nix](https://nixos.org) package manager.

The project aims at automating the configuration of software able to solve the following
tasks:

* Receive SMS messages and re-send them to a messanger bot.
* Handle voice calls with voice menu.
* Handle voice calls with a chat bot.

Setup
=====

0. `nix-info` Make sure you have [Nix package manager](https://nixos.org/nix) installed.
1. `git clone --recursive <this-repo-url> ; cd ...`
2. Apply [./0001-asterisk-1.7.patch](./0001-asterisk-1.7.patch) patch to your
   local nixpkgs. We use [20.03 Nixpkgs tree](https://github.com/NixOS/nixpkgs/tree/076c67fdea6d0529a568c7d0e0a72e6bc161ecf5/) as base.
3. If your USB dongle is not in modem mode by default, build and use
   [usb_modeswitch](https://www.draisberghof.de/usb_modeswitch/) `nix-build -A usb_modeswitch`.
4. Run the wrapper script `./asterisk.sh`
5. ???
6. Continue hacking

Hardware
========

We use the following USB dongle:


```
$ lsusb
...
Bus 001 Device 104: ID 12d1:1001 Huawei Technologies Co., Ltd.  E161/E169/E620/E800 HSDPA Modem
...
```

```
*CLI> dongle show devices
ID           Group State      RSSI Mode Submode Provider Name  Model      Firmware          IMEI             IMSI             Number        
dongle0      0     Free       16   0    0       Beeline        E303C      22.157.18.00.00   *************    ************     Unknown
```

See also [somewhat outdated list of supported devices](https://github.com/bg111/asterisk-chan-dongle/wiki/Requirements-and-Limitations)

Issues
======


* ~~https://github.com/wdoekes/asterisk-chan-dongle/issues/109~~
* ~~https://github.com/wdoekes/asterisk-chan-dongle/issues/110~~


References
==========

* GSMCTL https://www.unix.com/man-page/debian/8/gsmctl/
  - Homepage looks inactive
* MMCLI https://www.freedesktop.org/software/ModemManager/man/1.0.0/mmcli.8.html
