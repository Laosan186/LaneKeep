// Stream framing excludes startup, wait and cleanup from request time.
import * as fs from 'fs';
function mono(){let t=clock(true);if(!t)die('monotonic_clock_unavailable');return int(t[0]*1000+t[1]/1000000+0.5);}
let mode=ARGV[0],work=ARGV[1];
if(!match(work || '',/^\/tmp\/lanekeep-panel\/[a-f0-9-]{36}$/) || fs.lstat(work)?.type!='directory')exit(64);
function save(v){
 if(fs.writefile(work+'/test-result.next',sprintf('%J\n',v))==null)exit(71);
 fs.chmod(work+'/test-result.next',0600);if(!fs.rename(work+'/test-result.next',work+'/test-result'))exit(71);
}
let total=0;
function take(n){
 let s='';while(length(s)<n){let b=fs.stdin.read(n-length(s));if(!length(b||''))die('truncated');s+=b;total+=length(b);if(total>16384)die('oversize');}return s;
}
function body_result(body,finished){
 let d=json(body),start=+fs.readfile(work+'/test-start');
 if(!match(d.ip||'',/^[0-9]{1,3}(\.[0-9]{1,3}){3}$/)||!match(d.country||'',/^[A-Z]{2}$/))die('invalid_reply');
 for(let n in split(d.ip,'.'))if(int(n)>255)die('invalid_ip');
 let elapsed=finished-start;if(start<=0 || elapsed<0)die('invalid_clock');
 return {ok:true,status:'ok',ip:d.ip,country:d.country,elapsed_ms:elapsed,measurement_version:2,message:'测试完成；耗时仅覆盖本次请求'};
}
try {
 if(mode=='emit') {
  if(fs.writefile(work+'/test-start',''+mono())==null)exit(71);
  let host='ipinfo.io';printf('%c%c%c',5,1,0);printf('%c%c%c%c%c%s%c%c',5,1,0,3,length(host),host,0,80);
  print('GET /json HTTP/1.0\r\nHost: ipinfo.io\r\nAccept: application/json\r\nAccept-Encoding: identity\r\nConnection: close\r\n\r\n');exit(0);
 }
 if(mode!='stream')exit(64);
 let auth=take(2);if(ord(auth,0)!=5 || ord(auth,1)!=0)die('socks_auth');
 let rep=take(4);if(ord(rep,0)!=5 || ord(rep,1)!=0 || ord(rep,2)!=0)die('socks_connect');
 let at=ord(rep,3);if(at==1)take(6);else if(at==4)take(18);else if(at==3)take(ord(take(1),0)+2);else die('socks_address');
 let header='';while(index(header,'\r\n\r\n')<0){header+=take(1);if(length(header)>8192)die('headers');}
 if(!match(header,/^HTTP\/1\.[01] 200 /))die('http_status');
 let h=lc(header);if(index(h,'transfer-encoding:')>=0 || index(h,'content-encoding:')>=0)die('unsupported_encoding');
 let sizes=match(h,/\r\ncontent-length:[ \t]*([0-9]+)[ \t]*\r\n/),body='',finished;
 if(sizes){let size=int(sizes[1]);if(size<2 || size+total>16384)die('body_size');body=take(size);finished=mono();}
 else {
  while(true){body+=take(1);if(substr(body,-1)=='}'){try{json(body);finished=mono();break;}catch(e){}}}
 }
 save(body_result(body,finished));
} catch(e) {save({ok:false,status:'failed',message:'节点请求失败或返回格式无效；未尝试直连'});}
