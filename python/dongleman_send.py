#!/usr/bin/env python3
from base64 import b64decode
from sys import argv
from asyncio import get_event_loop
from telethon import TelegramClient
from json import load as json_load
from argparse import ArgumentParser
from os.path import isfile, join, isdir, basename
from os import rename
from json import dump as json_dump
from dongleman.spool import (isspool, SPOOLSIZE, spool_lock, spool_tmp,
                             spool_newname, spool_attaches)
from tempfile import mktemp


parser = ArgumentParser(description='Simple messaging client for Telegram.')
parser.add_argument('positionals', nargs=2,
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
assert len(args.positionals) == 2

spool = %DONGLEMAN_SPOOL%
assert isspool(spool), f"Invalid spool directory '{spool}'"
time = args.positionals[0]
device = args.positionals[1]

message = b64decode(args.message_base64).decode('utf-8') \
  if args.message_base64 is not None else (args.message \
    if args.message is not None else "")


def main():
  tattach=None
  if args.attach_voice is not None:
    try:
      a=join(spool_attaches(spool),basename(args.attach_voice))
      if isfile(a):
        raise ValueError(f"File '{a}' already exists")
      rename(args.attach_voice, a)
      tattach=a
    except (ValueError, OSError) as e:
      print(f"Failed to attach {args.attach_voice}", e)
  msg={
    'from_name':args.from_name,
    'message':message,
    'voice_path':tattach,
    'time':time,
    'device':device
    }
  tpath=mktemp(dir=spool_tmp(spool))
  with open(tpath,'w') as f:
    json_dump(msg,fp=f,indent=4)

  with spool_lock(spool) as lock:
    newname=spool_newname(spool, lock, 'json')
    print(f"Creating pool entry {newname}")
    rename(tpath, newname)

main()
