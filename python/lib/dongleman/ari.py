from typing import Optional
from os.path import isfile
from requests import post as requests_post
from requests.utils import quote
from json import loads as json_loads, load as json_load
from uuid import uuid4

SECRETS_PATH=%DONGLEMAN_SECRETS%
assert isfile(SECRETS_PATH), f"Secrets file not found: '{SECRETS_PATH}'"
with open(SECRETS_PATH, 'r') as f:
  SECRETS=json_load(f)

ARIAPP=SECRETS['asterisk_ari_app']
ARIUSER=SECRETS['asterisk_ari_user']
ARIPWD=SECRETS['asterisk_ari_password']

def aripost(cmd,args=None):
  args={} if args is None else args
  url=f"http://localhost:8088/ari/{cmd}?" \
      f"{'&'.join([str(k)+'='+str(v) for k,v in args.items()])}"
  print(f"HTTP> {url}")
  res=requests_post(url,auth=(ARIUSER,ARIPWD),timeout=5)
  print(f"HTTP> {res}")

def aripost_channel_create(endpoint,appArgs:Optional[str]=None):
  args={'endpoint':endpoint,'app':ARIAPP}
  if appArgs is not None:
    args.update({'appArgs':appArgs})
  aripost(f'channels/create',args)

def aripost_channel_ring(chanid):
  aripost(f'channels/{chanid}/ring')
def aripost_channel_dial(chanid):
  aripost(f'channels/{chanid}/dial')
def aripost_channel_answer(chanid):
  aripost(f'channels/{chanid}/answer')
def aripost_channel_continue(chanid,ctx,ext,pri):
  aripost(f'channels/{chanid}/continue',
       {'context':ctx,'extension':ext,'priority':pri})

def aripost_bridge_create(typ,brid=None):
  brid=str(uuid4()) if brid is None else brid
  aripost(f'bridges',{'type':typ,'bridgeId':brid})
  return brid

def aripost_bridge_addchannels(brid,chids):
  aripost(f'bridges/{brid}/addChannel',{'channel':','.join(chids)})

