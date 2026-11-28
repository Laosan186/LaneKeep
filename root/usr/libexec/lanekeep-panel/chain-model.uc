// Two-hop composition. The on-demand IP route verifies a pinned local asset; no network or writes.
import * as hashes from './node-fingerprint.uc';
// This exact database's GOOGLE/NETFLIX sets are IPv4-only and disjoint from FakeIP.
// Evidence: docs/audit/geodata.json. Asset drift rejects application.
function safe_ondemand_ip(rule) {
 if(length(keys(rule))!=(rule.network==null?4:5) || rule.type!='field' ||
    join(',',rule.inboundTag || [])!='ondemand-transparent' ||
    join(',',rule.ip || [])!='ext:lanekeep-services.dat:netflix,ext:lanekeep-services.dat:google' ||
    !match(rule.outboundTag||'',/^chain-[a-z][a-z0-9_]{0,31}$/) ||
    (rule.network!=null && index(['tcp','udp','tcp,udp'],rule.network)<0))return false;
 let asset=getenv('XRAY_LOCATION_ASSET');
 if(asset!=null && asset!='' && asset!='/usr/share/v2ray/' && asset!='/usr/share/v2ray')return false;
 return hashes.file('/usr/share/v2ray/lanekeep-services.dat')=='d326db0897723cd38b9d70c9b269c486fc05c6de61be1233187364abf6a890e7';
}
function copy(v){return json(sprintf('%J',v));}
function has(a,v){return index(a,v)>=0;}
function chain(n){return n?.protocol=='chain';}
function map_nodes(store){let out={};for(let n in store?.nodes||[])out[n.id]=n;return out;}
// A HY2 front with port hopping occupies its whole hop list on that server.
function hop_covers(n,port){for(let part in split(n?.hop_ports||'',',')){if(!part)continue;let p=split(part,'-');if(port>=int(p[0])&&port<=int(p[length(p)-1]))return true;}return false;}
function bind(api){
 function fail(code,param,message){api.fail(code,param,message);}
 function need(ok,code,param,message){if(!ok)fail(code,param,message);}
 function shape(n){
  need(type(n)=='object'&&chain(n),'param_invalid','protocol','需要链类型');
  for(let k in keys(n))need(has(['id','name','protocol','front','rear','udp','udp_expected_ip','udp_verification'],k),'param_unsupported',k,'链不接受该字段');
  need(api.valid_id(n.id)&&api.str(n.name,80)&&api.utf8_length(n.name)>0&&length(trim(n.name))>0,'param_invalid','name','链编号或名称无效');
  need(api.valid_id(n.front)&&api.valid_id(n.rear),'param_invalid','front','前置和后置必须使用有效节点编号');
  need(n.front!=n.id&&n.rear!=n.id&&n.front!=n.rear,'param_invalid','front','不能自引用或重复引用');
  api.udp_shape(n);return n;
 }
 function role_ready(n,which){
  if(!n||chain(n))return false;let c=api.combo(n);if(!c||!api.available(n))return false;
  return c[which]==true&&has(['trial','loopback','verified'],c[which+'_status']);
 }
 function pair_ready(front,rear){
  if(!front||!rear||chain(front)||chain(rear))return false;let f=api.feature(),a=api.combo(front),b=api.combo(rear);if(!has(['trial','loopback','verified'],f?.status)||!role_ready(front,'chain_front')||!role_ready(rear,'chain_rear'))return false;
  if(f.status=='trial')return true;
  let front_kind=match(front.server,/^[0-9.]+$/)?'ipv4':'domain',rear_kind=match(rear.server,/^[0-9.]+$/)?'ipv4':'domain';
  return length(filter(f.validated_pairs||[],p=>p.front_combo==a.id&&p.rear_combo==b.id&&has(['loopback','verified'],p.status)&&has(p.front_address_kinds||[],front_kind)&&has(p.rear_address_kinds||[],rear_kind)&&p.tcp_two_hop==true&&p.final_domain_preserved==true&&p.fakeip_rejected==true&&p.data_gate_verified==true))==1;
 }
 function validate(n,store,published){
  shape(n);let by=map_nodes(store),front=by[n.front],rear=by[n.rear];
  need(front!=null&&rear!=null,'param_invalid','front','链依赖不存在');
  need(!chain(front)&&!chain(rear),'combo_unsupported','front','只允许两跳，链不能作为前置或后置');
  need(!has(['socks5','http'],front.protocol)&&has(['socks5','http'],rear.protocol),'role_restricted','rear','前置须为普通代理节点，后置仅 SOCKS5 或 HTTP');
  // Endpoint validation rejects literal FakeIP/private/self endpoints; domain
  // resolution and loop prevention must be proven for each published pair.
  api.endpoint(front.server,front.port);api.endpoint(rear.server,rear.port);
  need(lc(front.server)!=lc(rear.server)||front.port!=rear.port&&!hop_covers(front,rear.port),'param_invalid','rear','前后置端点不能相同');
  if(published){need(pair_ready(front,rear),'verification_pending','chain','此两跳组合或端点形式尚未完成固定版本验证');api.udp_check(n,store);}
  return {front,rear};
 }
 function available(n,store){if(!store)return false;let by=map_nodes(store);return pair_ready(by[n.front],by[n.rear])&&(!n.udp||(api.udp_ready(by[n.front],by[n.rear])));}
 function tag(id,store){let n=map_nodes(store)[id];need(n!=null,'param_invalid','node','指定节点不存在');if(chain(n))return 'chain-'+id;return id==store.default_node?'proxy-default':'node-'+id;}
 function references(store,id){return map(filter(store.nodes,n=>chain(n)&&(n.front==id||n.rear==id)),n=>({id:n.id,name:n.name,role:n.front==id?'front':'rear'}));}
 function closure(store,roots){
  let by=map_nodes(store),used={},fronts={},chains={},rears={};
  for(let id in roots){let n=by[id];need(n!=null,'param_invalid','node','引用节点不存在');used[id]=true;
   if(chain(n)){let pair=validate(n,store,true);chains[id]=true;fronts[pair.front.id]=true;rears[pair.rear.id]=true;used[pair.front.id]=true;used[pair.rear.id]=true;}
   else{api.assert_regular(n);fronts[id]=true;}
  }
  return {records:sort(keys(used)),regular:sort(filter(keys(fronts),id=>id!=store.default_node)),chains:sort(keys(chains)),rears:sort(keys(rears))};
 }
 function outbound(n,store,front_tag){
  let pair=validate(n,store,true),expected=tag(pair.front.id,store);need(front_tag==expected||front_tag=='test-front','param_invalid','front','前置标签不一致');
  let out=api.render_rear(pair.rear);out.tag='chain-'+n.id;out.targetStrategy='AsIs';
  // Construct only the rear's modeled fields; never copy the default template.
  out.streamSettings.sockopt={dialerProxy:front_tag};delete out.proxySettings;delete out.mux;delete out.sendThrough;
  return out;
 }
 function guards(rule,store){
  if(!match(rule.outboundTag||'',/^chain-[a-z][a-z0-9_]{0,31}$/))return [copy(rule)];
  need(store!=null,'param_missing','store','链规则必须绑定节点库');let n=map_nodes(store)[substr(rule.outboundTag,6)];validate(n,store,true);
  need(rule.type=='field'&&rule.balancerTag==null,'param_invalid','rule','链规则必须为固定出站');
  need(rule.network==null||has(['tcp','udp','tcp,udp'],rule.network),'param_invalid','network','链规则网络条件不受支持');
  let ip_rule=rule.ip!=null;need(!ip_rule||safe_ondemand_ip(rule),'combo_unsupported','ip','链IP规则只允许已校验且数据未变化的按需分类');let out=[];
  if(!n.udp&&rule.network!='tcp'){let blocked=copy(rule);blocked.network='udp';blocked.outboundTag='block';push(out,blocked);}
  if(n.udp||rule.network!='udp'){
   let network=n.udp?(rule.network||'tcp,udp'):'tcp';
   if(!ip_rule){let fake=copy(rule);fake.network=network;fake.ip=['198.18.0.0/15','fc00::/18'];fake.outboundTag='block';push(out,fake);}
   let allowed=copy(rule);allowed.network=network;push(out,allowed);
  }return out;
 }
 function assert_outbounds(config,store,used,canon){
  let by={},nmap=map_nodes(store);for(let out in config.outbounds){need(!by[out.tag],'param_invalid','outbound','出站标签重复');by[out.tag]=out;}
  let expected={};for(let id in used.chains){let n=nmap[id],front=tag(n.front,store),out=by['chain-'+id];expected['chain-'+id]=true;
   need(out!=null&&canon(out)==canon(outbound(n,store,front)),'param_invalid','chain','链出站与专用生成结果不一致');
   need(by[front]!=null&&by[front].streamSettings?.sockopt?.mark==30241&&by[front].streamSettings?.sockopt?.dialerProxy==null&&by[front].proxySettings==null,'security_rejected','front','链前置物理数据标记或依赖异常');
   need(front!='dns-protected','security_rejected','front','不能使用健康 DNS 出站作为前置');
  }
  for(let name in keys(by))if(substr(name,0,6)=='chain-')need(expected[name]==true,'param_invalid','chain','出现无活跃引用的链出站');
  for(let i=0;i<length(config.routing.rules);i++){
   let r=config.routing.rules[i];if(substr(r.outboundTag||'',0,6)!='chain-')continue;
   let n=nmap[substr(r.outboundTag,6)];need(expected[r.outboundTag]==true&&has(n?.udp?['tcp','udp','tcp,udp']:['tcp'],r.network),'security_rejected','chain','链引用或 UDP 模式不一致');
   let ip_rule=r.ip!=null;
   if(ip_rule)need(safe_ondemand_ip(r),'security_rejected','chain','链IP规则或数据证明不符');
   else{let fake=copy(r);fake.ip=['198.18.0.0/15','fc00::/18'];fake.outboundTag='block';
    need(i>=1&&canon(config.routing.rules[i-1])==canon(fake),'security_rejected','chain','链前缺少同条件 FakeIP 阻断');}
   // Dedicated SOCKS inbounds accept TCP only; all other current chain roots
   // originated as TCP/UDP rules and require their matching UDP block.
   let tcp_only=length(r.inboundTag||[])==1&&substr(r.inboundTag[0],0,10)=='dedicated-';
   if(tcp_only){let ins=filter(config.inbounds||[],x=>x.tag==r.inboundTag[0]);need(length(ins)==1&&ins[0].protocol=='socks'&&ins[0].settings?.udp==false,'security_rejected','chain','专用链入口不能启用 UDP');}
   else if(!n.udp){let udp=copy(r);udp.network='udp';udp.outboundTag='block';let distance=ip_rule?1:2;need(i>=distance&&canon(config.routing.rules[i-distance])==canon(udp),'security_rejected','chain','链前缺少同条件 UDP 阻断');}
  }
  let regular={};for(let id in used.regular)regular['node-'+id]=true;
  for(let name in keys(by))if(substr(name,0,5)=='node-')need(regular[name]==true,'security_rejected','node','出现无活跃引用的普通或后置出站');
  return true;
 }
 return {shape,validate,available,role_ready,pair_ready,tag,references,closure,outbound,guards,assert_outbounds};
}
export {bind,chain,map_nodes};
