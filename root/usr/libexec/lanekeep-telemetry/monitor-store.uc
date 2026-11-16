// Separate typed monitoring summaries and priority slots; never deletes old histories.
import * as fs from 'fs';
import * as decision from './monitor-model.uc';
import * as capture from './monitor-capture.uc';
import * as ram from './store.uc';
import * as calendar from './health-model.uc';
let ROOT='/etc/lanekeep-health',state=null,records={},dirty_slots={},trigger=decision.blank(),last_flush=-60,last_counter=-60,healthy=true;
function abs(x){return x<0?-x:x;}
function min(a,b){return a<b?a:b;}
function max(a,b){return a>b?a:b;}
function path(name){
 if(ROOT!='/etc/lanekeep-health'&&!match(ROOT,/^\/tmp\/lanekeep-proxy-stage\/fdmonitor-[0-9TZ]+\/journal$/))die('monitor_root');
 if(!match(name,/^monitor-(history|fd-[01]|aux-[01])\.json(-next)?$/))die('monitor_name');let d=fs.lstat(ROOT);if(d?.type!='directory'||d.uid!=0||(d.mode&0077)!=0)die('monitor_directory');
 let p=ROOT+'/'+name,s=fs.lstat(p);if(s&&(s.type!='file'||s.uid!=0||(s.mode&0077)!=0||s.size>524288))die('monitor_permissions');return p;
}
function read(name){let p=path(name);if(!fs.lstat(p))return null;return json(fs.readfile(p));}
function write(name,value){let p=path(name),next=path(name+'-next'),text=sprintf('%J\n',value);if(length(text)>524288)die('monitor_size');let f=fs.open(next,'w',0600);if(!f)die('monitor_open');let n=f.write(text);f.close();if(n!=length(text)||!fs.rename(next,p))die('monitor_write');}
function initialize(boot,root){ROOT=root||ROOT;let x=read('monitor-history.json');if(x){if(x.version!=1||type(x.days)!='array'||length(x.days)>30||type(x.started_wall)!='int')die('monitor_schema');state=x;}else state={version:1,started_wall:time(),days:[],last:null,counter:null};
 records={};for(let slot in ['fd-0','fd-1','aux-0','aux-1']){let s=read('monitor-'+slot+'.json');if(s&&s.slot==slot&&s.version==1)records[slot]=s;}
 trigger=decision.blank();healthy=true;
}
function daily(p,result,counter){
 let c=calendar.calendar(p.wall),d=filter(state.days,x=>x.date==c.date)[0];if(!d){d={date:c.date,start:c.start,end:c.end,first:p.wall,last:p.wall,fd_peak:null,fd_peak_at:null,valid_fd_samples:0,missing_fd_samples:0,covered_seconds:0,gap_count:0,queue_counts:{},queue_peaks:{},gate_events:0,fd_events:0,counter_generations:[],counter_unavailable_samples:0,suppressed_aux_snapshots:0};push(state.days,d);}
 let prev=state.last,dt=prev?p.mono-prev.mono:null,continuous=prev&&prev.boot==p.boot&&dt>0&&dt<=7.5&&abs(p.wall-prev.wall-dt)<=2;
 if(continuous&&prev.fd_valid&&decision.valid(p.v.core_fd)){let from=prev.wall,to=p.wall;for(let part in state.days){let overlap=min(to,part.end)-max(from,part.start);if(overlap>0)part.covered_seconds+=overlap;}}
 else if(prev)d.gap_count++;
 if(decision.valid(p.v.core_fd)){d.valid_fd_samples++;if(d.fd_peak==null||p.v.core_fd>d.fd_peak){d.fd_peak=p.v.core_fd;d.fd_peak_at=p.wall;}}else d.missing_fd_samples++;
 for(let port in decision.ports){let key=''+port;if(!d.queue_peaks[key])d.queue_peaks[key]={tcp:null,data:null,udp:null};for(let type in ['tcp','data','udp']){let n=p.v['recv_'+type+'_'+port];if(decision.valid(n))d.queue_peaks[key][type]=d.queue_peaks[key][type]==null?n:max(n,d.queue_peaks[key][type]);}}
 for(let kind in result.triggers){if(substr(kind,0,6)=='queue_'){let port=substr(kind,6);d.queue_counts[port]=(d.queue_counts[port]||0)+1;}else if(kind=='gate_closed')d.gate_events++;else d.fd_events++;}
 if(counter){if(!counter.available)d.counter_unavailable_samples++;else{
  let identity=p.boot+':'+counter.table_handle+':'+counter.rule_handle,items=d.counter_generations,last=length(items)?items[length(items)-1]:null;
  if(!last||last.identity!=identity||counter.packets<last.last_packets||counter.bytes<last.last_bytes){
   if(length(items)<16)push(items,{identity,first_wall:p.wall,last_wall:p.wall,first_packets:counter.packets,last_packets:counter.packets,first_bytes:counter.bytes,last_bytes:counter.bytes,delta_packets:0,delta_bytes:0});else d.counter_generation_overflow=true;
  }else{last.delta_packets+=counter.packets-last.last_packets;last.delta_bytes+=counter.bytes-last.last_bytes;last.last_packets=counter.packets;last.last_bytes=counter.bytes;last.last_wall=p.wall;}
 }}
 d.last=p.wall;state.last={wall:p.wall,mono:p.mono,boot:p.boot,fd_valid:decision.valid(p.v.core_fd)};
 let cutoff=calendar.calendar(c.start+43200-29*86400).date;state.days=filter(state.days,x=>x.date>=cutoff);if(length(state.days)>30)state.days=slice(state.days,-30);return d;
}
function condensed(row,defs){let v={};for(let i=0;i<length(defs);i++)v[defs[i].id]=row.values[i];return {wall:row.wall,mono:row.mono,fd:v.core_fd??null,gate:v.gate??null,queues:map(decision.ports,n=>[v['recv_tcp_'+n]??null,v['recv_data_'+n]??null,v['recv_udp_'+n]??null])};}
function window_before(p){let latest=ram.read('latest.json'),defs=latest?.defs||[],rows=ram.rows('raw.ring',720);return map(filter(rows,r=>r.mono>=p.mono-600&&r.mono<=p.mono),r=>condensed(r,defs));}
function flush(){if(state){write('monitor-history.json',state);for(let slot in keys(dirty_slots)){write('monitor-'+slot+'.json',records[slot]);delete dirty_slots[slot];}}}
function observe(p){
 if(!state)return {storage_ok:false,policy:'absolute_fd_2000',snapshots:[],days:[]};
 let begin=clock(true),result=decision.advance(trigger,p),sample_counter=null;
 try{
  if(p.mono-last_counter>=60||result.request){sample_counter=capture.counters();state.counter={...sample_counter,wall:p.wall,boot:p.boot};last_counter=p.mono;}
  let day=daily(p,result,sample_counter),saved=false;
  if(result.request){let req=result.request;
   {let now=clock(true),elapsed=(now[0]-begin[0])+(now[1]-begin[1])/1e9;let slot=decision.slot(records,req.priority),shot=capture.capture(p,req.light,max(0,2-elapsed));shot.window=window_before(p);shot.window_until=p.mono+600;shot.window_complete=false;shot.slot=slot;shot.priority=req.priority;shot.reasons=req.reasons;shot.guard=state.counter;write('monitor-'+slot+'.json',shot);records[slot]=shot;saved=true;delete dirty_slots[slot];}
  }
  for(let slot,shot in records){if(shot.window_complete)continue;if(shot.boot!=p.boot){shot.window_complete=true;shot.post_window_interrupted=true;dirty_slots[slot]=true;continue;}if(p.mono>shot.mono&&p.mono<=shot.window_until&&length(shot.window)<250){dirty_slots[slot]=true;push(shot.window,{wall:p.wall,mono:p.mono,fd:p.v.core_fd??null,gate:p.v.gate??null,queues:map(decision.ports,n=>[p.v['recv_tcp_'+n]??null,p.v['recv_data_'+n]??null,p.v['recv_udp_'+n]??null])});}if(p.mono>=shot.window_until){shot.window_complete=true;dirty_slots[slot]=true;}}
  if(p.mono-last_flush>=60||result.request||saved){flush();last_flush=p.mono;}healthy=true;
 }catch(e){healthy=false;let day=state.days[length(state.days)-1];if(day)day.capture_or_storage_failures=(day.capture_or_storage_failures||0)+1;}
 return {version:1,storage_ok:healthy,policy:{fd_absolute:2000,fd_critical_ratio:0.9,queue_consecutive:2,gate_consecutive:2,relative_baseline_enabled:false,relative_reason:'Await sufficiently covered healthy data and explicit baseline review.',priority_slots:{fd:2,aux:2},aux_cooldown_seconds:0},classification:result,started_wall:state.started_wall,counter:state.counter,days:state.days,snapshots:map(sort(keys(records)),k=>{let s={...records[k]};s.window_samples=length(s.window||[]);delete s.window;return s;}),persistence:{interval_seconds:60,maximum_slots:4,max_bytes_per_slot:524288,loss_on_power_failure:'Up to the unflushed numeric-summary interval; snapshots flush on capture.'}};
}
export {initialize,observe,daily,flush};
