// SPDX-License-Identifier: GPL-3.0-only
// Local HTTP stub for latency-check.sh: the first response on each connection waits 300 ms
// (a simulated node handshake), later keep-alive responses wait 80 ms. Listens on 127.0.0.1 only.
import * as socket from 'socket';
let mode=ARGV[0] || 'normal', FIRST=300, NEXT=80;
let srv=socket.listen('127.0.0.1','18080',{socktype:socket.SOCK_STREAM},16,true);
if(!srv){print('LISTEN_FAILED\n');exit(1);}
while(true){
 let c=srv.accept();if(!c)continue;
 let buf='',first=true,open=true;
 while(open){
  let i;
  while((i=index(buf,'\r\n\r\n'))<0){let d=c.recv(4096);if(d==null || !length(d)){open=false;break;}buf+=d;}
  if(!open)break;
  let req=substr(buf,0,i+4);buf=substr(buf,i+4);
  let m=match(req,/\r\nHost: ([^\r]+)\r\n/),host=m?m[1]:'',close=index(lc(req),'connection: close')>=0;
  let wasfirst=first;sleep(first?FIRST:(mode=='slowwarm'&&host!='ipinfo.io'?7000:NEXT));first=false;
  if(host=='ipinfo.io'){
   if(mode=='stall')sleep(20000);
   let body='{"ip":"203.0.113.9","country":"ZZ","org":"test"}';
   c.send('HTTP/1.0 200 OK\r\nContent-Type: application/json\r\nContent-Length: '+length(body)+'\r\n\r\n'+body);open=false;break;
  }
  if(mode=='pingstall')sleep(20000);
  if(mode=='bad204'){c.send('HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n');open=false;break;}
  if(mode=='silentclose'&&wasfirst){c.send('HTTP/1.1 204 No Content\r\nContent-Length: 0\r\n\r\n');open=false;break;}
  let shut=close || mode=='noka';
  c.send('HTTP/1.1 204 No Content\r\nContent-Length: 0\r\n'+(shut?'Connection: close\r\n':'')+'\r\n');
  if(shut){open=false;break;}
 }
 c.close();
}
