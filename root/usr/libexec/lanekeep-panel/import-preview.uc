// Immutable private previews; caller holds submit lock. Never trusts row indices.
import * as fs from 'fs';
import * as nodes from './nodes.uc';
import * as sizes from './rpc-size.uc';
let OWNER='lanekeep-node-preview-v1\n',TTL=1200,MAX_BYTES=2097152,MAX_COUNT=4,MAX_TOTAL=8388608;
function bind(api){
 let ROOT=api.root+'/import-previews';
 function fail(code,param,message){api.reject(code,param,message);}
 function regular(p){return fs.lstat(p)?.type=='file'&&fs.lstat(p).uid==0&&(fs.lstat(p).mode&0077)==0;}
 function ensure(){api.ensure_root();if(fs.lstat(ROOT)==null&&!fs.mkdir(ROOT,448))fail('internal','preview','无法建立私有预览目录');if(fs.lstat(ROOT)?.type!='directory'||fs.lstat(ROOT).uid!=0||!fs.chmod(ROOT,448))fail('internal','preview','私有预览目录异常');}
 function owned(dir){return fs.lstat(dir)?.type=='directory'&&fs.lstat(dir).uid==0&&regular(dir+'/.owner')&&fs.readfile(dir+'/.owner')==OWNER;}
 function discard(dir){
  if(!owned(dir))return;let allowed=['.owner','data.json','data.json.next','connection.json','connection.json.next','input.txt'];let files=fs.lsdir(dir)||[];
  for(let n in files)if(index(allowed,n)<0||!regular(dir+'/'+n))return;
  for(let n in files)if(n!='.owner')fs.unlink(dir+'/'+n);fs.unlink(dir+'/.owner');fs.rmdir(dir);
 }
 function capacity(){let count=0,bytes=0;
  for(let name in fs.lsdir(ROOT)||[]){if(!api.valid_id(name)||!owned(ROOT+'/'+name))fail('internal','preview','预览目录所有权异常');let dir=ROOT+'/'+name,data=null;
   if(regular(dir+'/data.json')&&fs.stat(dir+'/data.json').size<=MAX_BYTES)try{data=json(fs.readfile(dir+'/data.json'));}catch(e){}
   let at=data?.schema==1&&type(data.created_at)=='int'?data.created_at:fs.stat(dir).mtime;if(time()>=at+TTL){discard(dir);if(fs.lstat(dir)==null)continue;}
   count++;for(let n in fs.lsdir(dir)||[]){if(!regular(dir+'/'+n))fail('internal','preview','预览缓存结构异常');bytes+=fs.stat(dir+'/'+n).size;}
  }return {count,bytes};
 }
 function fp(dir,n){let c=nodes.connection(n);if(c==null)return null;let p=dir+'/connection.json',raw=nodes.canonical(c);if(capacity().bytes+length(raw)>MAX_TOTAL)fail('limit_exceeded','preview','私有预览临时数据超过容量');let f=fs.open(p,'wx',384);if(!f)fail('internal','preview','无法比较连接字段');let nbytes=f.write(raw);f.close();if(nbytes!=length(raw))fail('internal','preview','无法比较连接字段');let result=api.fingerprint(p);fs.unlink(p);return result;}
 function prefix(s,bytes){let end=0;while(end<length(s)){let b=ord(substr(s,end,1)),n=b<128?1:b<224?2:b<240?3:4;if(end+n>bytes)break;end+=n;}return substr(s,0,end);}
 function name(value,names){if(!names[value])return value;for(let i=2;i<1000;i++){let suffix=' ('+i+')',n=prefix(value,80-length(suffix))+suffix;if(!names[n])return n;}fail('limit_exceeded','name','不能分配唯一名称');}
 function validated(id,version,owner,bindings){
  if(!api.valid_id(id)||!api.valid_id(version)||!api.valid_id(owner))fail('preview_expired','preview_id','预览编号或登录上下文失效');ensure();let dir=ROOT+'/'+id;
  if(!owned(dir)||!regular(dir+'/data.json')||fs.stat(dir+'/data.json').size>MAX_BYTES)fail('preview_expired','preview_id','预览不存在，请重新预览');let d=json(fs.readfile(dir+'/data.json'));
  if(d.schema!=1||d.preview_id!=id||d.owner!=owner||type(d.created_at)!='int'||time()<d.created_at||time()>=d.created_at+TTL||type(d.items)!='array'||length(d.items)>500)fail('preview_expired','preview_id','预览已过期或不属于当前会话');
  if(d.cache_version!=version||nodes.canonical(d.bindings)!=nodes.canonical(bindings))fail('revision_changed','preview_id','预览依赖的数据已变化，请重新预览');if(d.source_binding)api.check_source(d.source_binding);return d;
 }
 function display(d,offset,filter_text){
  filter_text=filter_text||'';if(type(filter_text)!='string'||length(filter_text)>80)fail('param_invalid','filter','筛选文字无效');
  let rows=filter(d.items,x=>!filter_text||index(lc(x.node?.name||''),lc(filter_text))>=0),base={ok:true,preview_id:d.preview_id,cache_version:d.cache_version,expires_in:TTL-(time()-d.created_at),dedup_incomplete:d.dedup_incomplete,matching_item_ids:map(filter(rows,x=>x.selectable),x=>x.item_id),message:'预览仅保存在私有临时目录；请选择条目后校验，再确认应用'};
  return sizes.page(map(rows,x=>x.display),offset||0,base,'items');
 }
 function create(content,owner,bindings,store,quick,options){
  options=options||{};if(!api.valid_id(owner))fail('preview_expired','preview_id','登录上下文不可用');ensure();let usage=capacity();if(usage.count>=MAX_COUNT)fail('limit_exceeded','preview','最多保留四份预览，请等待过期后重试');
  let parsed=options.rows||nodes.parse_preview(content,quick,options.kind),rename=options.prefix||'',updates=options.updates||{};if(type(rename)!='string'||length(rename)>32||match(rename,/[[:cntrl:]]/)||type(updates)!='object')fail('param_invalid','prefix','来源前缀或更新目标无效');
  if(type(parsed)!='array'||!length(parsed)||length(parsed)>500)fail('limit_exceeded','preview','预览条目超限');let id=api.uuid(),dir=ROOT+'/'+id;if(!fs.mkdir(dir,448))fail('internal','preview','无法建立预览');let owner_file=fs.open(dir+'/.owner','wx',384);if(!owner_file)fail('internal','preview','无法标记预览');owner_file.write(OWNER);owner_file.close();
  try{
   let known={},names={},uncompared=0,entries=[],used_targets={},used_items={};for(let n in store.nodes){names[n.name]=true;let f=fp(dir,n);if(f)known[f]=true;else uncompared++;}
   for(let key in keys(updates))if(!length(filter(parsed,r=>r.item_id==key)))fail('param_invalid','updates','更新目标不属于本次选择');
   for(let row in parsed){
    let item={item_id:row.item_id||api.uuid(),line:row.line,status:row.status},v={item_id:item.item_id,line:row.line,status:row.status,selectable:false,selected_default:false};if(!api.valid_id(item.item_id)||used_items[item.item_id])fail('param_invalid','item_id','预览条目标识重复');used_items[item.item_id]=true;
    if(row.error){item.error=row.error;v.code=row.error.code;v.param=row.error.param;v.message=row.error.message;}
    else{
     item.node=json(sprintf('%J',row.node));item.fp=fp(dir,item.node);item.duplicate=item.fp!=null&&known[item.fp]==true;let update=updates[item.item_id];
     if(update!=null){let a=filter(store.nodes,n=>n.id==update);if(!options.source_binding||!nodes.valid_node_id(update)||used_targets[update]||length(a)!=1||a[0].source?.id!=options.source_binding.id)fail('param_invalid','updates','更新目标无效或被重复选择');used_targets[update]=true;item.update_id=update;item.node.name=a[0].name;v.update_id=update;v.changed_fields=nodes.changed_fields(a[0],item.node);if(index(v.changed_fields,'无法完整比较')>=0)fail('param_invalid','updates','无法完整比较目标连接，请单独编辑');}
     else{let desired=prefix(rename+item.node.name,80),chosen=name(desired,names);item.renamed=chosen!=desired;item.node.name=chosen;names[chosen]=true;}
     if(item.fp)known[item.fp]=true;
     item.selectable=row.status=='ok'&&(!options.source_binding||!item.duplicate||item.update_id!=null)&&!row.duplicate;
     v.name=nodes.display_name(item.node.name);v.protocol=item.node.protocol;v.combo=nodes.combo_id(item.node);v.role=nodes.role(item.node);v.server_masked=nodes.mask(item.node.server);v.required_store_version=nodes.minimum_version(item.node);v.selectable=item.selectable;v.selected_default=item.selectable&&!item.duplicate&&uncompared==0;
     v.code=row.status=='pending_verification'?'verification_pending':item.update_id?'explicit_update':item.duplicate?'duplicate_node':item.renamed?'name_conflict':'ok';v.param=row.pending_param||'';v.message=item.update_id?'更新指定节点；请核对连接字段变化':row.status=='pending_verification'?'固定版本验证尚未完成':item.duplicate?'连接字段重复，默认不选择':item.renamed?'名称冲突，已建议新名称':'参数已解析';
    }item.display=v;push(entries,item);
   }
   let data={schema:1,preview_id:id,cache_version:options.source_binding?.cache_version||api.uuid(),owner,created_at:time(),bindings,source_binding:options.source_binding||null,dedup_incomplete:uncompared>0,items:entries},bytes=length(sprintf('%J\n',data));
   if(bytes>MAX_BYTES||usage.bytes+bytes+length(OWNER)>MAX_TOTAL)fail('limit_exceeded','preview','私有预览超过容量，请减少所选条目');api.write(dir+'/data.json',data);
   if(nodes.canonical(api.bindings())!=nodes.canonical(bindings))fail('revision_changed','preview','预览期间配置变化');if(data.source_binding)api.check_source(data.source_binding);return display(data,0,'');
  }catch(e){discard(dir);die('preview_not_created');}
 }
 function page(id,version,owner,bindings,offset,filter_text){return display(validated(id,version,owner,bindings),offset,filter_text);}
 function select(id,version,selected,owner,bindings){
  let d=validated(id,version,owner,bindings);if(type(selected)!='array'||!length(selected)||length(selected)>64)fail('limit_exceeded','selected_item_ids','请选择 1–64 条有效条目');let seen={},entries=[];
  for(let id in selected){if(!api.valid_id(id)||seen[id])fail('param_invalid','selected_item_ids','选择编号无效或重复');seen[id]=true;let a=filter(d.items,x=>x.item_id==id);if(length(a)!=1||a[0].status!='ok'||!a[0].selectable||type(a[0].node)!='object')fail('param_invalid','selected_item_ids','所选条目未通过校验');push(entries,{node:json(sprintf('%J',a[0].node)),update_id:a[0].update_id||null});}
  return {entries,source_binding:d.source_binding};
 }
 return {create,page,select};
}
export {bind};
