// UDP release gates and versioned receipts. No networking or service actions.
import * as fingerprints from './node-fingerprint.uc';
function has(a,v){return index(a||[],v)>=0;}
function public_ip(v){
 if(type(v)!='string'||!match(v,/^(0|[1-9][0-9]{0,2})(\.(0|[1-9][0-9]{0,2})){3}$/))return false;
 let a=map(split(v,'.'),x=>int(x));if(length(filter(a,n=>n>255)))return false;
 return !(a[0]==0||a[0]==10||a[0]==127||a[0]>=224||a[0]==100&&a[1]>=64&&a[1]<=127||a[0]==169&&a[1]==254||a[0]==172&&a[1]>=16&&a[1]<=31||a[0]==192&&a[1]==168||a[0]==198&&a[1]>=18&&a[1]<=19);
}
function bind(api){
 let memo={};
 function need(ok,param,message){if(!ok)api.fail('verification_pending',param,message);}
 function ready(front,rear){
  if(!front||!rear)return false;let f=api.feature(),a=api.combo(front),b=api.combo(rear);
  if(rear.protocol!='socks5'||rear.provider_udp!=true||!a||!b||!api.tcp_ready(front,rear)||!has(['trial','loopback','verified'],f?.status)||f.fixed_core!='26.10.21')return false;
  if(f.status=='trial')return true;
  let fk=match(front.server,/^[0-9.]+$/)?'ipv4':'domain',rk=match(rear.server,/^[0-9.]+$/)?'ipv4':'domain';
  return length(filter(f.validated_pairs||[],p=>p.front_combo==a.id&&p.rear_combo==b.id&&p.front_flow==(front.flow||'')&&has(['loopback','verified'],p.status)&&has(p.front_address_kinds,fk)&&has(p.rear_address_kinds,rk)&&p.control_two_hop==true&&p.data_two_hop==true&&p.relay_variants==true&&p.gate_no_bypass==true&&p.original_dns==true&&p.udp443_guard==true&&p.l3w==true&&p.l3o==true))==1;
 }
 function shape(n){
  if(type(n.udp)!='bool')api.fail('param_invalid','udp','UDP 开关必须为布尔值');
  if(n.udp_expected_ip!=null&&!public_ip(n.udp_expected_ip))api.fail('param_invalid','udp_expected_ip','请填写明确的公网 IPv4 出口约束');
  if(n.udp&&api.feature()?.status!='trial')need(public_ip(n.udp_expected_ip),'udp_expected_ip','启用前须填写预期后置出口');
  if(n.udp_verification!=null){let p=n.udp_verification;
   if(type(p)!='object'||length(keys(p))!=5||p.schema!=1||!match(p.binding||'',/^[a-f0-9]{64}$/)||!match(p.test_id||'',/^[a-f0-9-]{36}$/)||type(p.tested_at)!='int'||p.tested_at<=0||p.tcp_udp_same_exit!=true)api.fail('param_invalid','udp_verification','UDP 验证记录格式无效');
  }
 }
 function identity(n,store){
  let front=filter(store.nodes,x=>x.id==n.front)[0],rear=filter(store.nodes,x=>x.id==n.rear)[0];
  need(front&&rear&&public_ip(n.udp_expected_ip),'udp','UDP 依赖或出口约束无效');
  let a=api.connection(front),b=api.connection(rear);need(a!=null&&b!=null,'udp','不能完整绑定连接字段');
  let raw=api.canonical({schema:1,id:n.id,front_id:n.front,rear_id:n.rear,front:a,rear:b,provider_udp:rear.provider_udp==true,expected_ip:n.udp_expected_ip,capabilities:fingerprints.file(api.caps_file),core:'26.10.21'});
  if(memo[raw]==null)memo[raw]=fingerprints.digest(raw);return memo[raw];
 }
 function stamp_valid(n,store){
  if(!n.udp)return true;try{shape(n);return n.udp_verification!=null&&n.udp_verification.binding==identity(n,store);}catch(e){return false;}
 }
 function check(n,store){
  if(!n.udp)return;let front=filter(store.nodes,x=>x.id==n.front)[0],rear=filter(store.nodes,x=>x.id==n.rear)[0];
  need(ready(front,rear),'udp','该前置、SOCKS5 后置或链式 UDP 配对尚未验证');
  if(api.feature()?.status!='trial')need(stamp_valid(n,store),'udp','UDP 测试已失效；请关闭 UDP 或按当前连接重新测试');
 }
 function invalidate(before,after){
  let affected=[];
  for(let n in after.nodes){if(n.protocol!='chain'||!n.udp)continue;let old=filter(before.nodes,x=>x.id==n.id)[0];
   if(!old||old.protocol!='chain'||old.front!=n.front||old.rear!=n.rear||old.udp_expected_ip!=n.udp_expected_ip)continue;
   let changes=[];for(let id in [n.front,n.rear]){let a=filter(before.nodes,x=>x.id==id)[0],b=filter(after.nodes,x=>x.id==id)[0];if(!a||!b||api.canonical(api.connection(a))!=api.canonical(api.connection(b))||a.provider_udp!=b.provider_udp)push(changes,id);}
   if(length(changes)){n.udp=false;delete n.udp_verification;delete n.udp_expected_ip;push(affected,{id:n.id,name:api.display_name(n.name),dependency_ids:changes,action:'UDP 测试失效，候选关闭此链 UDP；确认应用后匹配的 UDP 将阻断'});}
  }return affected;
 }
 return {ready,shape,identity,stamp_valid,check,invalidate};
}
export {bind,public_ip};
