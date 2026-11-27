// SPDX-License-Identifier: GPL-3.0-only
// HY2 port hopping and certificate pin cases for nodes.uc, chain-model.uc and monitor-capture.uc.
// Run on an OpenWrt test machine: ucode tests/target/hy2-cases.uc
// Synthetic values only (TEST-NET addresses, fixed fake pin); nothing is written outside /tmp.
import * as nodes from '../../root/usr/libexec/lanekeep-panel/nodes.uc';
import * as monitor from '../../root/usr/libexec/lanekeep-telemetry/monitor-capture.uc';
let fails=0,count=0;
function check(name,ok,detail){count++;if(ok)print('PASS '+name+'\n');else{fails++;print('FAIL '+name+(detail!=null?': '+detail:'')+'\n');}}
let PIN='0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
let COLONS='',PBK='AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
for(let i=0;i<64;i+=2)COLONS+=(i?':':'')+uc(substr(PIN,i,2));
let DASHES='';for(let i=0;i<64;i+=8)DASHES+=(i?'-':'')+substr(PIN,i,8);
let BASE='hysteria2://PASSWORD@203.0.113.10:443/?sni=example.com';
function row(link){return nodes.parse_preview(link)[0];}
function has(n,k){return index(keys(n),k)>=0;}
function accept(name,link,port,hop,pin){
 let r=row(link),n=r.node;
 if(r.status!='ok'){check(name,false,sprintf('%J',r.error));return null;}
 let got_hop=has(n,'hop_ports')?n.hop_ports:null,got_pin=has(n,'pin_sha256')?n.pin_sha256:null;
 check(name,n.port==port&&got_hop==hop&&got_pin==pin&&n.insecure==false,sprintf('port=%J hop=%J pin=%J insecure=%J',n.port,got_hop,got_pin,n.insecure));
 return n;
}
function reject(name,link,code,param){
 let r=row(link);
 check(name,r.status=='error'&&r.error.code==code&&r.error.param==param,sprintf('%J',r.status=='error'?r.error:r.node));
}
function store_result(store){try{nodes.validate_store(store);return 'ok';}catch(e){let m=nodes.take_error();return m?m.code+':'+m.param:'die:'+e.message;}}
function update_result(input,previous){try{return nodes.update_node(input,previous);}catch(e){let m=nodes.take_error();return m?m.code+':'+m.param:'die:'+e.message;}}

// Share links: accepted forms.
let hop=accept('mport range with pin',BASE+'&mport=20000-50000&pinSHA256='+PIN+'#test',443,'20000-50000',PIN);
accept('authority multi-port (official form)','hy2://PASSWORD@203.0.113.10:443,20000-50000/?sni=example.com#t',443,'443,20000-50000',null);
accept('authority range only','hysteria2://PASSWORD@203.0.113.10:20000-50000/?sni=example.com',20000,'20000-50000',null);
accept('IPv6 authority with ports','hysteria2://PASSWORD@[2001:db8::1]:443,20000-20010/?sni=example.com',443,'443,20000-20010',null);
accept('mport with colon range','hysteria2://PASSWORD@203.0.113.10:443/?sni=example.com&mport=20000:50000',443,'20000-50000',null);
accept('mport sorted and merged',BASE+'&mport=30000-40000,20000-35000,443',443,'443,20000-40000',null);
accept('mport adjacent ranges merged',BASE+'&mport=1000-1999,2000-2999',443,'1000-2999',null);
accept('mport with encoded space',BASE+'&mport=20000-30000,%2040000',443,'20000-30000,40000',null);
accept('pin uppercase with colons',BASE+'&pinSHA256='+COLONS,443,null,PIN);
accept('pin with dashes (official normalization)',BASE+'&pinSHA256='+DASHES,443,null,PIN);
accept('insecure=1 accepted with pin',BASE+'&insecure=1&pinSHA256='+PIN,443,null,PIN);
accept('allowInsecure=1 accepted with pin',BASE+'&allowInsecure=1&pinSHA256='+PIN,443,null,PIN);
accept('insecure=0 with pin',BASE+'&insecure=0&pinSHA256='+PIN,443,null,PIN);
accept('empty mport and pin mean unset',BASE+'&mport=&pinSHA256=',443,null,null);
accept('single mport port equal to main port',BASE+'&mport=443',443,null,null);
let plain=accept('plain HY2 unchanged',BASE+'&alpn=h3',443,null,null);

