{
  # Names of usb devices to connect to access the GSM modem songle. The data
  # device should typically be a usb2com compatible device.
  dongle_device_data="/dev/ttyUSB0";
  dongle_device_audio="/dev/ttyUSB1";

  telegram_app_title="Myapp";
  telegram_api_id=9999999;
  telegram_api_hash="00000000000000000000000000000000";
  telegram_bot_token="1111111111:22222222222222222222222222222222222";

  # A phone number to pass to Telethon API library.
  telegram_phone="+79158888888";
  # Telegram chat identifier (typically - a long negative integer) to wich to
  # send SMS messages with information and voice records. The chat should be
  # available to the Telethon bot. A list of avaialbe chat identifiers is
  # printed at some point during the startup of the system.
  telegram_chat_id="-1111111111111";
  # Telegram Nicname to redirect voicecalls to. Used to create `tg2sip` calling
  # address
  telegram_master_nicname="realuser";
  # Name of a session file used by Telethon library to store the credentials of
  # a user between runs. Telethon will require you to pass SMS verification
  # if it couldn't find this file. One may typically leave the name as-is.
  telegram_session="./telegram.session";

  tg2sip_api_id=throw "Specify your Telegram api_id for tg2sip as a number";
  tg2sip_api_hash= throw "Specify your Telegram API_HASH for tg2sip as a string";
  # IP address to listed from the TG2sip side. Should be visible from the
  # `asterisk_bind_ip`.
  # 127.0.0.1 doesn't work due to a bug in tg2sip
  tg2sip_bind_ip="192.168.1.36";

  # Path for SMS forwarding queue from Asterisk to Telegram
  dongleman_spool="/tmp/dongleman/spool";

  # IP address to listed from the Asterisk side. Should be visible from the
  # `tg2sip_bind_ip`.
  asterisk_bind_ip="192.168.1.36";

  # We enable ARI API of the Asterisk. ARI clients connect to Asterisk using the
  # restful HTTP requiests. Both Asterisk and its clients need to know the user,
  # the password, and the application name to start talking.
  asterisk_ari_user="asterisk";
  asterisk_ari_password="asterisk";
  asterisk_ari_app="dongleman-ari-app";
}
