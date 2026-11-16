// Bounded SOCKS5 UDP transport test. The only directly dialed address is loopback.
import * as fs from 'fs';
import * as socket from 'socket';
import { public_ip } from './chain-udp.uc';
let work=ARGV[0],port=int(ARGV[1]),tcp=null,udp=null,result={ok:false,status:'failed',message:'UDP 临时测试未完成；未尝试其他出口'};
if(!match(work||'',/^\/tmp\/lanekeep-panel\/[a-f0-9-]{36}$/)||fs.lstat(work)?.type!='directory'||fs.readfile(work+'/.owner')!='lanekeep-chain-udp-test-v1\n'||port<20000||port>=50000)exit(64);
function mono(){let t=clock(true);if(!t)die('clock');return t[0]*1000+t[1]/1000000;}
let started=mono(),deadline=started+8000,total=0;
function take(c,n){let v='';while(length(v)<n){let wait=int(deadline-mono());if(wait<=0||!length(socket.poll(wait,c)||[]))die('timeout');let p=c.recv(n-length(v),socket.MSG_DONTWAIT);if(!length(p||''))die('truncated');v+=p;total+=length(p);if(total>8192)die('size');}return v;}
function send(c,v){if(c.send(v,socket.MSG_DONTWAIT)!=length(v))die('send');}
function u16(n){return sprintf('%c%c',(n>>8)&255,n&255);}
function number(s,i){if(i+2>length(s))die('size');return (ord(s,i)<<8)|ord(s,i+1);}
function host(v){return type(v)=='string'&&length(v)<=253&&match(v,/^[A-Za-z0-9][A-Za-z0-9.-]*\.[A-Za-z0-9]+$/)!=null;}
function random_bytes(n){let f=fs.open('/dev/urandom','r');if(!f)die('random');let v=f.read(n);f.close();if(length(v||'')!=n)die('random');return v;}
function header(target){let address='';if(public_ip(target.server)){address=sprintf('%c',1);for(let x in split(target.server,'.'))address+=sprintf('%c',int(x));}else{if(!host(target.server)||match(target.server,/^[0-9.]+$/))die('target');address=sprintf('%c%c',3,length(target.server))+target.server;}return sprintf('%c%c%c',0,0,0)+address+u16(target.port);}
function request(target,payload){
 send(udp,header(target)+payload);let wait=int(deadline-mono());if(wait<=0||!length(socket.poll(wait,udp)||[]))die('timeout');let d=udp.recv(4096,socket.MSG_DONTWAIT);total+=length(d||'');if(total>8192||length(d||'')<10||substr(d,0,3)!=sprintf('%c%c%c',0,0,0))die('udp_frame');
 let at=ord(d,3),off=4;if(at==1)off+=4;else if(at==3){if(length(d)<5)die('udp_frame');off+=1+ord(d,4);}else die('udp_address');
 if(off+2>length(d)||number(d,off)!=target.port)die('udp_target');return substr(d,off+2);
}
function dns_query(target){
 if(target.port!=53||!host(target.name))die('dns_target');let id=random_bytes(2),q='';for(let part in split(target.name,'.')){if(!length(part)||length(part)>63)die('dns_name');q+=sprintf('%c',length(part))+part;}q+=sprintf('%c',0)+u16(1)+u16(1);
 let body=request(target,id+u16(0x0100)+u16(1)+u16(0)+u16(0)+u16(0)+q);
 if(length(body)<12+length(q)||substr(body,0,2)!=id||(number(body,2)&0xfa0f)!=0x8000||number(body,4)!=1||number(body,6)<1||substr(body,12,length(q))!=q)die('dns_reply');
 let off=12+length(q),answers=number(body,6),found=false;if(answers>16)die('dns_size');
 function skip_name(at){let labels=0;while(true){if(at>=length(body)||++labels>128)die('dns_name');let n=ord(body,at++);if(n==0)return at;if((n&0xc0)==0xc0){if(at>=length(body)||(((n&63)<<8)|ord(body,at))>=length(body))die('dns_pointer');return at+1;}if(n>63||at+n>length(body))die('dns_name');at+=n;}}
 for(let i=0;i<answers;i++){off=skip_name(off);if(off+10>length(body))die('dns_size');let kind=number(body,off),cls=number(body,off+2),size=number(body,off+8);off+=10;if(off+size>length(body))die('dns_size');if(kind==1&&cls==1&&size==4)found=true;off+=size;}
 if(!found)die('dns_answer');
 // Transport test only. No answer addresses or domain records are retained.
 return true;
}
function stun_query(target){
 if(type(target.port)!='int'||target.port<1||target.port>65535||target.port==443||target.port==53||target.port==853)die('stun_target');
 let cookie=sprintf('%c%c%c%c',0x21,0x12,0xa4,0x42),tx=random_bytes(12),body=request(target,u16(1)+u16(0)+cookie+tx);
 if(length(body)<20||number(body,0)!=0x0101||number(body,2)+20!=length(body)||substr(body,4,4)!=cookie||substr(body,8,12)!=tx)die('stun_reply');
 let ip=null;for(let off=20;off<length(body);){if(off+4>length(body))die('stun_attribute');let kind=number(body,off),size=number(body,off+2);off+=4;if(off+size>length(body))die('stun_attribute');
  if(kind==0x0020){if(ip!=null||size!=8||ord(body,off)!=0||ord(body,off+1)!=1)die('stun_address');let octets=[];for(let i=0;i<4;i++)push(octets,''+(ord(body,off+4+i)^ord(cookie,i)));ip=join('.',octets);if(!public_ip(ip)||(number(body,off+2)^0x2112)==0)die('stun_address');}
  off+=(size+3)&~3;if(off>length(body))die('stun_padding');
 }if(ip==null)die('stun_address');return ip;
}
try{
 if(fs.lstat(work+'/test-targets.json')?.type!='file'||fs.stat(work+'/test-targets.json').size>2048)die('targets');let targets=json(fs.readfile(work+'/test-targets.json'));
 if(type(targets)!='object'||type(targets.dns)!='object'||type(targets.stun)!='object')die('targets');
 if(fs.writefile(work+'/test-start',''+int(started))==null||!fs.chmod(work+'/test-start',0600))die('storage');
 tcp=socket.connect({address:'127.0.0.1',port},null,{family:socket.AF_INET,socktype:socket.SOCK_STREAM},300);if(!tcp)die('local_connect');
 send(tcp,sprintf('%c%c%c',5,1,0));if(take(tcp,2)!=sprintf('%c%c',5,0))die('socks_auth');
 send(tcp,sprintf('%c%c%c%c%c%c%c%c%c%c',5,3,0,1,127,0,0,1,0,0));let response=take(tcp,10);
 if(substr(response,0,4)!=sprintf('%c%c%c%c',5,0,0,1)||number(response,8)!=port)die('socks_associate');
 let address=substr(response,4,4);if(address!=sprintf('%c%c%c%c',127,0,0,1)&&address!=sprintf('%c%c%c%c',0,0,0,0))die('local_relay');
 udp=socket.connect({address:'127.0.0.1',port},null,{family:socket.AF_INET,socktype:socket.SOCK_DGRAM},300);if(!udp)die('local_udp');
 dns_query(targets.dns);let ip=stun_query(targets.stun);result={ok:true,status:'ok',ip,udp_dns:true,stun:true,elapsed_ms:int(mono()-started),message:'临时 UDP 传输测试完成'};
}catch(e){ /* No raw exception, packet, query name or target values. */ }
if(udp)udp.close();if(tcp)tcp.close();
if(fs.writefile(work+'/test-result.next',sprintf('%J\n',result))==null||!fs.chmod(work+'/test-result.next',0600)||!fs.rename(work+'/test-result.next',work+'/test-result'))exit(71);
