// Private worker: bounded numeric dialing, HTTPS verification, no direct fallback.
import * as fs from 'fs';
import * as socket from 'socket';
import * as policy from './subscription-policy.uc';
import * as http from './subscription-model.uc';
import * as dns from './subscription-dns.uc';
function mono(){let t=clock(true);return t[0]+t[1]/1e9;}
function bad(){die('fetch_failed');}
let mode=ARGV[0],work=ARGV[1],failure_stage='input',owned=false;
function regular(p){let s=fs.lstat(p);return s?.type=='file'&&s.uid==0&&(s.mode&0077)==0;}
function read(name,limit){let p=work+'/'+name;if(!regular(p)||fs.stat(p).size>limit)bad();return fs.readfile(p);}
function write(name,s){let p=work+'/'+name;if(fs.lstat(p)!=null&&!regular(p))bad();let used=0;for(let n in fs.lsdir(work)||[]){if(!regular(work+'/'+n))bad();if(n!=name)used+=fs.stat(work+'/'+n).size;}if(used+length(s)>policy.LIMITS.work)bad();let f=fs.open(p,'w',384);if(!f)bad();let n=f.write(s);f.close();if(n!=length(s)||!fs.chmod(p,384))bad();}
function total(){let n=0;for(let name in fs.lsdir(work)||[]){if(!regular(work+'/'+name))bad();n+=fs.stat(work+'/'+name).size;}if(n>policy.LIMITS.work)bad();}
function exchange(port){
 let meta=json(read('exchange.json',8192)),request=read('request.bin',policy.LIMITS.headers+65535),conn=null,start=mono(),first=false,raw='',h=null;
 if(meta.deadline<=start||meta.deadline-start>60||port<20000||port>=50000)bad();
 try{
  conn=socket.connect({address:'127.0.0.1',port},null,{family:socket.AF_INET,socktype:socket.SOCK_STREAM},1000);if(!conn)bad();
  let sent=0;while(sent<length(request)){if(mono()>meta.deadline||mono()-start>10)bad();let n=conn.send(substr(request,sent),socket.MSG_DONTWAIT);if(n==null||n<=0)bad();sent+=n;}
  while(true){let remaining=meta.deadline-mono();if(!first&&start+10-mono()<remaining)remaining=start+10-mono();if(remaining<=0)bad();let events=socket.poll(int(remaining*1000),conn);if(!length(events||[]))bad();let data=conn.recv(16384,socket.MSG_DONTWAIT);if(data==null)bad();if(!length(data))break;first=true;raw+=data;
   if(!h)h=http.head(raw);if(length(raw)>policy.LIMITS.body+policy.LIMITS.headers||h&&length(raw)-h.offset>policy.LIMITS.body)bad();
   if(h&&h.transfer=='identity'&&h.size!=null&&length(raw)>=h.offset+h.size)break;
  }
  conn.close();conn=null;let response=http.parse_http(raw);
  write('response-body',response.body);delete response.body;write('response.json',sprintf('%J',response));total();
 }catch(e){if(conn)conn.close();bad();}
}
function hop(input,target,pin,request,deadline,port){
 if(mono()>=deadline)bad();let config=http.build_config(input.node,target.host,target.port,port,pin,input.channel);
 write('test-config.json',sprintf('%J',config));write('exchange.json',sprintf('%J',{deadline}));write('request.bin',request);total();
 let rc=system('/usr/libexec/lanekeep-panel/subscription-hop '+work+' '+port+' >/dev/null 2>&1');if(rc!=0||mono()>=deadline)bad();
 let value=json(read('response.json',8192));value.body=read('response-body',policy.LIMITS.body);return value;
}
function request(target,ua,body){
 let h=(body==null?'GET ':'POST ')+target.path+' HTTP/1.1\r\nHost: '+target.host+(target.port==443?'':':'+target.port)+'\r\nUser-Agent: '+policy.ua(ua)+'\r\nAccept-Encoding: identity\r\nConnection: close\r\n';
 h+=body==null?'Accept: text/plain\r\n':'Accept: application/dns-message\r\nContent-Type: application/dns-message\r\nContent-Length: '+length(body)+'\r\n';h+='\r\n';if(length(h)>policy.LIMITS.headers)bad();return h+(body||'');
}
function resolve(input,target,deadline,port){
 if(match(target.host,/^[0-9.]+$/))return policy.addresses([target.host]);
 let id=int(substr(replace(work,/-/g,''),-4),16)&65535,query=dns.query(target.host,id),response=null;
 if(input.channel=='proxy'){
  // Derive the existing protected real-DoH anchor; no new resolver and no use of 1053.
  let live=json(fs.readfile('/etc/lanekeep-proxy/config.json')),anchors=filter(live?.dns?.servers||[],s=>s.tag=='protected-real-dns'&&index(s.domains||[],'geosite:connectivity-check')>=0&&s.skipFallback==true&&s.finalQuery==true);
  if(length(anchors)!=1)bad();let resolver=policy.url(anchors[0].address);if(!policy.public_v4(resolver.host))bad();
  let r=hop(input,resolver,resolver.host,request(resolver,policy.DEFAULT_UA,query),deadline,port);if(r.status!=200||index(r.content_type,'application/dns-message')!=0)bad();response=r.body;
 }else{
  // Existing system resolver path; do not rewrite it or add a fallback.
  let list=[];for(let line in split(fs.readfile('/etc/resolv.conf')||'','\n')){let m=match(trim(line),/^nameserver\s+([0-9.]+)(\s|$)/);if(m)push(list,m[1]);}if(!length(list))bad();
  let a=iptoarr(list[0]);if(!a||length(a)!=4)bad();let conn=socket.connect({address:list[0],port:53},null,{family:socket.AF_INET,socktype:socket.SOCK_DGRAM},1000);if(!conn)bad();
  try{if(conn.send(query,socket.MSG_DONTWAIT)!=length(query))bad();let wait=deadline-mono();if(wait>10)wait=10;if(wait<=0||!length(socket.poll(int(wait*1000),conn)||[]))bad();response=conn.recv(65535,socket.MSG_DONTWAIT);conn.close();conn=null;}catch(e){if(conn)conn.close();bad();}
 }
 let parsed=dns.answer(response,target.host,id);policy.addresses(parsed.all_addresses);return policy.addresses(parsed.addresses);
}
try{
 if(!match(work||'',/^\/tmp\/lanekeep-sub-cache\/\.work-[a-f0-9-]{36}$/)||fs.lstat(work)?.type!='directory'||fs.lstat(work).uid!=0||(fs.lstat(work).mode&0077)!=0||read('.owner',64)!='lanekeep-sub-work-v1\n')bad();
 owned=true;
 if(mode=='exchange'){exchange(int(ARGV[2]));exit(0);}
 if(mode!='fetch')bad();let input=json(read('input.json',1048576));if(index(['proxy','direct'],input.channel)<0||input.channel=='direct'&&input.direct_confirmed!=true)bad();
 let deadline=mono()+59,target=policy.url(input.url),visited={},port=20000+(int(substr(replace(work,/-/g,''),-6),16)%30000);
 for(let step=0;step<=policy.LIMITS.redirects;step++){
  if(visited[target.value])bad();visited[target.value]=true;failure_stage='dns';let ips=resolve(input,target,deadline,port);failure_stage='https';let r=hop(input,target,ips[0],request(target,input.ua,null),deadline,port);
  if(r.status==200){write('body',r.body);write('result.json',sprintf('%J',{ok:true,usage:r.usage,redirects:step,channel:input.channel}));for(let f in ['response-body','request.bin'])if(regular(work+'/'+f))fs.unlink(work+'/'+f);total();exit(0);}
  if(index([301,302,303,307,308],r.status)<0||step==policy.LIMITS.redirects)bad();target=policy.redirect(target,r.location);
 }
 bad();
}catch(e){
 // Only fixed categories in this request's existing private result file.
 // Exchange errors propagate to the parent, which owns the DNS/HTTPS stage.
 if(mode=='fetch'&&owned)try{if(read('.owner',64)=='lanekeep-sub-work-v1\n')write('result.json',sprintf('%J',{ok:false,stage:failure_stage}));}catch(ignore){}
 exit(71);
}