// Share links: rejected forms.
reject('insecure=1 without pin',BASE+'&insecure=1','security_rejected','insecure');
reject('insecure=1 with empty pin',BASE+'&insecure=1&pinSHA256=','security_rejected','insecure');
reject('allowInsecure=1 without pin',BASE+'&allowInsecure=1','security_rejected','allowInsecure');
reject('pin 63 hex digits',BASE+'&pinSHA256='+substr(PIN,1),'param_invalid','pinSHA256');
reject('pin 65 hex digits',BASE+'&pinSHA256='+PIN+'0','param_invalid','pinSHA256');
reject('pin base64',BASE+'&pinSHA256=ASNFZ4mrze8BI0VniavN7wEjRWeJq83vASNFZ4mrze8=','param_invalid','pinSHA256');
reject('pin non-hex',BASE+'&pinSHA256='+substr(PIN,0,63)+'g','param_invalid','pinSHA256');
reject('pin list not accepted',BASE+'&pinSHA256='+PIN+','+PIN,'param_invalid','pinSHA256');
reject('mport reversed range',BASE+'&mport=50000-20000','param_invalid','mport');
reject('mport port 0',BASE+'&mport=0-100','param_invalid','mport');
reject('mport above 65535',BASE+'&mport=60000-65536','param_invalid','mport');
reject('mport wildcard all',BASE+'&mport=all','param_invalid','mport');
reject('mport wildcard star',BASE+'&mport=*','param_invalid','mport');
reject('mport open range',BASE+'&mport=20000-','param_invalid','mport');
reject('mport three parts',BASE+'&mport=1-2-3','param_invalid','mport');
reject('mport trailing comma',BASE+'&mport=20000-30000,','param_invalid','mport');
reject('mport nine segments',BASE+'&mport=1,2,3,4,5,6,7,8,9','limit_exceeded','mport');
reject('mport single port differs from main',BASE+'&mport=8443','param_invalid','mport');
reject('mport duplicated',BASE+'&mport=20000-30000&mport=40000-50000','param_invalid','mport');
reject('mport together with authority ports','hysteria2://PASSWORD@203.0.113.10:443,20000-30000/?sni=example.com&mport=40000-50000','param_invalid','mport');
reject('authority trailing comma','hysteria2://PASSWORD@203.0.113.10:443,/?sni=example.com','param_invalid','port');
reject('authority reversed range','hysteria2://PASSWORD@203.0.113.10:50000-20000/?sni=example.com','param_invalid','port');
reject('obfs still rejected',BASE+'&obfs=salamander&obfs-password=x','param_unsupported','obfs');
reject('bandwidth parameter still unknown',BASE+'&upmbps=100','param_unsupported','upmbps');
let VL='vless://00000000-0000-4000-8000-000000000001@203.0.113.11:443?security=reality&pbk='+PBK+'&sni=example.com';
reject('VLESS rejects mport',VL+'&mport=20000-30000','param_unsupported','mport');
reject('VLESS rejects pinSHA256',VL+'&pinSHA256='+PIN,'param_unsupported','pinSHA256');
reject('VLESS rejects multi-port authority','vless://00000000-0000-4000-8000-000000000001@203.0.113.11:443,8443?security=reality&pbk=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA&sni=example.com','param_invalid','port');

