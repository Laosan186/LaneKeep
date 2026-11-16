// Current day in RAM; completed days on demand. All persistent fields are typed.
import * as fs from 'fs';
import * as health from './health-model.uc';
let ROOT='/etc/lanekeep-health',state=null,summaries=[],ready=false,healthy=false,last_saved=0,last_attempt=-60,dirty=false;
function root_ok(root){return root=='/etc/lanekeep-health'||match(root,/^\/tmp\/lanekeep-proxy-stage\/health-journal-[0-9TZ]+\/journal(-[a-z0-9]+)?$/);}
function path(root,name){
 if(!root_ok(root)||!match(name,/^(history|[0-9]{4}-[0-9]{2}-[0-9]{2})\.(json|next)$/))die('journal_path');
 let d=fs.lstat(root);if(!d||d.type!='directory'||d.uid!=0||(d.mode&0077)!=0)die('journal_directory');
 let p=root+'/'+name,s=fs.lstat(p);if(s!=null&&(s.type!='file'||s.uid!=0||(s.mode&0077)!=0||s.size>1048576))die('journal_permissions');return p;
}
function write(name,value){
 let p=path(ROOT,name+'.json'),tmp=path(ROOT,name+'.next'),text=sprintf('%J\n',value);if(length(text)>1048576)die('journal_size');
 let f=fs.open(tmp,'w',0600);if(!f)die('journal_write');let n=f.write(text);f.close();if(n!=length(text))die('journal_write');if(!fs.rename(tmp,p))die('journal_rename');
}
function read_day(date,root){
 if(!match(date||'',/^[0-9]{4}-[0-9]{2}-[0-9]{2}$/))die('journal_date');
 let s=health.restore(json(fs.readfile(path(root||ROOT,date+'.json'))));
 if(length(s.days)!=1||s.days[0].date!=date||!s.days[0].closed)die('journal_day');return s.days[0];
}
function initialize(boot,root){
 ROOT=root||ROOT;if(!root_ok(ROOT))die('journal_root');
 let d=fs.lstat(ROOT);if(!d&&!fs.mkdir(ROOT,0700))die('journal_directory');
 let p=path(ROOT,'history.json'),st=fs.lstat(p);summaries=[];
 if(st){
  let x=json(fs.readfile(p));if(type(x)!='object'||join(',',sort(keys(x)))!='state,summaries,version'||x.version!=1||type(x.summaries)!='array'||length(x.summaries)>30)die('journal_index');
  state=health.restore(x.state);if(length(state.days)>1)die('journal_index');
  let seen={};for(let d in x.summaries){let test={...x.state,days:[d]};health.restore(test);if(!d.closed||length(d.events)||seen[d.date])die('journal_summary');seen[d.date]=true;push(summaries,d);}
 }else state=health.blank(boot);
 ready=true;healthy=true;
}
function persist(){
 let latest=health.calendar(state.last_wall).date,cutoff=health.calendar(health.calendar(state.last_wall).start+12*3600-29*86400).date;
 for(let d in state.days){
  if(!d.closed)continue;
  let existing=fs.lstat(path(ROOT,d.date+'.json'));
  if(existing){let archived=read_day(d.date);if(archived.observed>d.observed)d=archived;}
  write(d.date,{...health.saved(state),days:[d]});
  summaries=filter(summaries,x=>x.date!=d.date);push(summaries,{...d,events:[]});
 }
 let expired=filter(summaries,d=>d.date<cutoff),kept=filter(summaries,d=>d.date>=cutoff);
 if(length(kept)>29)die('journal_clock_or_capacity');
 let current=filter(state.days,d=>!d.closed);if(length(current)>1)die('journal_current');
 
 // Only archives registered in our own validated index may expire. Never scan
 // or clear other project histories, configuration versions or backup folders.
 for(let d in expired){let p=path(ROOT,d.date+'.json');if(fs.lstat(p)&&!fs.unlink(p))die('journal_expiry');}
 write('history',{version:1,state:{...health.saved(state),days:current},summaries:kept});
 state.days=current;summaries=kept;healthy=true;
}
function observe(p){
 if(!ready)return {timezone:'UTC',retention_days:30,storage_ok:false,days:[]};
 try{let r=health.advance(state,p);dirty=dirty||r.changed;let overflow=state.days[length(state.days)-1]?.overflow>0;
  if((healthy||p.mono-last_attempt>=60)&&((dirty&&(!overflow||p.mono-last_saved>=60))||last_saved==0||p.mono-last_saved>=3600)){last_attempt=p.mono;persist();last_saved=p.mono;dirty=false;}
 }catch(e){healthy=false;}
 let combined={days:sort([...summaries,...state.days],(a,b)=>a.start-b.start)};
 return health.view(combined,healthy);
}
export {initialize,observe,read_day};
