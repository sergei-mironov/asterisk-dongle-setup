#!/usr/bin/env python3

from sys import exit

import asyncio
from argparse import ArgumentParser
from telethon import TelegramClient
from os.path import isfile

from json import load as json_load

import logging
logging.basicConfig(format='[%(levelname) 5s/%(asctime)s] %(name)s: %(message)s',
                    level=logging.DEBUG)

SESSION=%DONGLEMAN_TGSESSION%
if SESSION.endswith('.session'):
  # assert isfile(SESSION)
  SESSION = SESSION[:(len(SESSION)-len('.session'))]

SECRETS=%DONGLEMAN_SECRETS%
assert isfile(SECRETS), f"Secrets file not found: '{SECRETS}'"
with open(SECRETS, 'r') as f:
  secret_contents=json_load(f)
TELEGRAM_API_ID = secret_contents['telegram_api_id']
TELEGRAM_API_HASH = secret_contents['telegram_api_hash']
TELEGRAM_PHONE = secret_contents['telegram_phone']

async def main():
  client = TelegramClient(session=SESSION,
                          api_id=TELEGRAM_API_ID,
                          api_hash=TELEGRAM_API_HASH)
  await client.start(phone=TELEGRAM_PHONE)
  dialogs = await client.get_dialogs()
  print("Dialogs")
  for d in dialogs:
    print(f"{d.id}: {d.title}")
  print('OK')

loop = asyncio.get_event_loop()
loop.run_until_complete(main())
