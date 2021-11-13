from typing import Optional
from os.path import isfile
from requests import post as requests_post, delete as requests_delete
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
ARIIP=SECRETS['asterisk_bind_ip']

def aripost(cmd,args=None):
  args={} if args is None else args
  url=f"http://{ARIIP}:8088/ari/{cmd}?" \
      f"{'&'.join([quote(str(k))+'='+quote(str(v)) for k,v in args.items()])}"
  print(f"<HTTP POST {url}")
  res=requests_post(url,auth=(ARIUSER,ARIPWD),timeout=5)
  print(f"HTTP> {res}")

def aridel(cmd,args=None):
  args={} if args is None else args
  url=f"http://{ARIIP}:8088/ari/{cmd}?" \
      f"{'&'.join([str(k)+'='+str(v) for k,v in args.items()])}"
  print(f"<HTTP DELETE {url}")
  res=requests_delete(url,auth=(ARIUSER,ARIPWD),timeout=5)
  print(f"HTTP> {res}")

def aripost_channel_create(endpoint,
                           appArgs:Optional[str]=None,
                           fmt=None,
                           chid=None):
  args={'endpoint':endpoint,'app':ARIAPP}
  if appArgs is not None:
    args.update({'appArgs':appArgs})
  if fmt is not None:
    args.update({'formats':fmt})
  if chid is not None:
    args.update({'channelId':chid})
  aripost(f'channels/create',args)
  return chid

def aripost_channel_var(chanid,name,value):
  args={'variable':name}
  if value is not None:
    args.update({'value':value})
  aripost(f'channels/{chanid}/variable',args)
def aripost_channel_ring(chanid):
  aripost(f'channels/{chanid}/ring')
def aripost_channel_dial(chanid):
  aripost(f'channels/{chanid}/dial')
def aripost_channel_answer(chanid):
  aripost(f'channels/{chanid}/answer')
def aripost_channel_continue(chanid,ctx,ext,pri):
  aripost(f'channels/{chanid}/continue',
       {'context':ctx,'extension':ext,'priority':pri})
def aridel_channel(chid):
  aridel(f'channels/{chid}',{})

def aripost_bridge_create(typ,brid=None):
  brid=str(uuid4()) if brid is None else brid
  aripost(f'bridges',{'type':typ,'bridgeId':brid})
  return brid

def aripost_bridge_addchannels(brid,chids):
  aripost(f'bridges/{brid}/addChannel',{'channel':','.join(chids)})
def aridel_bridge(brid):
  aridel(f'bridges/{brid}',{})

