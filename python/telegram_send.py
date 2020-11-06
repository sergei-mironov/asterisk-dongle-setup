#!/usr/bin/env python3
from base64 import b64decode
from sys import argv
from asyncio import get_event_loop
from telethon import TelegramClient
from json import load as json_load

session = argv[1]
secret = argv[2]
time = argv[3]
device = argv[4]
phone = argv[5]
message = b64decode(argv[6]).decode('utf-8')

if session.endswith('.session'):
  session = session[:(len(session)-len('.session'))]

with open(secret, 'r') as f:
  secret=json_load(f)
telegram_api_id = secret['telegram_api_id']
telegram_api_hash = secret['telegram_api_hash']
telegram_chat_id = secret['telegram_chat_id']

async def main():
  client = TelegramClient(session=session,
                          api_id=telegram_api_id,
                          api_hash=telegram_api_hash)
  def _input_stub():
    raise RuntimeError("This script is not supposed to be interactive")
  await client.start(code_callback=_input_stub)
  await client.send_message(telegram_chat_id, f"SMS from {phone}: {message}")

get_event_loop().run_until_complete(main())
