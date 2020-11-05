#!/usr/bin/env python3
import base64
import sys
import codecs

session = sys.argv[1]
phone = sys.argv[2]
message = base64.b64decode(sys.argv[3]).decode('utf-8')

if session.endswith('.session'):
  session = args.session[:(len(session)-len('.session'))]

print(f"SMS from: {phone}: {message}")

async def main():
  client = TelegramClient(session=args.session).start()
  # TODO

loop = asyncio.get_event_loop()
loop.run_until_complete(main())
