#!/usr/bin/env python

import asyncio
from websockets import connect as wsconnect
from base64 import b64encode
from requests import post as requests_post
from requests.utils import quote
from json import loads as json_loads
from uuid import uuid4

APP='hello-world'
USER='asterisk'
PWD='asterisk'


def post(cmd,args=None):
  args={} if args is None else args
  url=f"http://localhost:8088/ari/{cmd}?" \
      f"{'&'.join([str(k)+'='+str(v) for k,v in args.items()])}"
  print(f"HTTP> {url}")
  res=requests_post(url,auth=(USER,PWD),timeout=5)
  print(f"HTTP> {res}")

def post_channel_create(endpoint):
  post(f'channels/create',{'endpoint':endpoint,'app':APP})

def post_channel_ring(chanid):
  post(f'channels/{chanid}/ring')
def post_channel_dial(chanid):
  post(f'channels/{chanid}/dial')
def post_channel_answer(chanid):
  post(f'channels/{chanid}/answer')
def post_channel_continue(chanid,ctx,ext,pri):
  post(f'channels/{chanid}/continue',
       {'context':ctx,'extension':ext,'priority':pri})

def post_bridge_create(typ,brid=None):
  brid=str(uuid4()) if brid is None else brid
  post(f'bridges',{'type':typ,'bridgeId':brid})
  return brid

def post_bridge_addchannels(brid,chids):
  post(f'bridges/{brid}/addChannel',{'channel':','.join(chids)})

async def start():
  print("<WS (connecting...)")
  async with wsconnect(('ws://localhost:8088/ari/events?'
                        f'api_key={USER}:{PWD}&'
                        f'app={APP}')) as ws:
    print('WS> Connected!')
    chid_orig=None
    chid_peer=None
    while True:
      e_str=await ws.recv()
      print(f"WS> {e_str}")
      e=json_loads(e_str)
      if e['type']=='StasisStart':
        if chid_orig is None:
          chid_orig=e['channel']['id']
          post_channel_ring(chid_orig)
          post_channel_create(quote('PJSIP/tg#XXXXXX@telegram-endpoint'))
        else:
          chid_peer=e['channel']['id']
          brid=post_bridge_create('mixing')
          post_bridge_addchannels(brid,[chid_orig,chid_peer])
          post_channel_answer(chid_orig)
          post_channel_dial(chid_peer)
          # post_channel_continue(chid_orig,'telegram-incoming-lenny','telegram',1)
      else:
        pass


asyncio.get_event_loop().run_until_complete(start())
asyncio.get_event_loop().run_forever()



