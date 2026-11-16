// Independent procd sampler. Only aggregate numbers and typed events in tmpfs.
import * as fs from 'fs';
import * as model from './model.uc';
import * as store from './store.uc';
import * as snaps from './snapshots.uc';
import { collect } from './collect.uc';
import * as health from './health-store.uc';
import * as monitor from './monitor-store.uc';
import * as domestic from './domestic.uc';
function min(a,b){return a<b?a:b;}
function max(a,b){return a>b?a:b;}
function abs(a){return a<0?-a:a;}
// ubus initializes uloop signal hooks; this polling service exits explicitly.
function finish(){try{monitor.flush();}catch(e){}exit(0);}
signal('TERM',finish);signal('INT',finish);signal('HUP',finish);
let root=ARGV[0]||'/tmp/lanekeep-telemetry',port=ARGV[1]?int(ARGV[1]):10085,limit=ARGV[2]?int(ARGV[2]):0;
if(root=='/tmp/lanekeep-telemetry'&&(port!=10085||limit!=0))die('production_arguments');
store.initialize(root);
let boot=trim(fs.readfile('/proc/sys/kernel/random/boot_id')),saved=store.read('state.json');
if(saved&&saved.boot!=boot)die('unexpected_persistent_history');
if(root=='/tmp/lanekeep-telemetry'){try{health.initialize(boot);}catch(e){/* Preserve corrupt or unsafe files; report unavailable, never erase. */}}
if(root=='/tmp/lanekeep-telemetry'){try{monitor.initialize(boot);}catch(e){}}
let defs=saved?.defs||model.definitions(),seq=saved?.seq||0,minute_seq=saved?.minute_seq||0,event_seq=saved?.event_seq||0;
let previous={},previous_cpu=null,last=saved?.last||{},bucket=null,bucket_min=null,issue_starts={},events_seen=saved?.events_seen||{},snapshots=saved?.snapshots||[],last_probe=saved?.last_probe||0,last_probe_owner=saved?.last_probe_owner||'',probe_seq=saved?.probe_seq||0;
let restarts=saved?.observed_restarts||0,started=model.mono(),next=started;
function event(kind,mono,details){let e={kind,mono,wall:time()-(model.mono()-mono),details:details||{}};store.put('events.ring',512,event_seq++,e,256);}
function add_nodes(ids){for(let id in ids){if(!match(id,/^[a-z0-9_-]{1,32}$/))continue;for(let d in ['up','down']){let key='out_node-'+id+'_'+d;if(length(filter(defs,x=>x.id==key)))continue;if(length(defs)>=96)continue;push(defs,model.metric(key,'指定节点 '+id+(d=='up'?'上传':'下载'),'B/s','stats','rate'));}}}
function probe_events(){
 let peak=null;
 let owner=trim(fs.readfile('/tmp/lanekeep-dns-gate/watchdog.lock/owner')||''),s=fs.readfile('/tmp/lanekeep-dns-gate/status')||'',m=match(s,/(^|\n)rounds=([0-9]+)/),rounds=m?int(m[2]):0;
 if(owner!=last_probe_owner){last_probe=0;last_probe_owner=owner;}if(rounds<last_probe)last_probe=0;
 let f=fs.open('/tmp/lanekeep-dns-gate/probe-history','r');if(!f)return null;
 for(let n=max(last_probe+1,rounds-2047);n<=rounds;n++){f.seek((n%2048)*128,0);let row=trim(f.read(128)||''),a=split(row,/\s+/);if(length(a)!=6||int(a[2])!=n||!match(a[0],/^[0-9]+$/)||!match(a[1],/^[0-9]+$/))continue;
  let state=a[4]=='OPEN'?1:0,at=int(a[1])/100.0,ms=(int(a[1])-int(a[0]))*10;
  if(ms<0||ms>10000)continue;
  store.put('probe.ring',2048,probe_seq++,{mono:at,wall:int(time()-(model.mono()-at)),ms,ok:int(a[3]),gate:state},128);
  peak=peak==null?ms:max(peak,ms);
  if(last.probe_gate!=null&&last.probe_gate!=state)event(state?'gate_open':'gate_closed',at);
  last.probe_gate=state;last_probe=n;
 }f.close();return peak;
}
function apply_events(){
 for(let line in split(fs.readfile('/etc/lanekeep-proxy/panel-apply.log')||'','\n')){if(!length(trim(line)))continue;let a;try{a=json(line);}catch(e){continue;}
  let key=a.version+':'+a.result;if(events_seen[key])continue;events_seen[key]=true;if(last.apply_initialized){let type=match(a.result||'',/rolled_back|rollback/)?'core_rollback':'rules_apply';event(type,model.mono(),{});}
 }last.apply_initialized=true;
 if(length(keys(events_seen))>100){events_seen={};last.apply_initialized=false;}
}
function launch_events(){
 let text=fs.readfile('/tmp/lanekeep-dns-gate/telemetry-launches')||'',a=split(trim(text),' ');
 if(length(a)<3||!match(a[0],/^[0-9]+$/))return {restarts:null,partial:true};
 let count=int(a[0]),partial=a[2]=='1';
 if(count>(last.launch_count||0)){let f=fs.open('/tmp/lanekeep-dns-gate/telemetry-launch-ring','r');
  if(f){for(let n=max((last.launch_count||0)+1,count-127);n<=count;n++){f.seek((n%128)*64,0);let p=split(trim(f.read(64)||''),' ');if(int(p[0])==n){event(n==1&&!partial?'core_start_attempt':'core_restart_attempt',+p[1],{count:n});event('gate_closed',+p[1]);}}f.close();}}
 last.launch_count=count;return {restarts:partial?count:max(0,count-1),partial};
}
function take_mark(now){let r=snaps.take(snapshots,now);snapshots=r.snapshots;if(r.mark!=null)event('user_mark',r.mark,{slot:r.slot});}
event('sampler_started',started);
for(let cycle=0;!limit||cycle<limit;cycle++){
 let domestic_state=null;
 if(root=='/tmp/lanekeep-telemetry')try{domestic_state=domestic.observe();}catch(e){}
 let sample;
 try{sample=collect(port);}catch(e){sample={raw:{},sources:{},epochs:{},mono:model.mono(),wall:time(),node_ids:[]};}
 let peak=null;try{peak=probe_events();}catch(e){}
 if(peak!=null){sample.raw.probe_ms=peak;sample.sources.probe=model.mono();}else{sample.raw.probe_ms=null;}
 add_nodes(sample.node_ids);let values=[],raw=[],cpu=null;
 if(previous_cpu&&sample.raw.cpu_total!=null){let total=sample.raw.cpu_total-previous_cpu.total,busy=sample.raw.cpu_busy-previous_cpu.busy;if(total>0&&busy>=0&&sample.mono-previous_cpu.mono<=10)cpu=model.round(100.0*busy/total);}
 if(sample.raw.cpu_total!=null)previous_cpu={total:sample.raw.cpu_total,busy:sample.raw.cpu_busy,mono:sample.mono};
 for(let d in defs){let value=sample.raw[d.id];if(d.id=='cpu')value=cpu;let stamp=sample.sources[d.source],epoch=sample.epochs[d.source]??'boot';push(raw,value??null);
  let v=d.mode=='rate'?model.delta(value,stamp,epoch,previous[d.id]):value;
  push(values,model.round(v??null));if(value!=null&&stamp!=null)previous[d.id]={value,stamp,epoch};else delete previous[d.id];
 }
 let row={mono:model.round(sample.mono),wall:sample.wall,epoch:sample.core_start,sources:sample.sources,values};
 try{
  store.put('raw.ring',720,seq++,row);
  let m=int(sample.mono/60);if(bucket_min!=null&&bucket_min!=m){store.put('minute.ring',1440,minute_seq++,model.finish_roll(bucket,defs));bucket=null;}bucket_min=m;bucket=model.add_roll(bucket,row,defs);
  if(last.core_start!=null&&sample.core_start!=null&&last.core_start!=sample.core_start){restarts++;event('core_running',sample.mono);}
  if(last.wan_state!=null&&sample.raw.wan_up_state!=null&&last.wan_state!=sample.raw.wan_up_state)event(sample.raw.wan_up_state?'wan_restored':'wan_lost',sample.mono);
  if(last.default_node!=null&&sample.default_node!=null&&last.default_node!=sample.default_node)event('default_node_changed',sample.mono,{from:last.default_node,to:sample.default_node});
  if(last.wall!=null&&abs((sample.wall-last.wall)-(sample.mono-last.mono))>2)event('wall_clock_changed',sample.mono);
  last.core_start=sample.core_start;last.wan_state=sample.raw.wan_up_state;last.default_node=sample.default_node;last.wall=sample.wall;last.mono=sample.mono;
  apply_events();let launches=launch_events();take_mark(sample.mono);snaps.capture(snapshots,row);
  let issues=model.evaluate(values,defs);if(sample.sources.stats==null)push(issues,'Xray 统计不可用');
  let numeric={};for(let i=0;i<length(defs);i++)numeric[defs[i].id]=values[i];
  let monitored=monitor.observe({wall:sample.wall,mono:sample.mono,boot,epoch:sample.core_start,pid:sample.core_pid,local_addresses:sample.local_addresses,v:numeric,limit:sample.fd_limit});
  issues=filter(issues,s=>!match(s,/^入口 [0-9]+ 接收队列积压$/));
  for(let port in [12345,12346,12347,12348])if(monitored.classification?.queue_active?.[port])push(issues,'入口 '+port+' 接收队列积压');
  let journal=health.observe({wall:sample.wall,mono:sample.mono,boot,v:numeric,limit:sample.fd_limit,stats_ok:sample.sources.stats!=null,monitor:monitored.classification});
  if(monitored.classification?.fd_absolute)push(issues,'核心文件描述符异常增高（≥2000）');
  if(!monitored.storage_ok)push(issues,'监控快照或每日汇总保存不可用');
  if(sample.fd_limit>0&&numeric.core_fd>=sample.fd_limit)push(issues,'核心文件描述符达到上限');else if(sample.fd_limit>0&&numeric.core_fd>=sample.fd_limit*0.9)push(issues,'核心文件描述符接近上限');
  if(!journal.storage_ok)push(issues,'运行记录保存不可用');
  let next_issues={};for(let issue in issues)next_issues[issue]=issue_starts[issue]??sample.mono;issue_starts=next_issues;
  let status={home:{domestic:domestic_state},health:journal,monitor:monitored,fd_limit:sample.fd_limit,mono:sample.mono,wall:sample.wall,defs,row,raw,default_node:sample.default_node,issues:map(issues,s=>({message:s,since:issue_starts[s]})),restarts:launches.restarts,restarts_partial:launches.partial,observed_restarts:restarts,snapshots,retention:{raw_seconds:3600,minute_seconds:86400},unavailable:['按需四类服务 UDP443 拦截活动','DoH 域名拦截活动','FakeIP 残留拦截活动','非地址 DNS 空回应次数','blackhole 出站字节'],scope:'流量为 Xray 标签载荷统计；WAN 为接口字节。端口计数为进入透明捕获链的包数，非请求数；不含专用 SOCKS 内层端口。'};
  store.write('latest.json',status);store.write('state.json',{boot,defs,seq,minute_seq,event_seq,last,snapshots,observed_restarts:restarts,last_probe,last_probe_owner,probe_seq,events_seen});
 }catch(e){/* A failed RAM write must never touch routing, logs or flash. */}
 next+=5;let wait=next-model.mono();if(wait<=0){next=model.mono()+5;wait=5;}if(!limit||cycle+1<limit)sleep(int(wait*1000));
}

