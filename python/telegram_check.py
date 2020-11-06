#!/usr/bin/env python3

from sys import exit

import asyncio
from argparse import ArgumentParser
from telethon import TelegramClient

from json import load as json_load

import logging
logging.basicConfig(format='[%(levelname) 5s/%(asctime)s] %(name)s: %(message)s',
                    level=logging.DEBUG)


parser = ArgumentParser(description='Simple messaging client for Telegram.')
parser.add_argument('--session', help='Path to session file')
parser.add_argument('--secret',help='Path to secret.json')
args = parser.parse_args()

assert args.session is not None
assert args.session[0]=='/', "Session path should be absolute"
if args.session.endswith('.session'):
  args.session = args.session[:(len(args.session)-len('.session'))]

print(type(args.session), args.session)
print(type(args.secret), args.secret)

with open(args.secret, 'r') as f:
  secret=json_load(f)

telegram_app_title = secret['telegram_app_title']
telegram_api_id = secret['telegram_api_id']
telegram_api_hash = secret['telegram_api_hash']
telegram_phone = secret['telegram_phone']
telegram_bot_token = secret['telegram_bot_token']

print(type(telegram_api_id), telegram_api_id)
print(type(telegram_api_hash), telegram_api_hash)


async def main():
  client = TelegramClient(session=args.session,
                          api_id=telegram_api_id,
                          api_hash=telegram_api_hash)
  await client.start(phone=telegram_phone)
  dialogs = await client.get_dialogs()
  print("Dialogs")
  for d in dialogs:
    print(f"{d.id}: {d.title}")
  print('OK')

loop = asyncio.get_event_loop()
loop.run_until_complete(main())
