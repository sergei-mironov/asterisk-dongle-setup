#!/usr/bin/env python3
import sys
from time import sleep
from asyncio import get_event_loop, gather, Future, open_connection
from minotaur import Inotify, Mask
from argparse import ArgumentParser
from os.path import isdir, isfile
from os import remove
from telethon import TelegramClient
from telethon.events import NewMessage
from json import load as json_load, loads as json_loads, JSONDecodeError
from websockets import connect as wsconnect
from base64 import b64encode
from requests.utils import quote

from dongleman.spool import spool_lock, isspool, spool_queue, spool_iterate
from dongleman.ari import (ARIUSER, ARIPWD, ARIAPP, aripost_channel_create,
                           aripost_channel_ring, aripost_channel_dial,
                           aripost_channel_answer, aripost_channel_continue,
                           aripost_bridge_create, aripost_bridge_addchannels)

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
TELEGRAM_MASTER_NICKNAME = secret_contents['telegram_master_nicname']



async def send_telegram_message(client, message):
  voice_path=message.get('voice_path')
  fulltext=': '.join([message.get('from_name','<unknown-from>'),
                      message.get('message','<unknown-message>')])
  if voice_path is not None:
    if not isfile(voice_path):
      await client.send_message(TELEGRAM_CHAT_ID,
                                f"{fulltext}\nError: '{voice_path}' is not a file")
    else:
      await client.send_file(TELEGRAM_CHAT_ID,
                             voice_path,
                             voice_note=True,
                             caption=fulltext)
    remove(voice_path)
  elif fulltext is not None:
    await client.send_message(TELEGRAM_CHAT_ID, fulltext)
  else:
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


async def listen_asterisk_websocket(tclient):
  port=8088
  while True:
    try:
      r,w=await open_connection('localhost', port)
      w.close(); await w.wait_closed()
      break
    except Exception as e:
      print(f"<WS Waiting for socket")
      sleep(1)
  print(f"<WS (connecting as {ARIAPP})")
  async with wsconnect((f'ws://localhost:{port}/ari/events?'
                        f'api_key={ARIUSER}:{ARIPWD}&app={ARIAPP}')) as ws:
    print('WS> Connected!')
    while True:
      e_str=await ws.recv()
      # print(f"WS> {e_str}")
      e=json_loads(e_str)
      if e['type']=='StasisStart':
        print(f"WS> {e['type']} chanid {e['channel']['id']}")
        args=e['args']
        if len(args)==0:
          chid_orig=e['channel']['id']
          dst=Future()
          @tclient.on(NewMessage(pattern=r'Call (\+?\w+)'))
          async def handler(evt):
            match=evt.pattern_match.group(1)
            sender=await evt.get_sender()
            if sender.username == TELEGRAM_MASTER_NICKNAME:
              if match.lower()=='master':
                endp=quote(f'PJSIP/tg#{TELEGRAM_MASTER_NICKNAME}@telegram-endpoint')
              else:
                endp=quote(f'Dongle/dongle0/{match}')
              await evt.reply(f"Calling to {endp}")
              dst.set_result(endp)
            else:
              await evt.reply(f"{sender.username} access denied")
          await dst
          tclient.remove_event_handler(handler)
          aripost_channel_ring(chid_orig)
          aripost_channel_create(dst.result(),appArgs=chid_orig)
        else:
          chid_orig=args[0]
          chid_peer=e['channel']['id']
          brid=aripost_bridge_create('mixing')
          aripost_bridge_addchannels(brid,[chid_orig,chid_peer])
          aripost_channel_answer(chid_orig)
          aripost_channel_dial(chid_peer)
          # post_channel_continue(chid_orig,'telegram-incoming-lenny','1000',1)
      else:
        print(f"WS> {e['type']}")


async def main():
  print('Starting dongleman_daemon')
  tclient=TelegramClient(session=SESSION,
                         api_id=TELEGRAM_API_ID,
                         api_hash=TELEGRAM_API_HASH)
  def _input_stub():
    raise RuntimeError("This script is not supposed to be interactive")
  await tclient.start(code_callback=_input_stub)
  await gather(listen_system_commands(tclient),
               listen_asterisk_websocket(tclient))

if __name__=='__main__':

  argv=sys.argv[1:]
  if any([a in ['--check'] for a in argv]):
    print('Asterisk-dongleman-daemon script syntax OK')
    sys.exit(0)
  if any([a in ['help','-h','--help'] for a in argv]):
    print('Asterisk-dongleman-daemon')
    sys.exit(1)

  get_event_loop().run_until_complete(main())

