Asterisk-dongle-setup
=====================

In this playground project we try to setup Asterisk server to work with
[GSM-modem dongle](https://github.com/wdoekes/asterisk-chan-dongle) using
[Nix](https://nixos.org) package manager.

The project aims at automating the configuration of software able to solve the following
tasks:

* Receive SMS messages and re-send them to a messenger.
* Handle voice calls with voice menu.
* Handle voice calls with a chat bot.

Setup
=====

0. Install [Nix package manager](https://nixos.org/guides/install-nix.html).
   Note that it could easily co-exist with your native package manager. We use [20.03 Nixpkgs tree](https://github.com/NixOS/nixpkgs/tree/076c67fdea6d0529a568c7d0e0a72e6bc161ecf5/) as base.
1. `git clone --recursive <this-repo-url> ; cd ...`
2. Run the wrapper script `./asterisk.sh`.
   - The script currently relies on `sudo` to overcome difficulties with
     chan-dongle's hardcoded paths.
   - Script checks for the presence of `/dev/ttyUSB0` and if it is not present,
     it attempts to run the `usb_modeswitch` procedure. See below section for
     details.
3. ???
4. Continue hacking:
   * See the chan-dongle's [README.md](https://github.com/wdoekes/asterisk-chan-dongle)
     for supported commands.
   * To send SMS: `dongle sms dongle0 89097777777 HiHi`
   * To receive SMS with `E173`:
     - `dongle cmd dongle0 AT^PORTSEL=1`.
     - Send SMS/Call to dongle SIMcard's number
     - [x] TODO: Patch the driver.

### Doing USB Modeswitch manually

`asterisk.sh` attempts to run usb_modeswitch procedure automatically for devices
known to author. In case the procedure fails, one could attempt the manual way:

1. `nix-build -A usb_modeswitch`.
2. `lsusb` to find out your modem's vendor:product numbers
3. `sudo ./result/usr/sbin/usb_modeswitch -v <vendor> -p <product> -X`
4. `/dec/ttyUSB[01]` devices should appear. You should be able
   to `minicom -D /dev/ttyUSB0` and type some AT command, say `ATI`.
5. Update `asterisk.sh` script by adding new line like below to the
   corresponding place
   ```
   try_to_deal_with "<your_device_id>" "<your_device_vendor>" && wait_for_chardev "/dev/ttyUSB0"
   ```

### Nix-shell

Author uses VIM as the main development IDE. The start procedure is as follows:

```
$ nix-shell -A shell
(nix-shell) $ vim .   # Edit sources enjoying code navigaiton
(nix-shell) $ ipython # Testing telethon bot, etc
```

Hardware
========

We use the following USB dongle:

```
*CLI> dongle show devices
ID           Group State      RSSI Mode Submode Provider Name  Model      Firmware          IMEI             IMSI             Number
dongle0      0     Free       9    0    0       Beeline        E173       11.126.85.00.209  ***************  ***************  Unknown
```

See also [somewhat outdated list of supported devices](https://github.com/bg111/asterisk-chan-dongle/wiki/Requirements-and-Limitations)

Issues
======

* ~~https://github.com/wdoekes/asterisk-chan-dongle/issues/109~~
* ~~https://github.com/wdoekes/asterisk-chan-dongle/issues/110~~
* https://github.com/wdoekes/asterisk-chan-dongle/issues/120
* https://community.asterisk.org/t/receive-sms-using-chan-dongle/86097
* https://github.com/wdoekes/asterisk-chan-dongle/issues/121


References
==========

* GSMCTL https://www.unix.com/man-page/debian/8/gsmctl/
  - Homepage looks inactive
* MMCLI https://www.freedesktop.org/software/ModemManager/man/1.0.0/mmcli.8.html
* Asterisk+Dongle setup guide (in Russian)
  http://linux.mixed-spb.ru/asterisk/dongle_app1.php
* Another Dongle guide in Russian
  https://jakondo.ru/podklyuchenie-gsm-modema-usb-huawei-e1550-k-asterisk-13-chan_dongle-na-debian-8-jessie/

