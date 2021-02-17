from os.path import join, splitext, isdir, abspath
from os import makedirs, walk, remove

from filelock import SoftFileLock
from contextlib import contextmanager

SPOOLSIZE=20

def spool_tmp(spoolpath):
  return join(spoolpath,'tmp')
def spool_queue(spoolpath):
  return join(spoolpath,'queue')
def spool_attaches(spoolpath):
  return join(spoolpath,'attaches')

def isspool(spoolpath):
  return isdir(spool_tmp(spoolpath)) and \
         isdir(spool_queue(spoolpath)) and \
         isdir(spool_attaches(spoolpath))


def spool_init(spoolpath):
  makedirs(spoolpath,exist_ok=True)
  makedirs(spool_tmp(spoolpath),exist_ok=True)
  makedirs(spool_queue(spoolpath),exist_ok=True)
  makedirs(spool_attaches(spoolpath),exist_ok=True)
  assert isspool(spoolpath)

@contextmanager
def spool_lock(spoolpath):
  lock=SoftFileLock(join(spoolpath,'lock'))
  lock.acquire()
  try:
    yield lock
  finally:
    lock.release()

def spool_newname(spoolpath, lock, ext):
  nums=[]
  for root, dirs, filenames in walk(spool_queue(spoolpath), topdown=True):
    for filename in sorted(filenames):
      try:
        nums.append(int(splitext(filename)[0]))
      except ValueError:
        print(f"Ignoring spool entry: '{filename}'")
  return abspath(join(spool_queue(spoolpath),
              f"{max(nums)+1 if len(nums)>0 else 0:08d}.{ext}"))


def spool_get(spoolpath, lock):
  for root, dirs, filenames in walk(spool_queue(spoolpath), topdown=True):
    for filename in sorted(filenames):
      return abspath(join(root,filename))
  return None

def spool_iterate(spoolpath, lock):
  while True:
    m=spool_get(spoolpath, lock)
    if m is None:
      break
    yield m
    remove(m)

