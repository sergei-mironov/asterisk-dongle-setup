Asterisk-dongle-setup
=====================

In this playground project we try to setup Asterisk server to work with
[GSM-modem dongle](https://github.com/wdoekes/asterisk-chan-dongle) using
[Nix](https://nixos.org) package manager.

The project aims at automating the configuration of software able to solve the
following tasks:

* [x] Receive SMS messages and forward them to a Telegram chat.
* [x] Handle voice calls with voice menu.
* [ ] Handle voice calls with a chat bot.

Setup
=====

0. Install [Nix package manager](https://nixos.org/guides/install-nix.html).
   Note that it could easily co-exist with your native package manager. We use
   [20.03 Nixpkgs tree](https://github.com/NixOS/nixpkgs/tree/076c67fdea6d0529a568c7d0e0a72e6bc161ecf5/)
   as a base.
1. `git clone --recursive <this-repo-url> ; cd ...`
2. Create `./secrets.nix` file by copying and editing `./secrets_template.nix`.
   - You need a mobile phone which is bound to some Telegram account.
   - Go to https://my.telegram.org/auth and register an API Client instance.
     You will be provided with `api_id` and `api_hash` values.
   - Bot token field is not currently used.
   - Chat id is a (typically negative) identifier of a chat to send SMS messages
     to. `./asterisk.sh` will print available chat identifiers of a client at
     some point.
3. Setup the GSM Modem. You need to get a supported GSM modem and plug it into
   USB port of your computer.
   - See the chan-dongle's
     [README.md](https://github.com/wdoekes/asterisk-chan-dongle) for
     information about the supported hardware. Some outdated document is also
     available
     [here](https://github.com/bg111/asterisk-chan-dongle/wiki/Requirements-and-Limitations)
   - `./asterisk.sh` will check for the presence of `/dev/ttyUSB0`. If it
     is not present, the script would attempt to run the `usb_modeswitch`
     procedure. But only a small number of devices (currently, 1) is encoded,
     so an update may be required. See below section for details.
4. Run the main script `./asterisk.sh`.
   - The script currently relies on `sudo` to overcome difficulties with
     chan-dongle's hardcoded paths.
   - Script initializes Telegram session. As a part of initialization, Telegram
     server will send a digital code to your Telegram application. You are to
     type this code back into the script.
5. ???
6. Do some hacking:
   * To send SMS from the GSM modem, do: `dongle sms dongle0 89097777777 HiHi`
   * To receive SMS with `E173`:
     - `dongle cmd dongle0 AT^PORTSEL=1`.
     - Send SMS/Call to dongle SIMcard's number
     - [x] Patch the driver.

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
* ~~https://github.com/wdoekes/asterisk-chan-dongle/issues/121~~
* ~~https://github.com/Infactum/tg2sip/issues/42~~
* ~~https://community.asterisk.org/t/help-translating-a-simple-peer-config-to-pjsip/86601~~
* https://github.com/wdoekes/asterisk-chan-dongle/issues/120
* Binary `chan_opus.so` is used


References
==========

**GSM modems**

* Asterisk+Dongle setup guide (in Russian)
  http://linux.mixed-spb.ru/asterisk/dongle_app1.php
* Another Dongle guide in Russian
  https://jakondo.ru/podklyuchenie-gsm-modema-usb-huawei-e1550-k-asterisk-13-chan_dongle-na-debian-8-jessie/
* Unrelated GSM software:
  - GSMCTL (abandoned?) https://www.unix.com/man-page/debian/8/gsmctl/
  - MMCLI https://www.freedesktop.org/software/ModemManager/man/1.0.0/mmcli.8.html

**Asterisk**

* Asterisk Wiki https://wiki.asterisk.org/wiki/display/AST
* Generic information about PJSIP https://wiki.asterisk.org/wiki/display/AST/PJSIP+Configuration+Sections+and+Relationships
* An article about PJSIP configuration https://www.redhat.com/sysadmin/asterisk-dialplan
* Setting up TG2SIP (In Russian) https://voxlink.ru/kb/asterisk-configuration/ustanovka-i-nastrojka-sip-shljuza-dlja-telegram/
* About OPUS codec:
  - https://community.asterisk.org/t/codec-opus-source-code/72738/6
  - Binary opus module 'sends some statistics back to Digium' http://downloads.digium.com/pub/telephony/codec_opus/
  - OpenSource equivalent https://github.com/traud/asterisk-opus
* Important dialplan commands:
  - Dial https://wiki.asterisk.org/wiki/display/AST/Application_Dial

**Telegram**

* Client API access page https://my.telegram.org/auth
* Telethon API client documentation https://docs.telethon.dev/en/latest/
* TG2SIP https://github.com/Infactum/tg2sip
* Setting up TG2SIP (In Russian) https://voxlink.ru/kb/asterisk-configuration/ustanovka-i-nastrojka-sip-shljuza-dlja-telegram/

**Fun**

* Lenny https://crosstalksolutions.com/howto-pwn-telemarketers-with-lenny/