// Store versions and canonical storage.
check('minimum_version 7 with hop/pin',hop!=null&&nodes.minimum_version(hop)==7);
check('minimum_version 1 for plain HY2',plain!=null&&nodes.minimum_version(plain)==1);
function store(version,n){return {version:version,default_node:'',nodes:[n]};}
function with(n,extra){let c=json(sprintf('%J',n));for(let k in keys(extra)){if(extra[k]==null)delete c[k];else c[k]=extra[k];}return c;}
check('store v7 accepts canonical hop/pin node',store_result(store(7,hop))=='ok',store_result(store(7,hop)));
check('store v6 rejects hop/pin node',store_result(store(6,hop))=='param_invalid:version',store_result(store(6,hop)));
check('store v8 rejected',index(store_result(store(8,plain)),'die:')==0,store_result(store(8,plain)));
for(let c in [['20000:50000','colon'],['50000-60000,20000-30000','unsorted'],['443','single port'],['20000-50000,30000','overlap'],['020000-50000','leading zero'],['20000-50000 ','space']])
 check('store rejects non-canonical hop_ports ('+c[1]+')',index(store_result(store(7,with(hop,{hop_ports:c[0]}))),'param_invalid:hop_ports')==0,store_result(store(7,with(hop,{hop_ports:c[0]}))));
check('store rejects uppercase pin',store_result(store(7,with(hop,{pin_sha256:uc(PIN)})))=='param_invalid:pin_sha256');
check('store rejects non-string hop_ports',store_result(store(7,with(hop,{hop_ports:20000})))=='param_invalid:hop_ports');
check('store rejects insecure=true even with pin',index(store_result(store(7,with(hop,{insecure:true}))),'die:')==0);
let vl=row('vless://00000000-0000-4000-8000-000000000001@203.0.113.11:443?security=reality&pbk=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA&sni=example.com').node;
check('store rejects hop_ports on VLESS',vl!=null&&store_result(store(7,with(vl,{hop_ports:'20000-30000'})))=='combo_unsupported:hop_ports',vl?store_result(store(7,with(vl,{hop_ports:'20000-30000'}))):'no vless');
check('store rejects pin on VLESS',vl!=null&&store_result(store(7,with(vl,{pin_sha256:PIN})))=='combo_unsupported:pin_sha256');

// Form edits are normalized; empty values remove the field.
let u=update_result({hop_ports:' 20000:50000 ,443',pin_sha256:COLONS},plain);
check('form normalizes hop and pin',type(u)=='object'&&u.hop_ports=='443,20000-50000'&&u.pin_sha256==PIN,sprintf('%J',type(u)=='object'?[u.hop_ports,u.pin_sha256]:u));
u=update_result({hop_ports:'',pin_sha256:''},hop);
check('form clears hop and pin',type(u)=='object'&&!has(u,'hop_ports')&&!has(u,'pin_sha256'));
u=update_result({hop_ports:null,pin_sha256:null},hop);
check('form null clears hop and pin',type(u)=='object'&&!has(u,'hop_ports')&&!has(u,'pin_sha256'));
check('form rejects reversed range',update_result({hop_ports:'50000-20000'},plain)=='param_invalid:hop_ports');
check('form rejects bad pin',update_result({pin_sha256:'abc'},plain)=='param_invalid:pin_sha256');
u=update_result({name:'renamed'},hop);
check('form edit of other field keeps hop and pin',type(u)=='object'&&u.hop_ports=='20000-50000'&&u.pin_sha256==PIN);
u=vl?update_result({hop_ports:'20000-30000'},vl):null;
check('form hop on VLESS is refused when the store is saved',type(u)=='object'&&store_result(store(nodes.version_for(store(1,u)),u))=='combo_unsupported:hop_ports',sprintf('%J',u));
check('version_for picks 7 for hop/pin stores',nodes.version_for(store(1,hop))==7&&nodes.version_for(store(1,plain))<7);
check('format 7 returns to 6 when no node needs it',nodes.version_for(store(7,plain))==6&&nodes.version_for({version:7,default_node:'',nodes:[]})==6&&nodes.version_for(store(7,hop))==7);

