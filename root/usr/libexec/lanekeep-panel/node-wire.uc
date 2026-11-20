// Measurement v3 (2026-11-20): one ucode process over the local test SOCKS port.
// Latency is the smaller of two requests sent on an already established tunnel, as common
// clients report it; the first request (node handshake included) is reported separately.
// The exit IP comes from a second, untimed connection. No direct path; every step is bounded.
import * as fs from 'fs';
import * as socket from 'socket';
function mono(){let t=clock(true);if(!t)die('monotonic_clock_unavailable');return int(t[0]*1000+t[1]/1000000+0.5);}
let mode=ARGV[0],work=ARGV[1],port=int(ARGV[2]||'0');
if(mode!='probe' || !match(work || '',/^\/tmp\/lanekeep-panel\/[a-f0-9-]{36}$/) || fs.lstat(work)?.type!='directory' || port<20000 || port>=50000)exit(64);
function save(v){
 if(fs.writefile(work+'/test-result.next',sprintf('%J\n',v))==null)exit(71);
 fs.chmod(work+'/test-result.next',0600);if(!fs.rename(work+'/test-result.next',work+'/test-result'))exit(71);
}
function fill(conn){
 // poll() returns [[socket, 0]] rather than [] when the wait expires.
 let wait=conn.deadline-mono(),ready=wait>0?socket.poll(wait,conn.c):null;if(!length(ready || []) || !ready[0][1])die('timeout');
 let d=conn.c.recv(4096,socket.MSG_DONTWAIT);if(d==null)die('recv');if(!length(d))die('closed');
 conn.buf+=d;conn.total+=length(d);if(conn.total>65536)die('oversize');
}
function take(conn,n){while(length(conn.buf)<n)fill(conn);let s=substr(conn.buf,0,n);conn.buf=substr(conn.buf,n);return s;}
function send(conn,s){let sent=0;while(sent<length(s)){if(mono()>conn.deadline)die('timeout');let n=conn.c.send(substr(s,sent),socket.MSG_DONTWAIT);if(n==null || n<=0)die('send');sent+=n;}}
function headers(conn){let i;while((i=index(conn.buf,'\r\n\r\n'))<0){if(length(conn.buf)>8192)die('headers');fill(conn);}let h=substr(conn.buf,0,i+4);conn.buf=substr(conn.buf,i+4);return h;}
function open(host,deadline){
 let c=socket.connect({address:'127.0.0.1',port},null,{family:socket.AF_INET,socktype:socket.SOCK_STREAM},1000);if(!c)die('local_connect');
 let conn={c,buf:'',total:0,deadline};
 send(conn,sprintf('%c%c%c',5,1,0));
 let auth=take(conn,2);if(ord(auth,0)!=5 || ord(auth,1)!=0)die('socks_auth');
 send(conn,sprintf('%c%c%c%c%c%s%c%c',5,1,0,3,length(host),host,0,80));
 let rep=take(conn,4);if(ord(rep,0)!=5 || ord(rep,1)!=0 || ord(rep,2)!=0)die('socks_connect');
 let at=ord(rep,3);if(at==1)take(conn,6);else if(at==4)take(conn,18);else if(at==3)take(conn,ord(take(conn,1),0)+2);else die('socks_address');
 return conn;
}
function ping_request(last){return 'GET /generate_204 HTTP/1.1\r\nHost: www.gstatic.com\r\nUser-Agent: lanekeep-panel\r\nAccept: */*\r\nConnection: '+(last?'close':'keep-alive')+'\r\n\r\n';}
// Returns whether the server keeps the connection open for another request.
function ping_response(conn){
 let h=headers(conn),l=lc(h);
 if(!match(h,/^HTTP\/1\.1 20[04] /))die('ping_status');if(index(l,'transfer-encoding:')>=0)die('ping_encoding');
 let m=match(l,/\r\ncontent-length:[ \t]*([0-9]+)[ \t]*\r\n/),size=m?int(m[1]):0;if(size>4096)die('ping_body');if(size)take(conn,size);
 return !match(l,/\r\nconnection:[ \t]*close[ \t]*\r\n/);
}
// Only a failed first request discards the step. A warm request that fails (silent close,
// deadline) keeps what was measured; with no warm sample the caller uses the first request.
function latency(){
 let conn=null,connect=null,best=null;
 try{
  let t0=mono();conn=open('www.gstatic.com',t0+6000);
  send(conn,ping_request(false));let alive=ping_response(conn);connect=mono()-t0;
  try{for(let i=0;alive && i<2;i++){let s=mono();send(conn,ping_request(i==1));alive=ping_response(conn);let d=mono()-s;if(best==null || d<best)best=d;}}catch(e){}
  conn.c.close();return {connect_ms:connect,elapsed_ms:best};
 }catch(e){if(conn)conn.c.close();return null;}
}
function exit_ip(){
 let conn=null;
 try{
  let t0=mono();conn=open('ipinfo.io',t0+6000);
  send(conn,'GET /json HTTP/1.0\r\nHost: ipinfo.io\r\nAccept: application/json\r\nAccept-Encoding: identity\r\nConnection: close\r\n\r\n');
  let h=headers(conn),l=lc(h);if(!match(h,/^HTTP\/1\.[01] 200 /))die('http_status');
  if(index(l,'transfer-encoding:')>=0 || index(l,'content-encoding:')>=0)die('unsupported_encoding');
  let m=match(l,/\r\ncontent-length:[ \t]*([0-9]+)[ \t]*\r\n/),body;
  if(m){let size=int(m[1]);if(size<2 || size>16384)die('body_size');body=take(conn,size);}
  else{body=conn.buf;conn.buf='';while(true){let done=false;try{json(body);done=true;}catch(e){}if(done)break;if(length(body)>16384)die('body_size');fill(conn);body+=conn.buf;conn.buf='';}}
  let total=mono()-t0;conn.c.close();conn=null;
  let d=json(body);
  if(!match(d?.ip || '',/^[0-9]{1,3}(\.[0-9]{1,3}){3}$/) || !match(d?.country || '',/^[A-Z]{2}$/))die('invalid_reply');
  for(let n in split(d.ip,'.'))if(int(n)>255)die('invalid_ip');
  return {ip:d.ip,country:d.country,total_ms:total};
 }catch(e){if(conn)conn.c.close();return {error:e.message=='timeout'?'timeout':'failed'};}
}
try {
 if(fs.writefile(work+'/test-start',''+mono())==null)exit(71);
 let lat=latency(),ip=exit_ip();
 if(ip.error=='timeout'){save({ok:false,status:'timeout',message:'超时'});exit(0);}
 if(ip.error){save({ok:false,status:'failed',message:'节点请求失败或返回格式无效；未尝试直连'});exit(0);}
 let r={ok:true,status:'ok',ip:ip.ip,country:ip.country,measurement_version:3};
 if(lat?.elapsed_ms!=null){r.elapsed_ms=lat.elapsed_ms;r.connect_ms=lat.connect_ms;r.latency_basis='warm';r.message='延迟为连接建立后两次请求的较小值；首次连接含与节点握手';}
 else if(lat){r.elapsed_ms=lat.connect_ms;r.latency_basis='first_request';r.message='未取得复用连接的样本，延迟为首次请求耗时（含握手）';}
 else{r.elapsed_ms=ip.total_ms;r.latency_basis='first_request';r.message='延迟探测未完成，显示查询出口的首次请求耗时（含握手）';}
 save(r);
} catch(e) {save({ok:false,status:'failed',message:'节点请求失败或返回格式无效；未尝试直连'});}
