// Receipts remain private in /tmp, bounded and bound to the admin session.
import * as fs from 'fs';
function bind(api){
 let path=api.root+'/chain-udp-proofs.json',TTL=1200,MAX=64,MAX_BYTES=65536;
 function fail(code,message){api.reject(code,'udp_test_id',message);}
 function load(){
  api.ensure_root();if(fs.lstat(path)==null)return {schema:1,owner:'lanekeep-chain-udp-proofs-v1',entries:{}};
  let s=fs.lstat(path);if(s.type!='file'||s.uid!=0||(s.mode&0077)!=0||s.size>MAX_BYTES)fail('internal','UDP 测试记录存储异常');
  let d=json(fs.readfile(path));if(d?.schema!=1||d.owner!='lanekeep-chain-udp-proofs-v1'||type(d.entries)!='object'||length(keys(d.entries))>MAX)fail('internal','UDP 测试记录格式异常');return d;
 }
 function issue(owner,bindings,binding){
  if(!api.valid_id(owner)||!match(binding||'',/^[a-f0-9]{64}$/))fail('preview_expired','登录上下文或连接绑定失效');
  let d=load(),now=time();for(let id in keys(d.entries)){let at=d.entries[id].created_at;if(type(at)!='int'||now<at||now>=at+TTL)delete d.entries[id];}
  if(length(keys(d.entries))>=MAX)fail('limit_exceeded','UDP 测试记录已满，请等待过期');
  let id=api.uuid(),proof={schema:1,binding,tested_at:now,test_id:id,tcp_udp_same_exit:true};
  d.entries[id]={owner,bindings,binding,created_at:now,proof};if(length(sprintf('%J\n',d))>MAX_BYTES)fail('limit_exceeded','UDP 测试记录超过容量');api.write(path,d);return proof;
 }
 function check(id,owner,bindings,binding){
  if(!api.valid_id(id)||!api.valid_id(owner))fail('preview_expired','请先在当前登录会话测试此链 UDP');let v=load().entries[id],now=time();
  if(!v||v.owner!=owner||type(v.created_at)!='int'||now<v.created_at||now>=v.created_at+TTL)fail('preview_expired','UDP 测试已过期或不属于当前会话');
  if(v.binding!=binding||api.canonical(v.bindings)!=api.canonical(bindings))fail('revision_changed','连接、配置或能力表已变化，请重新测试 UDP');return v.proof;
 }
 return {issue,check};
}
export {bind};
