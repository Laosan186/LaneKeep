// One 16-byte IPv4 echo every 60 seconds through the existing WAN route.
// Payload, destination and command output are never stored. No DNS or rule changes.
import * as fs from 'fs';
let ROOT='/tmp/lanekeep-telemetry',cached=null,boot=null;
function mono(){let c=clock(true);return c[0]+c[1]/1e9;}
function read(){
 let s=fs.lstat(ROOT+'/domestic.json');if(s?.type!='file'||s.uid!=0||(s.mode&0077)!=0||s.size>2048)return null;
 try{return json(fs.readfile(ROOT+'/domestic.json'));}catch(e){return null;}
}
function save(x){
 let d=fs.lstat(ROOT);if(d?.type!='directory'||d.uid!=0||!match(fs.readfile('/proc/mounts')||'',/(^|\n)[^ ]+ \/tmp tmpfs /))return;
 for(let n in ['domestic.json','domestic-next.json']){let s=fs.lstat(ROOT+'/'+n);if(s&&(s.type!='file'||s.uid!=0||(s.mode&0077)!=0))return;}
 let t=sprintf('%J\n',x);if(length(t)>2048)return;let f=fs.open(ROOT+'/domestic-next.json','w',0600);if(!f)return;
 let n=f.write(t);f.close();if(n==length(t))fs.rename(ROOT+'/domestic-next.json',ROOT+'/domestic.json');
}
function command(text){let p=fs.popen(text+' 2>/dev/null','r');if(!p)return {rc:-1,text:''};let t=p.read(2048)||'',rc=p.close();return {rc,text:t};}
function observe(){
 let at=mono();if(boot==null)boot=trim(fs.readfile('/proc/sys/kernel/random/boot_id')||'');
 if(cached==null){let x=read();if(x?.version==1&&x.boot==boot&&(type(x.mono)=='double'||type(x.mono)=='int')&&x.mono>=0&&x.mono<=at&&type(x.available)=='bool'&&(x.ok==null||type(x.ok)=='bool')&&type(x.attempts)=='int'&&x.attempts>=0&&type(x.failures)=='int'&&x.failures>=0&&x.failures<=x.attempts){
  cached={version:1,boot,available:x.available,ok:x.ok,mono:x.mono,wall:x.wall,elapsed_ms:(type(x.elapsed_ms)=='double'||type(x.elapsed_ms)=='int')&&x.elapsed_ms>=0&&x.elapsed_ms<=3000?x.elapsed_ms:null,interval_seconds:60,attempts:x.attempts,failures:x.failures,reason:x.available?(x.ok?'国内直连有回应':'国内对照未应答，不能单凭这一项判定宽带故障'):'国内对照暂不可用'};
 }}
 if(cached&&at-cached.mono<60)return cached;
 let next={version:1,boot,available:false,ok:null,mono:at,wall:time(),elapsed_ms:null,interval_seconds:60,attempts:(cached?.attempts||0),failures:(cached?.failures||0),reason:'国内对照暂不可用'};
 cached=next;save(next);
 let route=command('ip -4 route get 223.5.5.5');
 if(route.rc==0&&match(route.text,/(^|\s)dev [A-Za-z0-9_.:-]+(\s|$)/)){
  let r=command('ping -4 -n -c 1 -W 2 -s 16 223.5.5.5'),m=match(r.text,/time=([0-9]+(\.[0-9]+)?) ms/);
  if(r.rc==0||r.rc==1){next.available=true;next.ok=r.rc==0&&m!=null;next.elapsed_ms=next.ok?+m[1]:null;next.attempts++;if(!next.ok)next.failures++;next.reason=next.ok?'国内直连有回应':'国内对照未应答，不能单凭这一项判定宽带故障';}
 }else next.reason='当前无法确认国内直连路径，未发检测请求';
 cached=next;save(next);return next;
}
export {observe};
