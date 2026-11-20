// SPDX-License-Identifier: GPL-3.0-only
// Compares generator output with IP rules (ARGV[1]) against the same rules without them (ARGV[0]).
import * as fs from 'fs';
function load(p){return json(fs.readfile(p));}
function canon(v){if(type(v)=='object')return '{'+join(',',map(sort(keys(v)),k=>sprintf('%J',k)+':'+canon(v[k])))+'}';if(type(v)=='array')return '['+join(',',map(v,canon))+']';return sprintf('%J',v);}
let s0=load(ARGV[0]+'/config.json').routing.rules,s1=load(ARGV[1]+'/config.json').routing.rules;
let values={};for(let r in load(ARGV[1]+'/normalized-rules.json').rules)if(r.type=='ip')values[r.value]=r.enabled;
function user_ip(r){return type(r.ip)=='array'&&length(filter(r.ip,v=>values[v]==null))==0;}
let ip_rows=filter(s1,user_ip),rest=filter(s1,r=>!user_ip(r)),fails=[];
if(canon(rest)!=canon(s0))push(fails,'rows_without_ip_rules_differ');
for(let r in ip_rows){
 if(r.domain!=null)push(fails,'ip_row_has_domain');
 if(length(r.inboundTag||[])!=1)push(fails,'ip_row_inbound');
 for(let v in r.ip)if(values[v]!='1')push(fails,'disabled_rule_rendered:'+v);
}
// On-demand proxy-type IP rules get a UDP 443 block row ahead of the user rows.
let guard=filter(ip_rows,r=>r.network=='udp'&&r.port=='443');
if(length(guard)!=1||guard[0].outboundTag!='block'||guard[0].inboundTag[0]!='ondemand-transparent')push(fails,'ondemand_ip_guard');
let gi=index(s1,guard[0]),di=-1;for(let i=0;i<length(s1);i++)if(s1[i].network=='udp'&&s1[i].port=='443'&&type(s1[i].domain)=='array'&&s1[i].inboundTag[0]=='ondemand-transparent'&&substr(s1[i].domain[0],0,8)!='geosite:')di=i;
if(di<0||gi!=di+1)push(fails,'guard_order');
printf('%J\n',{rows_without:length(s0),rows_with:length(s1),ip_rows,fails});
exit(length(fails)?1:0);
