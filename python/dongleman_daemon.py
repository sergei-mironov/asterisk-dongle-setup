#!/usr/bin/env python3
from asyncio import get_event_loop
from minotaur import Inotify, Mask
from argparse import ArgumentParser
from os.path import isdir, isfile
from os import remove
from telethon import TelegramClient

from dongleman.spool import spool_lock, isspool, spool_queue, spool_iterate
from json import load as json_load, JSONDecodeError

SPOOL=%DONGLEMAN_SPOOL%
assert isspool(SPOOL), f"Message pool should be a valid directory, got {SPOOL}"

SESSION=%DONGLEMAN_TGSESSION%
if SESSION.endswith('.session'):
  assert isfile(SESSION)
  SESSION = SESSION[:(len(SESSION)-len('.session'))]

SECRETS=%DONGLEMAN_SECRETS%
assert isfile(SECRETS), f"Secrets file not found: '{SECRETS}'"
with open(SECRETS, 'r') as f:
  secret_contents=json_load(f)
TELEGRAM_API_ID = secret_contents['telegram_api_id']
TELEGRAM_API_HASH = secret_contents['telegram_api_hash']
TELEGRAM_CHAT_ID = secret_contents['telegram_chat_id']



async def send_telegram_message(client, message):
  voice_path=message.get('voice_path')
  fulltext=f"{message.get('from_name','<unknown>')}: {message.get('message','')}"
  reacted=False
  if voice_path is not None:
    if not isfile(voice_path):
      await client.send_message(TELEGRAM_CHAT_ID,
                                f"Error: {voice_path} is not a file")
    else:
      await client.send_file(TELEGRAM_CHAT_ID,
                             voice_path,
                             voice_note=True,
                             caption=fulltext)
    remove(voice_path)
    reacted=True

  if fulltext is not None:
    await client.send_message(TELEGRAM_CHAT_ID, fulltext)
    reacted=True
  if not reacted:
    raise ValueError("Message should contain either message or voice file")


async def listen_system_commands(client):
  async def _handle():
    with spool_lock(SPOOL) as lock:
      for path in spool_iterate(SPOOL, lock):
        with open(path) as f:
          print(f'Processing path {path}')
          try:
            await send_telegram_message(client, json_load(f))
          except JSONDecodeError as err:
            print(f"Error parsing JSON '{path}': {err}")

  await _handle()
  with Inotify(blocking=False) as n:
    n.add_watch(spool_queue(SPOOL), Mask.CREATE | Mask.DELETE | Mask.MOVE)
    async for evt in n:
      print(evt)
      await _handle()



async def main():
  client = TelegramClient(session=SESSION,
                          api_id=TELEGRAM_API_ID,
                          api_hash=TELEGRAM_API_HASH)
  def _input_stub():
    raise RuntimeError("This script is not supposed to be interactive")
  await client.start(code_callback=_input_stub)
  await listen_system_commands(client)


# TODO: use this https://tutorialedge.net/python/concurrency/asyncio-event-loops-tutorial/
get_event_loop().run_until_complete(main())

