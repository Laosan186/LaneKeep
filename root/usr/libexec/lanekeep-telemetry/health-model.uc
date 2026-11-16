// Typed operational incidents only. Never accepts messages, hosts, IPs or tuples.
let ports=[12345,12346,12347,12348];
let codes=['gate_closed','wan_down','core_unknown','fd_high','fd_full','fd_absolute','cpu_high','memory_low','stats_unavailable','metrics_incomplete','observation_gap','clock_changed'];
for(let p in ports)push(codes,'queue_'+p);
function min(a,b){return a<b?a:b;}
function max(a,b){return a>b?a:b;}
function abs(a){return a<0?-a:a;}
function utc(y,m,d,h){return timegm({year:y,mon:m,mday:d,hour:h||0,min:0,sec:0});}
function offset(t){
 let y=gmtime(t).year,mar=utc(y,3,1),nov=utc(y,11,1);
 let spring=utc(y,3,8+(7-gmtime(mar).wday)%7,10),fall=utc(y,11,1+(7-gmtime(nov).wday)%7,9);
 return t>=spring&&t<fall?-25200:-28800;
}
function midnight(nominal){let t=nominal+28800;return nominal-offset(t);}
function calendar(t){
 let d=gmtime(t+offset(t)),nom=utc(d.year,d.mon,d.mday);
 return {date:sprintf('%04d-%02d-%02d',d.year,d.mon,d.mday),start:midnight(nom),end:midnight(nom+86400)};
}
function blank(boot){return {version:1,boot,last_wall:null,last_mono:null,days:[],active:{}};}
function day(s,t){
 let c=calendar(t);for(let d in s.days)if(d.date==c.date)return d;
 let d={date:c.date,start:c.start,end:c.end,observed:0,incomplete:true,closed:false,counts:{},events:[],overflow:0};push(s.days,d);s.days=sort(s.days,(a,b)=>a.start-b.start);return d;
}
function record(d,code,start,status,peak){
 d.counts[code]=(d.counts[code]||0)+1;
 let e={code,start,last:start,end:null,status:status||'active',seconds:0,peak:peak??null,evidence:{}};
 if(length(d.events)<64)push(d.events,e);else d.overflow++;
 return e;
}
function conditions(v,limit,stats,monitor){
 let q={gate_closed:v.gate==null?null:v.gate==0,wan_down:v.wan_up_state==null?null:v.wan_up_state==0,core_unknown:v.core_uptime==null,cpu_high:v.cpu==null?null:v.cpu>=85,memory_low:v.mem_available==null?null:v.mem_available<128,stats_unavailable:!stats,metrics_incomplete:v.gate==null||v.wan_up_state==null||v.cpu==null||v.mem_available==null||v.core_fd==null||limit==null};
 let valid=limit!=null&&limit>0&&v.core_fd!=null;
 q.fd_absolute=monitor?monitor.fd_absolute:(v.core_fd==null?null:v.core_fd>=2000);
 q.fd_full=valid?v.core_fd>=limit:null;q.fd_high=valid?v.core_fd>=limit*0.9&&v.core_fd<limit:null;
 for(let p in ports){let a=v['recv_tcp_'+p],b=v['recv_data_'+p],c=v['recv_udp_'+p];q['queue_'+p]=monitor?monitor.queue_active?.[p]:(a==null&&b==null&&c==null?null:(a>0||b>0||c>0));}
 return q;
}
function peak(code,v,limit){
 if(code=='fd_full'||code=='fd_high'||code=='fd_absolute')return v.core_fd;
 if(code=='cpu_high')return v.cpu;if(code=='memory_low')return v.mem_available;
 let m=match(code,/^queue_([0-9]+)$/);if(m)return v['recv_tcp_'+m[1]]??null;
 return null;
}
function interrupt(s){for(let code,e in s.active){e.status='unconfirmed';e.end=null;}s.active={};}
function advance(s,p){
 let d=day(s,p.wall),dt=s.last_mono==null?null:p.mono-s.last_mono,wall_dt=s.last_wall==null?null:p.wall-s.last_wall;
 let continuous=s.boot==p.boot&&dt!=null&&dt>0&&dt<=10&&abs(wall_dt-dt)<=2,changed=false;
 if(continuous){
  let from=s.last_wall,to=p.wall;
  while(from<to){let part=day(s,from),until=min(to,part.end);part.observed+=until-from;from=until;}
  for(let code,e in s.active){
   let old=day(s,e.last);
   if(old.date!=d.date){let split_at=old.end;e.seconds+=max(0,split_at-e.last);e.last=split_at;e.end=split_at;e.status='continued';let n=record(d,code,d.start,'active',e.peak);n.evidence={...e.evidence};n.seconds=max(0,p.wall-d.start);n.last=p.wall;s.active[code]=n;changed=true;}
   else{e.seconds+=dt;e.last=p.wall;}
  }
 }else if(s.last_wall!=null){
  interrupt(s);let code=s.boot==p.boot&&wall_dt!=null&&dt!=null&&abs(wall_dt-dt)>2?'clock_changed':'observation_gap';
  let e=record(d,code,p.wall,'unconfirmed',null);e.end=p.wall;e.last=p.wall;e.seconds=wall_dt!=null&&wall_dt>0?wall_dt:0;changed=true;
 }
 let q=conditions(p.v,p.limit,p.stats_ok,p.monitor);
 for(let code in keys(q)){
  let value=q[code],e=s.active[code],value_peak=peak(code,p.v,p.limit);
  if(value==true){
   if(!e){e=record(d,code,p.wall,'active',value_peak);s.active[code]=e;changed=true;}
   else if(value_peak!=null)e.peak=e.peak==null?value_peak:(code=='memory_low'?min(e.peak,value_peak):max(e.peak,value_peak));
   if(code=='fd_full'||code=='fd_high'||code=='fd_absolute')e.evidence.fd_limit=p.limit;
   let qm=match(code,/^queue_([0-9]+)$/);if(qm)for(let kind in ['tcp','data','udp']){let n=p.v['recv_'+kind+'_'+qm[1]];if(n!=null)e.evidence[kind]=max(e.evidence[kind]||0,n);}
  }else if(e){e.status=value==null?'unconfirmed':'recovered';e.end=value==null?null:p.wall;e.last=p.wall;delete s.active[code];changed=true;}
 }
 for(let x in s.days){
  if(x.end<=p.wall&&!x.closed){x.closed=true;changed=true;}
  x.incomplete=x.observed<(x.closed?x.end-x.start:p.wall-x.start)-1;
 }
 // Keep today's date and the preceding 29 calendar dates, not 30*24h across DST.
 let cutoff=calendar(p.wall).date,nom=utc(gmtime(p.wall+offset(p.wall)).year,gmtime(p.wall+offset(p.wall)).mon,gmtime(p.wall+offset(p.wall)).mday)-29*86400;
 let earliest=midnight(nom);s.days=filter(s.days,x=>x.start>=earliest);if(length(s.days)>30)s.days=slice(s.days,-30);
 s.last_wall=p.wall;s.last_mono=p.mono;s.boot=p.boot;
 return {changed,conditions:q};
}
function saved(s){return {version:1,boot:s.boot,last_wall:s.last_wall,last_mono:s.last_mono,days:s.days};}
function exact(o,wanted){if(type(o)!='object'||join(',',sort(keys(o)))!=join(',',sort(wanted)))die('journal_schema');}
function num(v){return type(v)=='int'||type(v)=='double';}
function bounded(v,lo,hi){return num(v)&&v>=lo&&v<=hi;}
function restore(x){
 exact(x,['version','boot','last_wall','last_mono','days']);
 if(x.version!=1||!match(x.boot||'',/^[0-9a-f-]{36}$/)||!bounded(x.last_wall,1600000000,4102444800)||!bounded(x.last_mono,0,1e10)||type(x.days)!='array'||length(x.days)>30)die('journal_schema');
 let s=blank(x.boot);s.last_wall=x.last_wall;s.last_mono=x.last_mono;let seen={};
 for(let d in x.days){
  exact(d,['date','start','end','observed','incomplete','closed','counts','events','overflow']);
  if(!match(d.date||'',/^[0-9]{4}-[0-9]{2}-[0-9]{2}$/)||seen[d.date]||!bounded(d.start,1600000000,4102444800)||!bounded(d.end,d.start+82800,d.start+90000)||calendar(d.start).date!=d.date||calendar(d.start).end!=d.end||!bounded(d.observed,0,d.end-d.start+10)||type(d.incomplete)!='bool'||type(d.closed)!='bool'||type(d.counts)!='object'||type(d.events)!='array'||length(d.events)>64||!bounded(d.overflow,0,1e10))die('journal_schema');
  seen[d.date]=true;for(let code,n in d.counts)if(index(codes,code)<0||!bounded(n,0,1e10))die('journal_schema');
  for(let e in d.events){
   exact(e,['code','start','last','end','status','seconds','peak','evidence']);
   if(type(e.evidence)!='object')die('journal_schema');for(let k,v in e.evidence)if(index(['fd_limit','tcp','data','udp'],k)<0||!bounded(v,0,1e12))die('journal_schema');
   if(index(codes,e.code)<0||index(['active','recovered','continued','unconfirmed'],e.status)<0||!bounded(e.start,d.start,d.end)||!bounded(e.last,e.start,4102444800)||(e.end!=null&&!bounded(e.end,e.start,4102444800))||!bounded(e.seconds,0,1e10)||(e.peak!=null&&!bounded(e.peak,0,1e12)))die('journal_schema');
   if(e.status=='active')s.active[e.code]=e;
  }push(s.days,d);
 }
 return s;
}
function view(s,storage_ok){
 let days=[];for(let d in s.days){let count=0;for(let k,v in d.counts)count+=v;
  push(days,{date:d.date,start:d.start,end:d.end,observed:int(d.observed),incomplete:d.incomplete,closed:d.closed,counts:d.counts,events:d.events,overflow:d.overflow,result:!d.closed?'collecting':count?'issues':d.incomplete?'incomplete':'normal'});
 }
 return {timezone:'UTC',retention_days:30,detail_limit_per_day:64,storage_ok,days};
}
export {calendar,blank,advance,saved,restore,view,conditions,codes};
