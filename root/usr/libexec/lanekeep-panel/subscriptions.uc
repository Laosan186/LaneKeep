// Caller holds the existing submit lock; writes never touch nodes/config/rules.
import * as fs from 'fs';
import * as policy from './subscription-policy.uc';
import * as nodes from './nodes.uc';
import * as sizes from './rpc-size.uc';
import * as caps from './caps.uc';
let FILE='/etc/lanekeep-proxy/subscriptions.json',ROOT='/tmp/lanekeep-sub-cache',OWNER='lanekeep-sub-cache-v1\n',WORK_OWNER='lanekeep-sub-work-v1\n';
function bind(api){
// ucode binds closures in source order; declare shared bindings before use.
 let budget;
 function fail(code,param,message){api.reject(code,param,message);}
 function regular(p){let s=fs.lstat(p);return s?.type=='file'&&s.uid==0&&(s.mode&0077)==0;}
 function read(p,max){if(!regular(p)||fs.stat(p).size>max)fail('internal','storage','私有数据不可读取');return json(fs.readfile(p));}
 function write(p,v,max){let raw=sprintf('%J\n',v);if(length(raw)>max)fail('limit_exceeded','storage','私有数据超过容量');if(fs.lstat(p)!=null&&!regular(p))fail('internal','storage','私有数据路径异常');if(substr(p,0,length(ROOT)+1)==ROOT+'/'){let parts=split(p,'/');pop(parts);budget(join('/',parts),length(raw));}let tmp=p+'.next-'+api.uuid(),f=fs.open(tmp,'wx',384);if(!f)fail('internal','storage','不能写入私有数据');let n=f.write(raw);f.close();if(n!=length(raw)||!fs.chmod(tmp,384)||!fs.rename(tmp,p)){if(regular(tmp))fs.unlink(tmp);fail('internal','storage','私有数据提交失败，原版本保留');}}
 function store(){
  if(fs.lstat(FILE)==null)return {schema:1,revision:'empty',sources:[]};let s=read(FILE,65536);
  if(s?.schema!=1||!policy.uuid(s.revision)||type(s.sources)!='array'||length(s.sources)>8)fail('internal','sources','来源定义格式异常');let seen={};
  for(let x in s.sources){if(!policy.source_id(x.id)||seen[x.id]||!policy.uuid(x.revision)||type(x.created_at)!='int')fail('internal','sources','来源定义格式异常');seen[x.id]=true;policy.source({id:x.id,name:x.name,url:x.url,ua:x.ua,channel:x.channel},x,x.revision,x.id,x.created_at,x.direct_confirmed);}
  return s;
 }
 function one(id,s){if(!policy.source_id(id))fail('param_invalid','id','来源编号无效');let a=filter((s||store()).sources,x=>x.id==id);if(length(a)!=1)fail('revision_changed','source','来源已改变或删除');return a[0];}
 function owned_root(){return fs.lstat(ROOT)?.type=='directory'&&fs.lstat(ROOT).uid==0&&(fs.lstat(ROOT).mode&0077)==0&&regular(ROOT+'/.owner')&&fs.readfile(ROOT+'/.owner')==OWNER;}
 function ensure(){
  if(!match(fs.readfile('/proc/mounts')||'',/(^|\n)tmpfs \/tmp tmpfs /))fail('internal','cache','缓存必须位于内存文件系统');
  if(fs.lstat(ROOT)==null){if(!fs.mkdir(ROOT,448))fail('internal','cache','不能建立私有缓存');let f=fs.open(ROOT+'/.owner','wx',384);if(!f)fail('internal','cache','不能标记私有缓存');f.write(OWNER);f.close();}
  if(!owned_root()||!fs.chmod(ROOT,448))fail('internal','cache','私有缓存所有权异常');
 }
 function cache(id){
  if(!policy.source_id(id))fail('param_invalid','id','来源编号无效');if(fs.lstat(ROOT)==null)return null;if(!owned_root())fail('internal','cache','私有缓存所有权异常');let p=ROOT+'/'+id+'.json';if(fs.lstat(p)==null)return null;let c=read(p,policy.LIMITS.cache);
  if(c?.schema!=1||c.source_id!=id||!policy.uuid(c.cache_version)||!policy.uuid(c.source_revision)||type(c.items)!='array'||length(c.items)>500||type(c.fetched_at)!='int'||c.fetched_at<0||type(c.caps_revision)!='string'||!match(c.caps_revision,/^[a-f0-9]{64}$/))fail('internal','cache','缓存格式异常');let seen={};
  for(let row in c.items){if(type(row)!='object'||!policy.uuid(row.item_id)||seen[row.item_id]||type(row.line)!='int'||row.line<1||index(['ok','error','pending_verification'],row.status)<0||row.fp!=null&&(type(row.fp)!='string'||!match(row.fp,/^[a-f0-9]{64}$/)||row.fp_schema!=1)||row.status!='error'&&(type(row.node)!='object'||type(row.node.name)!='string'||length(row.node.name)>80||match(row.node.name,/[[:cntrl:]]/)))fail('internal','cache','缓存条目异常');seen[row.item_id]=true;}
  if(c.usage!=null){if(type(c.usage)!='object')fail('internal','cache','用量格式异常');for(let key,value in c.usage)if(index(['upload','download','total','expire'],key)<0||type(value)!='int'||value<0||value>9007199254740991)fail('internal','cache','用量格式异常');}
  return c;
 }
 function clean_work(dir){
  let allowed=['.owner','input.json','test-config.json','exchange.json','request.bin','response-body','response.json','body','result.json','connection.json','cache-next.json'];
  if(fs.lstat(dir)?.type!='directory'||fs.lstat(dir).uid!=0||!regular(dir+'/.owner')||fs.readfile(dir+'/.owner')!=WORK_OWNER)return;
  let names=fs.lsdir(dir)||[];for(let n in names){let m=match(n,/^(.+)\.next-([a-f0-9-]{36})$/),known=index(allowed,n)>=0||m&&policy.uuid(m[2])&&index(allowed,m[1])>=0;if(!known||!regular(dir+'/'+n))return;}
  for(let n in names)if(n!='.owner')fs.unlink(dir+'/'+n);fs.unlink(dir+'/.owner');fs.rmdir(dir);
 }
 function workspace(){
  ensure();for(let n in fs.lsdir(ROOT)||[])if(match(n,/^\.work-[a-f0-9-]{36}$/)){let p=ROOT+'/'+n,entry=fs.lstat(p);if(entry?.type!='directory'||entry.uid!=0||(entry.mode&0077)!=0)fail('internal','cache','工作区所有权异常');if(time()-entry.mtime>120)clean_work(p);if(fs.lstat(p)!=null)fail('request','refresh','已有刷新工作区，稍后手动重试');}
  let dir=ROOT+'/.work-'+api.uuid();if(!fs.mkdir(dir,448))fail('internal','refresh','不能建立私有工作区');let f=fs.open(dir+'/.owner','wx',384);if(!f)fail('internal','refresh','不能标记工作区');f.write(WORK_OWNER);f.close();return dir;
 }
 budget = function(dir,extra){let bytes=extra||0;for(let n in fs.lsdir(dir)||[]){if(!regular(dir+'/'+n))fail('internal','cache','工作区结构异常');bytes+=fs.stat(dir+'/'+n).size;}if(bytes>policy.LIMITS.work)fail('limit_exceeded','cache','临时工作区超过 6 MiB');};
 function fingerprint(n,dir){let c=nodes.connection(n);if(c==null)return null;let p=dir+'/connection.json',raw=nodes.canonical(c);budget(dir,length(raw));let f=fs.open(p,'wx',384);if(!f)fail('internal','fingerprint','无法比较连接字段');let count=f.write(raw);f.close();if(count!=length(raw))fail('internal','fingerprint','无法比较连接字段');let fp=api.fingerprint(p);fs.unlink(p);return fp;}
 function binding(id){let s=one(id),c=cache(id);if(!c||c.source_revision!=s.revision)fail('revision_changed','cache','缓存不可用或来源已修改，请手动刷新');return {id,source_revision:s.revision,cache_version:c.cache_version};}
 function check(expected){if(index(['trial','loopback','verified'],caps.get().features?.subscriptions?.status)<0)fail('verification_pending','subscription','订阅功能尚未完成必要验证');if(nodes.canonical(binding(expected?.id))!=nodes.canonical(expected))fail('revision_changed','cache','来源或缓存已变化，请重新预览');}
 function list(){let s=store(),out=[];for(let x in s.sources){let c=cache(x.id);push(out,{id:x.id,name:x.name,url_masked:'https://••••/…',ua:x.ua,channel:x.channel,revision:x.revision,created_at:x.created_at,cache_version:c?.cache_version||null,fetched_at:c?.fetched_at||null,count:c?length(c.items):0,usage:c?.usage||null,cache_ready:c?.source_revision==x.revision,cache_message:!c?'缓存不可用，需手动刷新':c.source_revision!=x.revision?'来源已修改，需手动刷新':'已缓存'});}return {ok:true,revision:s.revision,sources:out,limits:policy.LIMITS};}
 function save(d){
  let s=store();if(d.revision!=s.revision)fail('revision_changed','revision','来源定义已变化，请刷新');
  if(d.operation=='delete'){
   let x=one(d.id,s);s.sources=filter(s.sources,a=>a.id!=x.id);
  }else if(d.operation=='save'){
   let old=d.source?.id?one(d.source.id,s):null;if(!old&&length(s.sources)>=8)fail('limit_exceeded','sources','最多保存 8 个来源');
   let value;try{value=policy.source(d.source,old,api.uuid(),old?.id||'sub_'+substr(replace(api.uuid(),/-/g,''),0,24),time(),d.confirm_direct);}catch(e){fail('param_invalid','source','来源格式无效或直连未单独确认');}
   if(old)s.sources=map(s.sources,x=>x.id==old.id?value:x);else push(s.sources,value);
  }else fail('param_invalid','operation','不支持的来源操作');
  s.revision=api.uuid();write(FILE,s,65536);
  if(d.operation=='delete'&&owned_root()){let p=ROOT+'/'+d.id+'.json';if(regular(p))fs.unlink(p);}
  return {ok:true,revision:s.revision,message:'来源定义已保存；已导入节点保持'};
 }
 function fetch_to(source,dir){
  let feature=caps.get().features?.subscriptions;
  if(index(['trial','loopback','verified'],feature?.status)<0||index((feature?.status=='trial'?feature.trial_channels:feature?.validated_channels)||[],source.channel)<0)fail('verification_pending','subscription','此拉取通道尚未完成必要验证');
  let st=api.current_nodes(),n=filter(st.nodes,x=>x.id==st.default_node)[0];if(source.channel=='proxy')nodes.assert_reference(n);
  write(dir+'/input.json',{url:source.url,ua:source.ua,channel:source.channel,direct_confirmed:source.direct_confirmed,node:source.channel=='proxy'?nodes.render(n):null},1048576);budget(dir,0);
  let completed=api.run('/usr/libexec/lanekeep-panel/subscription-fetch '+dir),r=regular(dir+'/result.json')?read(dir+'/result.json',8192):null;
  if(completed==null||r?.ok!=true||!regular(dir+'/body')||fs.stat(dir+'/body').size>policy.LIMITS.body){
   let messages={input:'订阅请求准备未完成；来源和旧缓存保持',dns:'订阅服务器解析阶段未完成；未切换解析路径，旧缓存保持',https:'订阅 HTTPS 获取阶段未完成；未切换通道，旧缓存保持'};
   fail('fetch_failed','subscription',messages[r?.stage]||'订阅拉取未完成；失败阶段不可用，旧缓存保持');
  }return {content:fs.readfile(dir+'/body'),usage:r.usage};
 }
 function once(url){let dir=workspace();try{let r=fetch_to({url,ua:policy.DEFAULT_UA,channel:'proxy',direct_confirmed:false},dir);clean_work(dir);return r.content;}catch(e){clean_work(dir);die('subscription_failed');}}
 function refresh(d){
  let s=one(d.id);if(s.revision!=d.source_revision)fail('revision_changed','source','来源已改变，请刷新');let before=api.bindings(),old=cache(s.id),dir=workspace();
  try{
   let fetched=fetch_to(s,dir),parsed=nodes.parse_preview(fetched.content,null,'subscription'),old_counts={},old_ids={},counts={},items=[];
   for(let row in old?.items||[])if(row.fp){old_counts[row.fp]=(old_counts[row.fp]||0)+1;old_ids[row.fp]=row.item_id;}
   for(let row in parsed){let item={item_id:api.uuid(),line:row.line,status:row.status,error:row.error,pending_param:row.pending_param};if(row.node){item.node=row.node;item.fp=fingerprint(row.node,dir);item.fp_schema=1;if(item.fp)counts[item.fp]=(counts[item.fp]||0)+1;}push(items,item);}
   for(let row in items)if(row.fp){row.duplicate=counts[row.fp]>1;if(counts[row.fp]==1&&old_counts[row.fp]==1)row.item_id=old_ids[row.fp];}
   let value={schema:1,source_id:s.id,source_revision:s.revision,cache_version:api.uuid(),caps_revision:before.caps_revision,fetched_at:time(),usage:fetched.usage,items},raw=sprintf('%J\n',value);
   if(length(raw)>policy.LIMITS.cache)fail('limit_exceeded','cache','解析后缓存超过 4 MiB，旧版本保持');budget(dir,length(raw));
   let total=length(raw);for(let name in fs.lsdir(ROOT)||[]){if(name==s.id+'.json'||name=='.owner'||match(name,/^\.work-/))continue;if(!match(name,/^sub_[a-f0-9]{24}\.json$/)||!regular(ROOT+'/'+name))fail('internal','cache','缓存目录含未知内容');total+=fs.stat(ROOT+'/'+name).size;}
   if(total>policy.LIMITS.total)fail('limit_exceeded','cache','全部缓存超过 16 MiB，旧版本保持');
   if(one(s.id).revision!=s.revision||nodes.canonical(api.bindings())!=nodes.canonical(before))fail('revision_changed','source','刷新期间来源或配置改变，旧版本保持');
   let target=ROOT+'/'+s.id+'.json';if(fs.lstat(target)!=null&&!regular(target))fail('internal','cache','缓存目标所有权异常');let next=dir+'/cache-next.json',f=fs.open(next,'wx',384);if(!f)fail('internal','cache','缓存写入失败');let n=f.write(raw);f.close();if(n!=length(raw)||!fs.chmod(next,384)||!fs.rename(next,ROOT+'/'+s.id+'.json'))fail('internal','cache','缓存提交失败，旧版本保持');
   clean_work(dir);return {ok:true,cache_version:value.cache_version,count:length(items),fetched_at:value.fetched_at,message:'仅更新缓存；节点与规则未改变'};
  }catch(e){clean_work(dir);die('subscription_refresh_failed');}
 }
 function diff(d){
  let s=one(d.id),c=cache(s.id),current=binding(s.id),bindings=api.bindings();if(d.cache_version&&d.cache_version!=c.cache_version||d.source_revision&&d.source_revision!=s.revision||d.nodes_revision&&d.nodes_revision!=bindings.nodes_revision||d.caps_revision&&d.caps_revision!=bindings.caps_revision)fail('revision_changed','cache','来源、节点或缓存已变化，请重新查看');
  if(c.caps_revision!=bindings.caps_revision)fail('revision_changed','capabilities','能力表已变化，请重新刷新来源');
  let st=api.current_nodes(),dir=workspace(),known=[],rows=[],present={},filter_text=d.filter||'';if(type(filter_text)!='string'||length(filter_text)>80)fail('param_invalid','filter','筛选文字无效');
  try{
   for(let n in st.nodes)push(known,{node:n,fp:fingerprint(n,dir)});
   for(let row in c.items){
    let view={item_id:row.item_id,line:row.line,name:row.node?nodes.display_name(row.node.name):'',protocol:row.node?.protocol||'',selectable:row.status=='ok'&&!row.duplicate,status:row.status,message:row.status=='pending_verification'?'固定版本验证尚未完成':row.status=='error'?'条目未通过格式校验':'新增',param:'',targets:[]};
    if(row.fp){present[row.fp]=true;let same=filter(known,k=>k.fp==row.fp),similar=filter(known,k=>k.node.source?.id==s.id&&k.node.name==row.node.name&&k.fp!=row.fp);if(length(same)){view.status=length(filter(same,k=>k.node.source?.id==s.id))?'imported':'duplicate';view.message=view.status=='imported'?'已导入':'已有相同连接';view.selectable=false;}else if(length(similar)){view.status='possibly_changed';view.message='可能已变更；需显式选择更新目标';view.targets=map(similar,k=>({id:k.node.id,name:nodes.display_name(k.node.name),fields:nodes.changed_fields(k.node,row.node)}));}if(row.duplicate){view.status='duplicate';view.selectable=false;view.message='缓存内连接内容重复';}}
    else if(row.node){view.status='incomparable';view.selectable=false;view.message='连接字段无法完整比较';}
    if(!filter_text||index(lc(row.node?.name||''),lc(filter_text))>=0)push(rows,view);
   }
   for(let k in known)if(k.node.source?.id==s.id&&(!k.fp||!present[k.fp]))if(!filter_text||index(lc(k.node.name),lc(filter_text))>=0)push(rows,{node_id:k.node.id,name:nodes.display_name(k.node.name),status:k.fp?'missing':'incomparable',selectable:false,message:k.fp?'来源已不存在此连接；保留已导入节点':'原生字段无法完整比较；不自动更新'});
   clean_work(dir);let selection_ids=map(filter(rows,r=>r.selectable),r=>r.item_id),base={ok:true,...current,...bindings,matching_item_ids:selection_ids,source_name:nodes.display_name(s.name),fetched_at:c.fetched_at};return sizes.page(rows,d.offset||0,base,'items');
  }catch(e){clean_work(dir);die('subscription_diff_failed');}
 }
 function selected(d){
  if(index(['trial','loopback','verified'],caps.get().features?.subscriptions?.status)<0)fail('verification_pending','subscription','订阅功能尚未完成必要验证');let current=binding(d.source_id);if(d.cache_version!=current.cache_version||d.source_revision!=current.source_revision)fail('revision_changed','cache','来源或缓存已变化，请重新查看');let s=one(d.source_id),c=cache(s.id);if(c.caps_revision!=api.bindings().caps_revision)fail('revision_changed','capabilities','能力表变化，请刷新来源');
  if(type(d.selected_item_ids)!='array'||!length(d.selected_item_ids)||length(d.selected_item_ids)>64)fail('limit_exceeded','selected_item_ids','每批选择 1–64 条');let seen={},out=[];
  for(let id in d.selected_item_ids){if(!policy.uuid(id)||seen[id])fail('param_invalid','selected_item_ids','选择编号无效或重复');seen[id]=true;let a=filter(c.items,r=>r.item_id==id);if(length(a)!=1||a[0].status!='ok'||a[0].duplicate||!a[0].fp)fail('param_invalid','selected_item_ids','所选条目未通过校验');let row=json(sprintf('%J',a[0]));row.node.source={id:s.id,item_id:id,fp_schema:1,fp:row.fp};push(out,row);}
  return {rows:out,binding:current,source_name:s.name};
 }
 return {list,save,refresh,diff,once,binding,check,selected};
}
export {FILE,ROOT,bind};
