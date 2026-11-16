#!/usr/bin/env python3
"""Reproduce the pinned public geodata subset; never downloads user data."""
from pathlib import Path
import argparse,hashlib,ipaddress,urllib.request
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--input',type=Path);p.add_argument('--output',type=Path,default=ROOT/'root/usr/share/v2ray/lanekeep-services.dat');a=p.parse_args()
URL='https://github.com/Loyalsoldier/v2ray-rules-dat/releases/download/202611152204/geoip.dat'
SOURCE_SHA='304ac8a1cbcc8166e4f5a4f32955e4d0fb77a1bd713583e371b30ee27f3659d8'
OUTPUT_SHA='d326db0897723cd38b9d70c9b269c486fc05c6de61be1233187364abf6a890e7'
blob=a.input.read_bytes() if a.input else urllib.request.urlopen(URL,timeout=60).read()
assert hashlib.sha256(blob).hexdigest()==SOURCE_SHA,'Source digest mismatch'
def varint(data,i):
 n=shift=0
 while True:
  b=data[i];i+=1;n|=(b&127)<<shift
  if b<128:return n,i
  shift+=7
def fields(data):
 i=0
 while i<len(data):
  start=i;key,i=varint(data,i);kind=key&7
  if kind==2:
   size,i=varint(data,i);v=data[i:i+size];i+=size
  elif kind==0:v,i=varint(data,i)
  else:raise ValueError(kind)
  yield key>>3,v,data[start:i]
def vi(n):
 out=bytearray()
 while n>127:out.append((n&127)|128);n>>=7
 out.append(n);return bytes(out)
kept=[];counts={}
for _,entry,_ in fields(blob):
 parts=list(fields(entry));name=next(v.decode() for f,v,_ in parts if f==1)
 if name not in ('GOOGLE','NETFLIX'):continue
 out=b'';count=0
 for f,v,raw in parts:
  if f!=2:out+=raw;continue
  props={k:v for k,v,_ in fields(v)};addr=props[1];prefix=props.get(2,0)
  if len(addr)!=4:continue
  net=ipaddress.ip_network((ipaddress.ip_address(addr),prefix))
  assert not net.overlaps(ipaddress.ip_network('198.18.0.0/15'))
  assert net.is_global
  out+=raw;count+=1
 kept.append(b'\x0a'+vi(len(out))+out);counts[name]=count
assert set(counts)=={'GOOGLE','NETFLIX'}
result=b''.join(kept)
assert hashlib.sha256(result).hexdigest()==OUTPUT_SHA,'Output digest mismatch'
if a.output.exists():
 assert a.output.read_bytes()==result,'Existing output differs; choose a new --output path'
else:
 a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_bytes(result)
print(OUTPUT_SHA,counts)
