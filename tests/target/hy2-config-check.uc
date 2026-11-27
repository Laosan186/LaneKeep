// SPDX-License-Identifier: GPL-3.0-only
// Checks generated config.json for the hop/pin store built by hy2-check.sh.
// Usage: ucode hy2-config-check.uc HOP_CONFIG PLAIN_CONFIG TEMPLATE
// The plain config comes from the same nodes without the HY2 hop, pin and tuning fields. After removing finalmask and
// pinnedPeerCertSha256 the two configs must be identical, so routes, groups, marks and DNS stay as they were.
import * as fs from 'fs';
let hop=json(fs.readfile(ARGV[0])),plain=json(fs.readfile(ARGV[1])),tpl=json(fs.readfile(ARGV[2]));
let PIN='0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
let PIN2='fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';
let want={'203.0.113.20':{hop:'20000-50000',pin:PIN,interval:60,q:{brutalUp:'60mbps',brutalDown:'200mbps'}},'203.0.113.21':{hop:'443,20000-30000,40000',pin:null,interval:30,q:null},'203.0.113.22':{hop:null,pin:PIN2,q:{brutalDown:'100mbps'}}};
let fails=0;
function check(name,ok,detail){if(ok)return;fails++;print('  '+name+(detail!=null?': '+detail:'')+'\n');}
function has(o,k){return type(o)=='object'&&index(keys(o),k)>=0;}
let marks={};for(let o in tpl.outbounds)if(o.streamSettings?.sockopt?.mark!=null)marks[o.tag]=o.streamSettings.sockopt.mark;
let tags={},count=0;
for(let o in hop.outbounds){
 tags[o.tag]=o;
 if(o.protocol!='hysteria')continue;count++;
 let w=want[o.settings?.address],s=o.streamSettings||{},t=s.tlsSettings||{};
 check(o.tag+' known server',w!=null,o.settings?.address);if(!w)continue;
 if(w.hop){
  let udp=s.finalmask?.udp;
  check(o.tag+' finalmask udp list',has(s,'finalmask')&&type(udp)=='array',sprintf('%J',s.finalmask));
  let last=udp?.[length(udp)-1];
  check(o.tag+' udphop is last',last?.type=='udphop');
  check(o.tag+' udphop settings',last?.settings?.mode=='intervalLocal,intervalRemote'&&last?.settings?.interval==w.interval&&last?.settings?.remotePorts==w.hop&&!has(last?.settings,'remoteIPs'),sprintf('%J',last));
 }else check(o.tag+' no udp mask',!has(s.finalmask,'udp'));
 check(o.tag+' finalmask keys',has(s,'finalmask')==(w.hop!=null||w.q!=null)&&(!has(s,'finalmask')||length(keys(s.finalmask))==(w.hop?1:0)+(w.q?1:0)),sprintf('%J',s.finalmask));
 let q=s.finalmask?.quicParams;
 check(o.tag+' brutal bandwidth',w.q?type(q)=='object'&&length(keys(q))==length(keys(w.q))&&length(filter(keys(w.q),k=>q[k]==w.q[k]))==length(keys(w.q)):!has(s.finalmask,'quicParams'),sprintf('%J',q));
 check(o.tag+' pin',w.pin?t.pinnedPeerCertSha256==w.pin:!has(t,'pinnedPeerCertSha256'),t.pinnedPeerCertSha256);
 check(o.tag+' no allowInsecure',!has(t,'allowInsecure'));
 let mark=s.sockopt?.mark,expect=o.tag=='dns-protected'?marks['dns-protected']:30241;
 check(o.tag+' sockopt mark',mark==expect&&mark!=null,sprintf('%J != %J',mark,expect));
}
check('hysteria outbound count',count>=4,count);
for(let tag in ['proxy-default','dns-protected','node-node_b','node-node_c'])check('outbound '+tag,tags[tag]?.protocol=='hysteria');
check('proxy-default is node A',tags['proxy-default']?.settings?.address=='203.0.113.20');
check('dns-protected is node A',tags['dns-protected']?.settings?.address=='203.0.113.20');
check('global group routes to node B',length(filter(hop.routing?.rules||[],r=>r.outboundTag=='node-node_b'))>0);
check('enhanced group routes to node C',length(filter(hop.routing?.rules||[],r=>r.outboundTag=='node-node_c'))>0);
// Removing finalmask and the pin must give the plain configuration exactly.
for(let o in hop.outbounds){let s=o.streamSettings;if(type(s)!='object')continue;delete s.finalmask;if(type(s.tlsSettings)=='object')delete s.tlsSettings.pinnedPeerCertSha256;}
check('only finalmask and pin differ from the plain configuration',sprintf('%J',hop)==sprintf('%J',plain));
if(fails)exit(1);