// Rendering.
let o=nodes.render(hop),t=o.streamSettings.tlsSettings,m=o.streamSettings.finalmask;
check('render pin',t.pinnedPeerCertSha256==PIN&&!has(t,'allowInsecure'),sprintf('%J',t));
check('render udphop is the only and last udp mask',type(m?.udp)=='array'&&length(m.udp)==1&&m.udp[0].type=='udphop'&&length(keys(m))==1,sprintf('%J',m));
let s=m?.udp?.[0]?.settings||{};
check('render udphop settings',s.mode=='intervalLocal,intervalRemote'&&s.interval==30&&s.remotePorts=='20000-50000'&&!has(s,'remoteIPs')&&length(keys(s))==3,sprintf('%J',s));
check('render keeps server and main port',o.settings.address=='203.0.113.10'&&o.settings.port==443&&o.protocol=='hysteria');
let po=nodes.render(plain);
check('render plain has no finalmask or pin',!has(po.streamSettings,'finalmask')&&!has(po.streamSettings.tlsSettings,'pinnedPeerCertSha256'));
let po2=nodes.render(with(hop,{hop_ports:null}));
check('render pin without hop',!has(po2.streamSettings,'finalmask')&&po2.streamSettings.tlsSettings.pinnedPeerCertSha256==PIN);

// Identity: plain nodes keep the old keys; new keys only when set and different values differ.
let cp=nodes.connection(plain),ch=nodes.connection(hop);
check('plain identity has no new keys',!has(cp,'hop_ports')&&!has(cp,'pin_sha256'));
check('hop identity carries both keys',ch.hop_ports=='20000-50000'&&ch.pin_sha256==PIN);
check('hop change changes identity',nodes.canonical(ch)!=nodes.canonical(nodes.connection(with(hop,{hop_ports:'20000-40000'}))));
check('pin change changes identity',nodes.canonical(ch)!=nodes.canonical(nodes.connection(with(hop,{pin_sha256:replace(PIN,/^0/,'f')}))));
let cf=nodes.changed_fields(plain,hop);
check('changed fields name the new keys',index(cf,'hop_ports')>=0&&index(cf,'pin_sha256')>=0,sprintf('%J',cf));

// Chain endpoint: a hopping HY2 front covers its hop list on the same server.
let rear={id:'rear_a',name:'Rear A',protocol:'socks5',server:'203.0.113.10',port:30000,security:'none',transport:'raw',provider_udp:false};
function chain_store(front,rear_port){let f=with(front,{id:'front_a',name:'Front A'}),r=with(rear,{port:rear_port});return {version:7,default_node:'',nodes:[f,r,{id:'chain_a',name:'Chain A',protocol:'chain',front:'front_a',rear:'rear_a',udp:false}]};}
check('chain rejects rear inside front hop range',store_result(chain_store(hop,30000))=='param_invalid:rear',store_result(chain_store(hop,30000)));
check('chain accepts rear outside front hop range',store_result(chain_store(hop,1080))=='ok',store_result(chain_store(hop,1080)));
check('chain without hop keeps old rule',store_result(chain_store(plain,30000))=='ok'&&store_result(chain_store(plain,443))=='param_invalid:rear');

// Telemetry: sockets to any hop port are node traffic.
let ranges=monitor.hop_ranges(o),ctx={nodes:{'203.0.113.10:443':true},node_ranges:{'203.0.113.10':ranges},unresolved_node_endpoints:0};
check('monitor reads udphop ranges',length(ranges)==1&&ranges[0][0]==20000&&ranges[0][1]==50000,sprintf('%J',ranges));
let multi=monitor.hop_ranges(nodes.render(with(hop,{hop_ports:'443,20000-30000,40000'})));
check('monitor reads a multi-segment list',length(multi)==3&&multi[0][0]==443&&multi[0][1]==443&&multi[2][0]==40000&&multi[2][1]==40000,sprintf('%J',multi));
check('monitor classifies hop ports',monitor.category('203.0.113.10',20000,ctx)=='node_server'&&monitor.category('203.0.113.10',50000,ctx)=='node_server'&&monitor.category('203.0.113.10',443,ctx)=='node_server');
check('monitor leaves other ports alone',monitor.category('203.0.113.10',19999,ctx)!='node_server'&&monitor.category('203.0.113.11',20001,ctx)!='node_server');
check('monitor ignores malformed udphop',length(monitor.hop_ranges({streamSettings:{finalmask:{udp:[{type:'udphop',settings:{remotePorts:'9-1,0-5,70000'}}]}}}))==0);

printf('%s %d/%d\n',fails?'SOME CHECKS FAILED':'ALL PASS',count-fails,count);
exit(fails?1:0);
