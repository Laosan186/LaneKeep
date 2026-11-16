import * as lan from './network.uc';
// Read-only home-page evidence. Only local-device observations live in tmpfs.
// No visits, names queried, remote destinations, packet captures, or flash writes.
import * as fs from 'fs';
let ROOT='/tmp/lanekeep-home',STATE=ROOT+'/devices.json';
function mono(){let x=clock(true);return x[0]+x[1]/1e9;}
function valid_ip(x){return lan.member(x);}
function num(x){return (type(x)=='int'||type(x)=='double')&&x>=0&&x<1e12;}
function run(s){let p=fs.popen(s+' 2>/dev/null','r');if(!p)return null;let x=p.read('all'),rc=p.close();return rc==0?x:null;}
function object(path,max){let s=fs.lstat(path);if(s?.type!='file'||s.uid!=0||(s.mode&0077)!=0||s.size>max)return null;try{return json(fs.readfile(path));}catch(e){return null;}}
function members(raw,expected){
 let parsed;try{parsed=json(raw);}catch(e){return {ok:null,groups:{}};}
 if(type(parsed?.nftables)!='array')return {ok:null,groups:{}};
 let checked={},actual_groups={},all=true;
 for(let g in ['global','enhanced','ondemand']){
  let found=filter(parsed.nftables,x=>x.set?.table=='lanekeep_phone'&&x.set?.name=='lanekeep_grp_'+g);
  if(length(found)!=1){checked[g]=false;all=false;continue;}
  let set=found[0].set,actual=[],valid=set.type=='ipv4_addr';
  for(let element in set.elem||[]){let v=type(element)=='object'?(element.elem?.val??element.val):element;if(!valid_ip(v)){valid=false;break;}push(actual,v);}
  let want=expected[g]||[];
  checked[g]=valid&&sprintf('%J',sort(actual))==sprintf('%J',sort([...want]));actual_groups[g]=valid?actual:null;all=all&&checked[g];
 }
 return {ok:all,groups:checked,actual:actual_groups};
}
function neighbours(raw){
 let out={};if(raw==null)return null;
 for(let line in split(raw,'\n')){let a=split(trim(line),/\s+/);if(!valid_ip(a[0]))continue;let state=null;
  for(let word in a)if(index(['REACHABLE','FAILED','INCOMPLETE','STALE','DELAY','PROBE','PERMANENT','NOARP'],word)>=0)state=word;
  out[a[0]]=state;
 }return out;
}
function blank(boot,at){return {version:1,boot,first_mono:at,last_mono:at,last_readable:false,coverage:[],devices:{}};}
function restore(x,boot,at){
 if(x?.version!=1||x.boot!=boot||!num(x.first_mono)||!num(x.last_mono)||x.last_mono>at||type(x.coverage)!='array'||length(x.coverage)>240||type(x.devices)!='object'||length(keys(x.devices))>253)return blank(boot,at);
 for(let pair in x.coverage)if(type(pair)!='array'||length(pair)!=2||!num(pair[0])||!num(pair[1])||pair[1]<pair[0]||pair[1]>at)return blank(boot,at);
 for(let ip,d in x.devices){if(!valid_ip(ip)||type(d)!='object'||type(d.events)!='array'||length(d.events)>120||index(['REACHABLE','FAILED','unknown'],d.state)<0)return blank(boot,at);for(let t in d.events)if(!num(t)||t>at)return blank(boot,at);
  if(d.last_reachable!=null&&(!num(d.last_reachable)||d.last_reachable>x.last_mono))return blank(boot,at);
  if(d.failure_counted!=null&&type(d.failure_counted)!='bool')return blank(boot,at);
 }
 return x;
}
function observe(s,current,hosts,at){
 let dt=at-s.last_mono,continuous=dt>0&&dt<=20;
 if(continuous&&current!=null&&s.last_readable){let tail=s.coverage[length(s.coverage)-1];if(tail&&tail[1]==s.last_mono)tail[1]=at;else push(s.coverage,[s.last_mono,at]);}
 s.coverage=filter(s.coverage,x=>x[1]>at-3600);if(length(s.coverage)>240)s.coverage=slice(s.coverage,-240);
 let observed=0;for(let pair in s.coverage)observed+=pair[1]-max(pair[0],at-3600);
 let out={},keep={};
 for(let h in hosts){if(!valid_ip(h.ip))continue;let raw=current?.[h.ip],state=raw=='REACHABLE'?'REACHABLE':raw=='FAILED'?'FAILED':'unknown',previous=s.devices[h.ip],events=filter(previous?.events||[],t=>t>=at-3600&&t<=at);
  let chain=continuous&&current!=null&&s.last_readable,last_reachable=chain?previous?.last_reachable:null,failure_counted=chain&&previous?.failure_counted==true;
  if(last_reachable!=null&&at-last_reachable>120)last_reachable=null;
  if(state=='REACHABLE'){last_reachable=at;failure_counted=false;}
  else if(state=='FAILED'&&last_reachable!=null&&!failure_counted){push(events,at);failure_counted=true;}
  if(length(events)>120)events=slice(events,-120);keep[h.ip]={state,events,last_reachable:last_reachable??null,failure_counted};
  out[h.ip]={online:state=='REACHABLE'?true:state=='FAILED'?false:null,unstable:length(events)>0,drops_1h:length(events),observed_seconds:int(observed),history_complete:observed>=3595,observation:state=='REACHABLE'?'最近有响应':state=='FAILED'?'最近一次探测未应答':'暂未确认',observation_source:'系统邻居表；未主动探测设备'};
 }
 s.devices=keep;s.last_mono=at;s.last_readable=current!=null;return out;
}
function save(s){
 if(!match(fs.readfile('/proc/mounts')||'',/(^|\n)tmpfs \/tmp tmpfs /))return false;
 let d=fs.lstat(ROOT);if(d&&(d.type!='directory'||d.uid!=0||(d.mode&0077)!=0))return false;if(!d&&!fs.mkdir(ROOT,0700))return false;
 for(let p in [STATE,STATE+'-next']){let st=fs.lstat(p);if(st&&(st.type!='file'||st.uid!=0||(st.mode&0077)!=0))return false;}
 let text=sprintf('%J\n',s);if(length(text)>262144)return false;let f=fs.open(STATE+'-next','w',0600);if(!f)return false;let n=f.write(text);f.close();return n==length(text)&&fs.rename(STATE+'-next',STATE);
}
function fallback(f){return f?.action=='direct'?'直连':f?.action=='node'?'走指定节点':f?.action=='proxy'?'走代理':'尚未核实';}
function rule_text(group,config,verified){
 if(!verified)return '现役规则尚未核实';
 let text=({standard:'明确国外走代理，国内直连',global:'大多走代理，保留局域网及已设定的直连例外',enhanced:'明确国外及苹果、微软等预设服务走代理，国内直连',ondemand:'已设定的国外视频服务走代理'})[group]||'分组未知';
 let selected=config.group_nodes?.[group];if(selected)text=replace(text,/走代理/g,'走本组节点');
 text+='；其余'+(selected&&config.fallbacks?.[group]?.action=='proxy'?'走本组节点':fallback(config.fallbacks?.[group]));let n=length(filter(config.rules||[],r=>r.group==group&&r.enabled=='1'));
 if(n)text+='；'+n+' 条自定规则优先';return text;
}
function supervisor(){
 let x=object('/tmp/lanekeep-sampler-supervisor/state.json',4096),boot=trim(fs.readfile('/proc/sys/kernel/random/boot_id')||'');if(x?.version!=1||x.boot!=boot)return {available:false,retry_seconds:60};
 let last=null,e=x.last_exit;if(e&&index(['exit','signal','unknown'],e.kind)>=0)last={wall:e.wall,mono:e.mono,kind:e.kind,exit_code:e.exit_code,signal:e.signal,runtime_seconds:e.runtime_seconds};
 return {available:true,launches:x.launches,exits:x.exits,recording_since_wall:x.recording_since_wall,started_wall:x.started_wall,retry_seconds:60,last_exit:last,phase:x.phase,ring_overwritten:x.ring_overwritten,count_basis:'自监督记录开始以来的启动尝试；不含此前启动，不能当作本次开机完整重启数'};
}
function privacy(){
 try{let s=fs.lstat('/etc/lanekeep-proxy/config.json');if(s?.type!='file'||s.size>2097152)return null;let c=json(fs.readfile('/etc/lanekeep-proxy/config.json')),l=c?.log;return l?.access=='none'&&l?.error=='none'&&l?.loglevel=='none'&&l?.dnsLog==false;}catch(e){return null;}
}
function device_rule_ok(device,checked,verified){
 if(verified!=true)return false;
 if(device.group=='standard')return checked.ok==true;
 if(checked.groups?.[device.group]!=true)return false;
 // A changed earlier group must not silently steal this device's address.
 for(let g in ['global','enhanced','ondemand'])if(index(checked.actual?.[g]||[],device.ip)>=0)return g==device.group;
 return false;
}
function adblocking(config,verified){
 let groups={};for(let g in ['standard','global','enhanced','ondemand']){
  let rows=filter(config.rules||[],r=>r.group==g&&r.type=='geosite'&&r.value=='category-ads-all'&&r.action=='block');
  let enabled=length(rows)==1&&rows[0].enabled=='1';
  groups[g]={enabled:enabled,verified:verified==true&&length(rows)<=1};
 }
 return {engine:'Xray',category:'category-ads-all',groups:groups,configuration_verified:verified==true,visits_recorded:false};
}
function read(hosts,config,verified){
 let at=mono(),boot=trim(fs.readfile('/proc/sys/kernel/random/boot_id')||''),m=members(run('nft -j list table inet lanekeep_phone'),config.members),n=neighbours(run('ip -4 neigh show dev '+lan.context().device));
 let s=restore(object(STATE,262144),boot,at),observed=observe(s,n,hosts,at),stored=save(s),rules=verified==true&&m.ok==true;
 let devices=[];for(let h in hosts){let d=observed[h.ip]||{online:null,unstable:false,drops_1h:0,observed_seconds:0,history_complete:false,observation:'暂未确认'};push(devices,{ip:h.ip,name:h.name,group:h.group,rule_text:rule_text(h.group,config,verified),rule_ok:device_rule_ok(h,m,verified),...d});}
 return {wall:time(),mono:at,devices,rules_checked:rules,rules_message:rules?'分组和现役规则与设定一致；未核验逐设备实际流量走向':'分组或现役规则未能确认一致',policy_check:{rules_match:verified==true,members_match:m.ok,groups:m.groups},device_history_memory_only:true,device_history_ok:stored,device_history_basis:'仅页面读取时被动观察；未应答不等于实际断网，睡眠设备可能没有新响应',supervisor:supervisor(),privacy_ok:privacy(),adblocking:adblocking(config,verified)};
}
function max(a,b){return a>b?a:b;}
export {read,members,neighbours,blank,restore,observe,rule_text,device_rule_ok,supervisor,privacy,adblocking};
