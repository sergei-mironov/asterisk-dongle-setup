#!/usr/bin/env python3
from base64 import b64decode
from sys import argv
from asyncio import get_event_loop
from telethon import TelegramClient
from json import load as json_load
from argparse import ArgumentParser
from os.path import isfile

NARGS=2
parser = ArgumentParser(description='Simple messaging client for Telegram.')
parser.add_argument('positionals', nargs=NARGS,
                    help='TIME DEVICE')
parser.add_argument('--attach-voice', type=str, metavar='PATH',
                    help='File to attach', default=None)
parser.add_argument('--message-base64', type=str, metavar='TEXT',
                    help='Base64-encoded message', default=None)
parser.add_argument('--message', type=str, metavar='TEXT',
                    help='Message in plain text (utf8)', default=None)
parser.add_argument('--from-name', type=str, metavar='TEXT',
                    help='String in plain text (utf8)', default=None)
args = parser.parse_args()
assert len(args.positionals) == NARGS

time = args.positionals[0]
device = args.positionals[1]
message = b64decode(args.message_base64).decode('utf-8') \
  if args.message_base64 is not None else args.message
from_name=args.from_name if args.from_name is not None else "Unknown"
fulltext=':'.join([f"{from_name} via {device}",message])

session=%DONGLEMAN_TGSESSION%
if session.endswith('.session'):
  assert isfile(session)
  session = session[:(len(session)-len('.session'))]

secret=%DONGLEMAN_SECRETS%
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
  if args.attach_voice is not None:
    if not isfile(args.attach_voice):
      await client.send_message(telegram_chat_id,
                                f"Error: {args.attach_voice} is not a file")
    else:
      await client.send_file(telegram_chat_id, args.attach_voice,
                             voice_note=True,
                             caption=fulltext)
  elif message is not None:
    await client.send_message(telegram_chat_id, fulltext)
  else:
    raise ValueError("Either --message-* or --attach-voice should be passed")

get_event_loop().run_until_complete(main())
