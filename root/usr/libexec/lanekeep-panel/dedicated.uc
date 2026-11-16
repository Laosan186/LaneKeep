import { route_tag, chain_rules } from './nodes.uc';
// Stage C first creation. Deterministic dedicated-entry surface, no I/O or credentials.
function active(rules) {
    return sort(filter(rules,r=>r.type=='dedicated' && r.enabled=='1'),(a,b)=>int(a.value)-int(b.value));
}
function tag(r) { return 'dedicated-'+r.group+'-'+r.value; }
function valid_port(v) { return type(v)=='string' && match(v,/^108[1-6][0-9]$/)!=null && int(v)>=10811 && int(v)<=10860; }
function inbound(r) {
    return {tag:tag(r),listen:'__LAN_ADDRESS__',port:int(r.value),protocol:'socks',settings:{auth:'noauth',udp:false},sniffing:{enabled:false}};
}
function routes(r,store) {
    let tags=[tag(r)],out=r.action=='node'?route_tag(r.node,store):r.action=='proxy'?'proxy-default':'direct';
    let result=[
        {type:'field',inboundTag:tags,ip:['geoip:private','0.0.0.0/8','100.64.0.0/10','198.18.0.0/15','224.0.0.0/4','240.0.0.0/4','::/128','::1/128','64:ff9b::/96','64:ff9b:1::/48','2001:2::/48','fc00::/7','fe80::/10','ff00::/8'],outboundTag:'block'},
        {type:'field',inboundTag:tags,domain:['geosite:private','domain:lan','domain:local','full:localhost'],outboundTag:'block'},
        {type:'field',inboundTag:tags,port:'53,853,1053,5053,10811-10860,12345-12348',outboundTag:'block'},
        {type:'field',inboundTag:tags,network:'tcp',outboundTag:out},
        {type:'field',inboundTag:tags,outboundTag:'block'}
    ];
    let expanded=[];for(let rule in result)for(let row in chain_rules(rule,store))push(expanded,row);return expanded;
}
function internal_rule(r) {
    return r.outboundTag=='block' && r.port=='1053,12345-12348,5053' &&
        join(',',r.ip || [])=='127.0.0.0/8,__LAN_ADDRESS__/32' &&
        join(',',r.inboundTag || [])=='standard-transparent,global-transparent,enhanced-transparent,ondemand-transparent';
}
function protected_rule(r,enabled) {
    let copy=json(sprintf('%J',r));
    if(enabled && internal_rule(copy)) copy.port+=',10811-10860';
    return copy;
}
function dns_anchor(r) { return r.port=='53' && r.outboundTag=='lan-dns-out'; }
function nft(base,rules) {
    let entries=active(rules);if(!length(entries))return base;
    let lines=['    chain dedicated_access {'];
    for(let r in entries)push(lines,'        iifname "__LAN_DEVICE__" ip saddr @lanekeep_grp_'+r.group+' ip daddr __LAN_ADDRESS__ tcp dport '+r.value+' meta mark set 0x7610 accept');
    push(lines,'        drop','    }');
    let out=replace(base,'    chain select_phone {',join('\n',lines)+'\n    chain select_phone {');
    // Mark only after membership validation. This passes the earlier boot input
    // guard without invoking a TPROXY target; the same ACL is checked again at input.
    let jump='        ip daddr __LAN_ADDRESS__ meta l4proto { tcp, udp } th dport 10811-10860 jump dedicated_access\n';
    out=replace(out,'type filter hook prerouting priority -151; policy accept;\n','type filter hook prerouting priority -151; policy accept;\n'+jump);
    out=replace(out,'type filter hook input priority -1; policy accept;\n','type filter hook input priority -1; policy accept;\n'+jump);
    return out;
}
function warnings(before,after) {
    let now={};for(let r in after)now[r.id]=r;
    return map(filter(before,r=>r.type=='dedicated' && r.enabled=='1' &&
        (!now[r.id] || now[r.id].type!='dedicated' || now[r.id].enabled!='1' || now[r.id].value!=r.value || now[r.id].group!=r.group)),
        r=>'入口 '+r.value+' 将停用、删除或改变。请先在增强运行该浏览器的“关闭”文件，否则浏览器可能无法上网。');
}
export { active, tag, valid_port, inbound, routes, internal_rule, protected_rule, dns_anchor, nft, warnings };
