#!/usr/bin/env python

import asyncio
from websockets import connect as wsconnect
from base64 import b64encode


async def start():
  async with wsconnect(('ws://localhost:8088/ari/events?'
                        'api_key=asterisk:asterisk&'
                        'app=hello-world')) as ws:
    print('Connected!')
    while True:
      inp=await ws.recv()
      print(f"< {inp}")

asyncio.get_event_loop().run_until_complete(start())
asyncio.get_event_loop().run_forever()



