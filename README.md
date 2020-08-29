Asterisk-dongle-setup
=====================

In this playground project we try to setup Asterisk server to work with
[GSM-modem dongle](https://github.com/wdoekes/asterisk-chan-dongle) using
[Nix](https://nixos.org) package manager.

* We use recent
  [20.03 Nixpkgs tree](https://github.com/NixOS/nixpkgs/tree/076c67fdea6d0529a568c7d0e0a72e6bc161ecf5/)


Usage
=====

0. `nix-info` # Make sure you have Nix installed
1. `git clone <this-repo-url> ; cd ...`
2. Apply [./0001-asterisk-1.7.patch](./0001-asterisk-1.7.patch) patch to your
   local nixpkgs.
3. If the USB dongle is not in modem mode by default, build and use
   usb_modeswitch: `nix-build -A usb_modeswitch`
3. `./asterisk.sh`
4. ???
5. Continue hacking


Issues
======


* ~~https://github.com/wdoekes/asterisk-chan-dongle/issues/109~~
* https://github.com/wdoekes/asterisk-chan-dongle/issues/110


References
==========

* GSMCTL https://www.unix.com/man-page/debian/8/gsmctl/
  - Homepage looks inactive
* MMCLI https://www.freedesktop.org/software/ModemManager/man/1.0.0/mmcli.8.html
