// Authenticated admin-only RAM history API. No arbitrary paths or commands.
import * as fs from 'fs';
import * as uloop from 'uloop';
import * as paging from '/usr/libexec/lanekeep-telemetry/page-model.uc';
import * as store from '/usr/libexec/lanekeep-telemetry/store.uc';
import * as health from '/usr/libexec/lanekeep-telemetry/health-store.uc';
import { mono } from '/usr/libexec/lanekeep-telemetry/model.uc';
function read_data(args){
 let window=args?.window||'30m',snapshot=args?.snapshot||'none';
 if(index(['30m','6h','24h'],window)<0||index(['none','0','1'],snapshot)<0)return {ok:false,message:'无效时间范围'};
 try{
  let latest=store.read('latest.json');if(!latest)return {ok:false,message:'采样尚未启动，历史不会补造'};
  let date=args?.health_date||'';
  if(date&&latest.health){
   if(!match(date,/^[0-9]{4}-[0-9]{2}-[0-9]{2}$/)||!length(filter(latest.health.days||[],d=>d.date==date)))return {ok:false,message:'无效运行记录日期'};
   let selected=filter(latest.health.days||[],d=>d.date==date)[0];
   if(selected.closed)try{let full=health.read_day(date);selected.events=full.events;}catch(e){latest.health.detail_error='当天故障明细暂不可读，不能据此认为没有异常';}
  }
  let now=mono(),span=({'30m':1800,'6h':21600,'24h':86400})[window],rows;
  if(snapshot!='none'){let s=filter(latest.snapshots||[],x=>''+x.slot==snapshot)[0];if(!s)return {ok:false,message:'快照已轮换'};rows=store.rows('snapshot-'+snapshot+'.ring',250);span=1200;}
  else rows=filter(store.rows(window=='30m'?'raw.ring':'minute.ring',window=='30m'?720:1440),r=>r.mono>=now-span&&r.mono<=now+1);
  return {ok:true,now,window,span,latest,rows,probes:filter(store.rows('probe.ring',2048,128),r=>r.mono>=now-3600&&r.mono<=now+1),events:filter(store.rows('events.ring',512,256),r=>r.mono>=now-86400&&r.mono<=now+1),snapshot};
 }catch(e){return {ok:false,message:'内存采样暂不可读'};}
}
function read_legacy(args){
 let data=read_data(args);
 if(data?.ok&&paging.wire_total(data)>paging.MAX_WIRE)return {ok:false,code:'read_requires_paging',message:'完整历史超过旧页面传输容量，请刷新到新页面；已有历史完整保留'};
 return data;
}
// The single history snapshot belongs only to this RPC VM; no RAM files or flash.
let page_cache=null,page_expiry=uloop.timer(-1,()=>{page_cache=null;});
function read_current(){
 try{
  let latest=store.read('latest.json');if(!latest)return {ok:false,message:'采样尚未启动'};
  let now=mono();return paging.current({ok:true,now,window:'now',span:0,latest,rows:latest.row?[latest.row]:[],
   probes:filter(store.rows('probe.ring',2048,128),r=>r.mono>=now-3600&&r.mono<=now+1),events:filter(store.rows('events.ring',512,256),r=>r.mono>=now-86400&&r.mono<=now+1),snapshot:'none'});
 }catch(e){return {ok:false,message:'当前监控暂不可读'};}
}
function read_page(args){
 let a={window:args?.window||'30m',snapshot:args?.snapshot||'none',health_date:args?.health_date||'',page:args?.page??0,read_id:args?.read_id||''};
 if(index(['now','30m','6h','24h'],a.window)<0||index(['none','0','1'],a.snapshot)<0||type(a.page)!='int'||a.page<0||a.page>3)return {ok:false,code:'read_arguments',message:'历史读取参数无效'};
 if(a.window=='now'){if(a.page!=0||a.snapshot!='none'||a.health_date!='')return {ok:false,code:'read_arguments',message:'当前状态不使用历史页码'};return read_current();}
 let now=mono();if(page_cache&&now-page_cache.at>=15)page_cache=null;
 if(a.page==0){
  page_cache=null;
  let id=trim(fs.readfile('/proc/sys/kernel/random/uuid')||'');if(!match(id,/^[a-f0-9-]{36}$/)||!page_expiry)return {ok:false,message:'无法建立有界历史读取'};
  let candidate=paging.start(read_data(a),id,mono(),{window:a.window,snapshot:a.snapshot,health_date:a.health_date});
  if(!candidate.ok)return candidate;
  page_cache=candidate;page_expiry.set(15000);a.read_id=id;
 }
 return paging.page(page_cache,a,mono());
}
function mark(){
 try{
  let s=fs.lstat('/tmp/lanekeep-telemetry');if(s?.type!='directory'||s.uid!=0)return {ok:false,message:'采样尚未启动'};
  let latest=store.read('latest.json');if(!latest||mono()-latest.mono>10)return {ok:false,message:'采样已过期，不能标记'};
  if(length(filter(latest.snapshots||[],x=>!x.complete))>=2||fs.lstat('/tmp/lanekeep-telemetry/mark-request.json'))return {ok:false,message:'已有快照采集中，请稍后再标记'};
  let at=mono();if(!store.request({mono:at}))return {ok:false,message:'标记已排队，请稍后再试'};return {ok:true,mono:at,message:'已标记；采样器将在下一轮保留前后各 10 分钟，最多保留两个快照'};
 }catch(e){return {ok:false,message:'标记未保存'};}
}
return {lanekeep_telemetry:{read_page:{args:{window:'30m',snapshot:'none',health_date:'',page:0,read_id:''},call:r=>read_page(r.args)},read:{args:{window:'30m',snapshot:'none',health_date:''},call:r=>read_legacy(r.args)},mark:{args:{},call:r=>mark()}}};
