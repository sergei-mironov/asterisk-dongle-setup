{
  telegram_app_title="Myapp";
  telegram_api_id=9999999;
  telegram_api_hash="00000000000000000000000000000000";
  telegram_bot_token="1111111111:22222222222222222222222222222222222";
  telegram_phone="+79158888888";
  # Telegram chat_id to send SMS and VOICECALLs
  telegram_chat_id="-1111111111111";
  # Telegram Nicname to redirect CALLs to
  telegram_master_nicname="realuser";

  tg2sip_api_id=throw "Specify your Telegram api_id for tg2sip as a number";
  tg2sip_api_hash= throw "Specify your Telegram API_HASH for tg2sip as a string";
  tg2sip_bind_ip="192.168.1.36"; # 127.0.0.1 doesn't work due to bug in tg2sip

  dongle_device_data="/dev/ttyUSB0";
  dongle_device_audio="/dev/ttyUSB1";

  # Path for SMS forwarding queue from Asterisk to Telegram
  dongleman_spool="/tmp/dongleman/spool";

  asterisk_bind_ip="192.168.1.36";
  asterisk_ari_user="asterisk";
  asterisk_ari_password="asterisk";
}
