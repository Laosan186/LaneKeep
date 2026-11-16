// First creation: narrowly variable fallback destinations and real-DNS domains.
import { assert_reference, route_tag, chain_rules } from './nodes.uc';
let GROUPS=['standard','global','enhanced','ondemand'];
let TAGS={standard:'standard-transparent',global:'global-transparent',enhanced:'enhanced-transparent',ondemand:'ondemand-transparent'};
let LABELS={standard:'常规',global:'全局',enhanced:'增强',ondemand:'按需'};
function defaults() {
    return {group_nodes:{standard:'',global:'',enhanced:'',ondemand:''},fallbacks:{standard:{action:'direct',node:''},global:{action:'proxy',node:''},enhanced:{action:'proxy',node:''},ondemand:{action:'direct',node:''}},real_dns:[]};
}
function presets() {return [];}
function only(v,allowed) {
    if(type(v)!='object')die('settings_object_required');
    for(let k in keys(v))if(substr(k,0,1)!='.' && index(allowed,k)<0)die('settings_unknown_field');
}
function section(data,s,seen) {
    if(s['.type']=='group_proxy') {
        only(s,['group','node']);let g=s.group;
        if(index(GROUPS,g)<0 || s['.name']!='group_proxy_'+g || seen['proxy_'+g])die('invalid_group_proxy_section');
        seen['proxy_'+g]=true;data.group_nodes[g]=s.node ?? '';return true;
    }
    if(s['.type']=='fallback') {
        only(s,['group','action','node']);let g=s.group;
        if(index(GROUPS,g)<0 || s['.name']!='fallback_'+g || seen[g])die('invalid_fallback_section');
        seen[g]=true;data.fallbacks[g]={action:s.action,node:s.node || ''};return true;
    }
    if(s['.type']=='real_dns') {
        only(s,['domain']);if(s['.name']!='real_dns' || seen.dns)die('invalid_real_dns_section');
        seen.dns=true;data.real_dns=s.domain || [];return true;
    }
    return false;
}
function validate(value,store) {
    only(value,['fallbacks','real_dns','group_nodes']);only(value.fallbacks,GROUPS);
    if(value.group_nodes!=null)only(value.group_nodes,GROUPS);
    let out=defaults();
    for(let g in GROUPS) {
        let id=value.group_nodes?.[g] ?? '';
        if(type(id)!='string')die('group_node_string_required');
        if(id!=''){let n=filter(store.nodes,n=>n.id==id)[0];if(!n)die('group_node_missing');assert_reference(n,store);}
        out.group_nodes[g]=id;
        let f=value.fallbacks[g];only(f,['action','node']);
        if(index(['proxy','node','direct'],f.action)<0)die('invalid_fallback_action');
        if(f.action=='node') {if(type(f.node)!='string' || !length(filter(store.nodes,n=>n.id==f.node)))die('fallback_node_missing');assert_reference(filter(store.nodes,n=>n.id==f.node)[0],store);}
        else if(f.node!=null && f.node!='')die('unexpected_fallback_node');
        out.fallbacks[g]={action:f.action,node:f.node || ''};
    }
    if(type(value.real_dns)!='array' || length(value.real_dns)>200)die('real_dns_list_required_max_200');
    let seen={};
    for(let entry in value.real_dns) {
        if(type(entry)!='string' || length(entry)>260)die('invalid_real_dns_domain');
        entry=lc(trim(entry));let m=match(entry,/^(domain|full):([a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+)$/);
        if(!m || length(m[2])>253)die('real_dns_requires_domain_or_full');
        for(let label in split(m[2],'.'))if(length(label)>63)die('invalid_real_dns_domain');
        if(seen[entry])die('duplicate_real_dns_domain');seen[entry]=true;push(out.real_dns,entry);
    }
    return out;
}
function encode(data,quote) {
    let lines=[];
    for(let g in GROUPS) {
        let id=data.group_nodes?.[g] || '';
        if(id!='')push(lines,'config group_proxy '+quote('group_proxy_'+g),'\toption group '+quote(g),'\toption node '+quote(id),'');
        let f=data.fallbacks[g];push(lines,'config fallback '+quote('fallback_'+g),'\toption group '+quote(g),'\toption action '+quote(f.action));
        if(f.action=='node')push(lines,'\toption node '+quote(f.node));push(lines,'');
    }
    push(lines,"config real_dns 'real_dns'");for(let d in data.real_dns)push(lines,'\tlist domain '+quote(d));push(lines,'');return lines;
}
function fallback_group(r) {
    if(type(r)!='object' || length(keys(r))!=4 || r.type!='field' || r.network!='tcp,udp' || type(r.inboundTag)!='array' || length(r.inboundTag)!=1 || r.outboundTag==null)return null;
    for(let g in GROUPS)if(r.inboundTag[0]==TAGS[g])return g;return null;
}
// Only transparent group business routes inherit this choice. DNS and dedicated entries do not.
function proxy_tag(data,group,store) {
    let id=data.group_nodes?.[group] || '';return id==''?'proxy-default':route_tag(id,store);
}
function route(rule,data,store) {
    let r=json(sprintf('%J',rule)),g=fallback_group(r);
    if(g!=null){let f=data.fallbacks[g];r.outboundTag=f.action=='direct'?'direct':f.action=='proxy'?proxy_tag(data,g,store):route_tag(f.node,store);return r;}
    if(r.outboundTag=='proxy-default' && length(r.inboundTag || [])==1)
        for(let group in GROUPS)if(r.inboundTag[0]==TAGS[group])r.outboundTag=proxy_tag(data,group,store);
    return r;
}
function routes(rule,data,store){return chain_rules(route(rule,data,store),store);}
function dns(template,data) {
    let d=json(sprintf('%J',template)),found=0;
    for(let s in d.servers || [])if(index(s.domains || [],'geosite:connectivity-check')>=0) {
        if(s.address!='https://1.1.1.1/dns-query' || s.tag!='protected-real-dns' || s.finalQuery!=true || s.skipFallback!=true)die('real_dns_anchor_changed');
        found++;for(let domain in data.real_dns)if(index(s.domains,domain)<0)push(s.domains,domain);
    }
    if(found!=1)die('real_dns_anchor_missing_or_duplicate');
    // Isolate the existing health query from one stale HTTP/2 connection.
    // Both endpoints use protected-real-dns -> dns-protected; no direct/system resolver.
    let health='full:one.one.one.one',servers=[],health_count=0,backup_count=0;
    for(let s in d.servers || []) {
        if(index(s.domains || [],health)<0){push(servers,s);continue;}
        if(s.address=='https://1.0.0.1/dns-query') {
            backup_count++;
            if(length(s.domains)!=1 || s.tag!='protected-real-dns' || s.disableCache!=true || s.skipFallback!=true || s.finalQuery!=true || s.timeoutMs!=900)die('health_dns_backup_changed');
            continue;
        }
        health_count++;
        if(length(s.domains)!=1 || s.address!='https://1.1.1.1/dns-query' || s.tag!='protected-real-dns' || s.disableCache!=true || s.skipFallback!=true)die('health_dns_anchor_changed');
        if(s.finalQuery!=true && !(s.finalQuery==false && s.timeoutMs==800))die('health_dns_policy_changed');
        s.finalQuery=false;s.timeoutMs=800;push(servers,s);
        push(servers,{address:'https://1.0.0.1/dns-query',disableCache:true,domains:[health],finalQuery:true,skipFallback:true,tag:'protected-real-dns',timeoutMs:900});
    }
    if(health_count!=1 || backup_count>1)die('health_dns_anchor_missing_or_duplicate');
    d.servers=servers;return d;
}
function diff(before,after) {
    let fallbacks=[];for(let g in GROUPS)if(before.fallbacks[g].action!=after.fallbacks[g].action || before.fallbacks[g].node!=after.fallbacks[g].node)push(fallbacks,{group:g,before:before.fallbacks[g],after:after.fallbacks[g]});
    let group_nodes=[];for(let g in GROUPS){let a=before.group_nodes?.[g] || '',b=after.group_nodes?.[g] || '';if(a!=b)push(group_nodes,{group:g,before:a,after:b});}
    return {group_node_changes:group_nodes,fallback_changes:fallbacks,real_dns_change:sprintf('%J',before.real_dns)==sprintf('%J',after.real_dns)?null:{before:before.real_dns,after:after.real_dns}};
}
function warnings(summary) {
    let out=[];
    for(let c in summary.group_node_changes || [])push(out,LABELS[c.group]+'组代理节点改变：内置代理分类、普通代理规则及代理兜底跟随此选择；直连、屏蔽、明确指定节点、专用入口与DNS路径保持。TCP链只承载命中它的TCP，UDP阻断；所有代理仍受原默认节点健康门控约束。');
    for(let change in summary.fallback_changes || []) {
        let lead=LABELS[change.group]+'组兜底出口：';
        if(change.after.action=='direct')push(out,lead+'未被识别为国外网站的流量将从国内直接访问，部分国外网站可能打不开。');
        else push(out,lead+'未命中前面规则的流量使用'+(change.after.action=='proxy'?'本组代理节点（未选择时跟随全局默认）':'指定节点')+'；代理或DNS故障时保持阻断。');
        if(change.group=='global' && change.after.action!='proxy')push(out,'全局兜底改变后，Wi-Fi通话的真实IP也会使用该出口；请确认运营商所需出口。');
    }
    if(summary.real_dns_change)push(out,'不使用假 IP 的域名对所有组生效，通过代理真实DoH解析；实际流量仍按所属组规则匹配。重启会清除共享FakeDNS，Wi-Fi通话可能需要几分钟重新注册。');
    return out;
}


// Standard domestic-classification direct routes retain the original domestic DNS.
// Other public standard routes resolve through the existing protected DNS channel.
// Shared DNS and every original outbound remain unchanged.
const FAMILY_RESOLVE='standard-resolve-';
function standard_canonical(v){
 if(type(v)=='object')return '{'+join(',',map(sort(keys(v)),k=>sprintf('%J',k)+':'+standard_canonical(v[k])))+'}';
 if(type(v)=='array')return '['+join(',',map(v,standard_canonical))+']';return sprintf('%J',v);
}
function standard_copy(v){return json(sprintf('%J',v));}
function standard_same(a,b){return standard_canonical(a)==standard_canonical(b);}
function standard_reserved(tag){return substr(tag||'',0,length(FAMILY_RESOLVE))==FAMILY_RESOLVE;}
function standard_target(tag){return tag=='direct'||tag=='proxy-default'||substr(tag||'',0,5)=='node-'||substr(tag||'',0,6)=='chain-';}
function standard_private(r){
 return r.outboundTag=='direct'&&(
  standard_same(r.domain,['geosite:private'])||
  standard_same(r.domain,['geosite:private','domain:lan','domain:local'])||
  standard_same(r.ip,['geoip:private']));
}
function standard_domestic(r){
 // Only the existing mainland/domain classification receives domestic resolution.
 // Do not classify arbitrary direct rules or the unmatched fallback as domestic.
 return r.outboundTag=='direct'&&standard_same(r.domain,['geosite:cn']);
}
function standard_wrap_rule(r){return standard_same(r.inboundTag,['standard-transparent'])&&standard_target(r.outboundTag)&&!standard_private(r)&&!standard_domestic(r);}
function standard_wrapper(tag){
 return {tag:FAMILY_RESOLVE+tag,protocol:'freedom',settings:{},
  streamSettings:{sockopt:{domainStrategy:'ForceIP',dialerProxy:tag}}};
}
function standard_physical_ip(config,tag,seen){
 if(index(seen,tag)>=0)die('standard_dns_outbound_cycle');
 let list=filter(config.outbounds||[],o=>o.tag==tag);if(length(list)!=1)die('standard_dns_missing_exit');
 let o=list[0];if(o.protocol=='freedom'){if(tag!='direct'||o.streamSettings?.sockopt?.mark!=255)die('standard_dns_direct_anchor');return;}
 let next=o.streamSettings?.sockopt?.dialerProxy;
 if(next!=null){standard_physical_ip(config,next,[...seen,tag]);return;}
 let a=o.settings?.address||o.settings?.vnext?.[0]?.address||o.settings?.servers?.[0]?.address;
 if(type(a)!='string'||!match(a,/^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/)||length(filter(split(a,'.'),p=>int(p)<0||int(p)>255)))
  die('standard_dns_physical_endpoint_requires_ipv4_literal');
}
function standard_dns_restore(config){
 let result=standard_copy(config),mapped={},used={};
 for(let o in result.outbounds||[])if(standard_reserved(o.tag)){
  let tag=substr(o.tag,length(FAMILY_RESOLVE));
  if(!standard_target(tag)||!standard_same(o,standard_wrapper(tag))||mapped[o.tag]!=null)die('standard_dns_wrapper_drift');
  mapped[o.tag]=tag;
 }
 for(let r in result.routing?.rules||[])if(standard_reserved(r.outboundTag)){
  let tag=mapped[r.outboundTag];if(tag==null||!standard_same(r.inboundTag,['standard-transparent']))die('standard_dns_cross_group_reference');
  used[r.outboundTag]=true;r.outboundTag=tag;if(!standard_wrap_rule(r))die('standard_dns_private_route_changed');
 }
 for(let key in keys(mapped))if(!used[key])die('standard_dns_unused_wrapper');
 result.outbounds=filter(result.outbounds||[],o=>!standard_reserved(o.tag));
 return result;
}
function standard_dns_enable(config){
 let before=standard_copy(config),d=config.dns;
 if(d?.disableFallback!=true||d?.useSystemHosts!=false||d?.queryStrategy!='UseIPv4'||d?.enableParallelQuery!=false)die('standard_dns_dns_anchor');
 for(let s in d.servers||[])if(s.address!='fakedns'&&(!(s.address=='https://1.1.1.1/dns-query'||s.address=='https://1.0.0.1/dns-query')||s.tag!='protected-real-dns'||s.skipFallback!=true))die('standard_dns_upstream_drift');
 if(length(filter(d.servers||[],s=>s.address=='fakedns'))!=1)die('standard_dns_fake_anchor');
 let routes=filter(config.routing?.rules||[],r=>standard_same(r.inboundTag,['protected-real-dns']));
 if(length(routes)!=1||routes[0].outboundTag!='dns-protected')die('standard_dns_doh_route_anchor');
 standard_physical_ip(config,'dns-protected',[]);
 for(let o in config.outbounds||[])if(standard_reserved(o.tag))die('standard_dns_reserved_collision');
 for(let r in config.routing.rules)if(standard_reserved(r.outboundTag))die('standard_dns_reserved_collision');
 let targets=[],changed=0;
 for(let r in config.routing.rules)if(standard_wrap_rule(r)){
  let tag=r.outboundTag;if(index(targets,tag)<0){standard_physical_ip(config,tag,[]);push(targets,tag);}
  r.outboundTag=FAMILY_RESOLVE+tag;changed++;
 }
 if(!changed)die('standard_dns_missing_public_route');
 for(let tag in targets)push(config.outbounds,standard_wrapper(tag));
 // Reversal proves all DNS, all original outbounds, other groups, rule matches,
 // data exits, FakeDNS, policy, log fields and order are preserved exactly.
 if(!standard_same(standard_dns_restore(config),before))die('standard_dns_unexpected_delta');
 return {scope:'standard_only',domestic_dns:'existing_dnsmasq_ali_doh',foreign_unknown_dns:'cloudflare_via_protected_dns',wrapper_count:length(targets),route_count:changed,shared_dns_changed:false};
}
function standard_dns_active(config){
 try{
  if(!length(filter(config.outbounds||[],o=>standard_reserved(o.tag))))return false;
  let base=standard_dns_restore(config);standard_dns_enable(base);return standard_same(base,config);
 }catch(e){return false;}
}
function standard_dns_base(config){
 if(length(filter(config.outbounds||[],o=>standard_reserved(o.tag)))&&!standard_dns_active(config))die('standard_dns_config_incomplete');
 return standard_dns_restore(config);
}

export { defaults, presets, section, validate, encode, fallback_group, proxy_tag, route, routes, dns, diff, warnings, standard_dns_enable, standard_dns_active, standard_dns_base };
