'use strict';
// All calls terminate here. This module contains no router address or network RPC.
const scenario=new URLSearchParams(location.search).get('scenario')||'normal';
const english=new URLSearchParams(location.search).get('lang')==='en';
const tr=(zh,en)=>english?en:zh;
const bad=scenario==='error',empty=scenario==='empty',long=scenario==='long',many=scenario==='many';
const now=100000,wall=Math.floor(Date.now()/1000),revision='demo-revision-1',stamp=new Date(Date.now()-7200000).toISOString();
const clone=value=>JSON.parse(JSON.stringify(value));
const longName=tr('演示名称特别长用于检查卡片换行与弹窗边界ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789','AnExtremelyLongDemoNodeNameForTestingWrappingABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789');
const test={ok:true,measurement_version:3,elapsed_ms:186,connect_ms:742,latency_basis:'warm',ip:'203.0.113.50',country:'ZZ',time_utc:stamp};
let catalog;
const nodes=Array.from({length:empty?0:many?18:6},(_,i)=>({id:'demo_'+(i+1),name:long?longName+'_'+(i+1):tr('演示节点 ','Demo node ')+String(i+1).padStart(2,'0'),protocol:i===4?'socks5':'vless',combo:i===4?'socks5-plain-tcp':'vless-reality-raw',model_version:3,extended_model:true,server:'198.51.100.'+(10+i),port:443,security:'reality',transport:'raw',flow:'xtls-rprx-vision',role:i===4?'rear_only':'normal',provider_udp:i===4,capability_status:i===4?'trial':'verified',default_allowed:i!==4,route_allowed:true,test_allowed:true,chain_front_allowed:i!==4,chain_rear_allowed:i===4,default:i===0,references:i===0?[tr('常规模式','Standard mode')]:i===5?[tr('全局模式','Global mode')]:[],last_test:bad&&i===1?{ok:false,status:'timeout',message:'演示错误：测试超时',time_utc:stamp}:i<2?test:null}));
if(scenario==='legacy'&&nodes[1])nodes[1].extended_model=false;
// Legacy HY2 node with port hopping and a certificate pin (synthetic values only).
if(scenario==='hy2'&&nodes[1]){['security','transport','flow'].forEach(k=>delete nodes[1][k]);Object.assign(nodes[1],{protocol:'hysteria2',combo:'hysteria2-tls',extended_model:false,model_version:7,sni:'example.com',password:'********',alpn:[],insecure:false,hop_ports:'20000-50000',pin_sha256:'0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',capability_status:'legacy_preserved'});}
if(nodes.length>2)nodes[2].source={id:'demo_source',item_id:'item_1'};
if(scenario==='failed'&&nodes[1])nodes[1].last_test={ok:false,status:'timeout',message:'演示错误：测试超时',time_utc:stamp};
if(scenario==='experimental'&&nodes[1])Object.assign(nodes[1],{capability_status:'trial',default_allowed:false});
if(scenario==='names'){nodes[0].name='自定义名称 A';nodes[1].name='全局 / 增强 / 按需';nodes[0].references=[{type:'group_proxy',group:'standard',label:'常规 / 组代理节点'}];}
 if(scenario==='disabled'&&nodes[1])Object.assign(nodes[1],{test_allowed:false,default_allowed:false,references:['demo_chain']});
if(nodes.length>5)Object.assign(nodes[5],{protocol:'chain',name:long?longName+tr('_两跳链','_chain'):tr('演示两跳链','Demo chain'),front:'demo_1',rear:'demo_5',udp:false,default_allowed:false,capability_status:'trial',composition:{front:{name:nodes[0].name},rear:{name:nodes[4].name}}});
const devices=empty?[]:['global','standard','standard','enhanced','ondemand'].map((g,i)=>({name:scenario==='names'?['自定义名称 A','Demo host B','增强','按需','常规 / 全局 · 常规'][i]:long?longName+'_设备_'+i:tr('演示设备 ','Demo device ')+String.fromCharCode(65+i),ip:'192.0.2.'+[105,102,104,101,103][i],group:g,online:true,unstable:bad&&i===0,rule_ok:!bad||i!==0,rule_text:g==='standard'?'国内直连，其余走本组代理节点':'按本组当前规则处理'}));
const rules=empty?[]:['standard','global','enhanced','ondemand'].flatMap((group,i)=>[
 {id:'ad_'+group,group,type:'geosite',value:'category-ads-all',action:'block',enabled:'1',note:'广告屏蔽'},
 {id:'demo_rule_'+i,group,type:'domain',value:'example.com',action:'proxy',enabled:'1',note:long?longName:'演示规则',positions:[14+i*2]},
 // Documentation ranges: display-only demo data; the router would reject them.
 {id:'demo_ip_'+i,group,type:'ip',value:i%2?'203.0.113.0/24':'198.51.100.7',action:i===2?'node':i===3?'block':'direct',node:i===2?'demo_2':'',enabled:'1',note:tr('演示 IP 规则：这是一段比较长的备注，用来检查单行备注框','Demo IP rule with a long note to check the single-line note field'),positions:[15+i*2]}
]).concat(empty?[]:['global','enhanced'].map((group,i)=>({id:'demo_entry_'+group,group,type:'dedicated',value:String(10811+i),action:i?'direct':'proxy',enabled:'1',note:'',positions:[30+i]})));
const builtin=Object.fromEntries(['standard','global','enhanced','ondemand'].map(g=>[g,[
 {position:1,kind:'fixed',text:'TCP/UDP 目标端口 53 → 共享DNS处理'},{position:2,kind:'fixed',text:'目标端口 853 → 阻断'},{position:13,kind:'fixed',text:'私有地址分类 → 直连'},
 {position:null,kind:'user_slot',text:'我的规则插入位置'+(g==='ondemand'?'；代理域名和IP自动先附加相同目标的UDP443保护':'')},
 {position:40,kind:'fixed',text:'国外分类 → 代理'},{position:41,kind:'fixed',text:'国内分类 → 直连'},{position:42,kind:'fallback',text:'TCP/UDP → 兜底出口'}]]));
function status(){return {ok:true,lifecycle:{enabled:true},lan:{address:'192.0.2.1',subnet:'192.0.2.0/24'},revision,current_version:'demo-version-3',core:{running:!bad},gate:{state:bad||scenario==='triggered'?'CLOSED':scenario==='unknown'?'UNKNOWN':'OPEN',fresh:scenario!=='unknown'},default_node:nodes[0]||{},last_apply:{time_utc:stamp,result:bad?'rolled_back':'applied'},config:{revision,members:{global:empty?[]:['192.0.2.105'],enhanced:empty?[]:['192.0.2.101'],ondemand:empty?[]:['192.0.2.103']},rules,group_nodes:{standard:'',global:'',enhanced:'',ondemand:''},fallbacks:Object.fromEntries(['standard','global','enhanced','ondemand'].map(g=>[g,{action:'proxy',node:''}])),real_dns:empty?[]:['example.com']},builtin,rule_types:['domain','full','keyword','ip','dedicated','geosite'],devices:{static:devices,dynamic:empty?[]:[{name:long?longName:'演示访客设备',ip:'192.0.2.30'}],dhcp_path:['admin','network','dhcp']},counts:{standard:empty?0:1,global:empty?0:1,enhanced:empty?0:1,ondemand:empty?0:1},warnings:bad?[{message:'演示异常：一个设备的分组与预期不一致'}]:[],home:{mono:now,devices,rules_checked:!bad,rules_message:bad?'演示异常：规则需核对':'配置检查通过',privacy_ok:true,supervisor:{launches:1},adblocking:{configuration_verified:true,groups:Object.fromEntries(['standard','global','enhanced','ondemand'].map(g=>[g,{verified:true,enabled:true}]))},domestic:{available:true,ok:true,mono:now,wall}}};}
const metricSpecs=[['probe_ms','代理线路响应','ms',160],['tcp_retrans','网络重传','次/s',.2],['gate','保护开关','',bad?0:1],['wan_up_state','外网接口','',1],['cpu','处理器','%',bad?92:12],['mem_used','已用内存','MiB',434],['conntrack','连接数','条',281],['core_fd','代理程序句柄','个',237],['core_uptime','代理程序运行时间','s',10000],['mem_available','可用内存','MiB',bad?75:3500],['probe_ok','探针成功','轮/s',bad?0:.5],['probe_fail','探针失败','轮/s',bad?.5:0],['wan_down','外网下载','B/s',1200000],['wan_up','外网上传','B/s',170000],['group_standard_down','常规下载','B/s',800000],['group_enhanced_down','增强下载','B/s',400000],['out_demo_1_down','演示节点 01 下载','B/s',900000],['nft_udp443','UDP 443','包/s',2],['tcp_timeout','TCP 超时','次/s',0],['recv_tcp_12345','常规 TCP 队列','条',0]];
function telemetry(args){
 const window=args[0]||'30m',snapshot=args[1]||'none',span=window==='24h'?86400:window==='6h'?21600:1800;
 const defs=metricSpecs.map(([id,label,unit])=>({id,label,unit,source:'demo'}));
 const values=metricSpecs.map(x=>x[3]);
 const rows=empty?[]:Array.from({length:120},(_,i)=>({mono:now-span+(i+1)*span/120,wall:wall-span+(i+1)*span/120,values:values.map((v,j)=>['gate','wan_up_state','core_uptime'].includes(defs[j].id)?v:Math.max(0,v*(1+.12*Math.sin(i*.3+j))))}));
 const events=bad?[{kind:'gate_closed',mono:now-100,wall:wall-100}]:[];
 return {ok:true,window,snapshot,read_id:'demo-read',page:0,page_count:1,total_rows:rows.length,total_probes:0,total_events:events.length,rows,probes:[],events,now,span,home:status().home,latest:{mono:now,wall,default_node:nodes[0]?.id||'',fd_limit:16384,defs,row:{values:empty?values.map(()=>null):values,sources:{demo:now}},issues:bad?[{message:'演示异常：CPU 占用偏高',since:now-90}]:[],scope:'演示数据：聚合指标',restarts:0,snapshots:[],unavailable:['阻断出口字节数'],health:{storage_ok:true,days:empty?[]:[{date:'2026-11-12',closed:true,result:bad?'issues':'normal',observed:86400,start:wall-86400,end:wall,counts:bad?{gate_closed:1}:{},events:[]}]},monitor:{storage_ok:true,days:empty?[]:[{date:'2026-11-12',fd_peak:310,fd_peak_at:wall-1800,covered_seconds:86400,gap_count:0,first:wall-86400,last:wall}],snapshots:[]}}};
}
const subscriptions=()=>({ok:true,revision,sources:empty?[]:[{id:'demo_source',name:scenario==='names'?'全局 常规的订阅':long?longName+tr('_订阅','_subscription'):tr('演示订阅','Demo subscription'),url_masked:'https://example.com/subscription',channel:'proxy',revision,cache_ready:!bad,cache_version:'demo-cache',cache_message:bad?'演示错误：刷新失败，保留旧缓存':tr('缓存可用','Cache ready'),fetched_at:wall-300,count:6,usage:{upload:1024,download:1048576,total:1073741824}}]});
const calls=[];window.previewCalls=calls;
window.previewReady=fetch('/data/capabilities.json').then(r=>r.json()).then(value=>{catalog=value;});
window.previewRPC=async function(object,method,args=[]){
 await window.previewReady;calls.push({object,method,args:clone(args)});
 if(scenario==='rpc-once'&&calls.filter(c=>c.object===object&&c.method===method).length===1)return {ok:false,code:'demo_transient',message:'演示首次读取失败'};
 if(scenario==='rpc-error')return {ok:false,code:'demo_unavailable',message:'演示错误：RPC 暂时不可用'};
 if(object==='lanekeep_telemetry'){
  if(method==='read_page')return clone(telemetry(args));
  if(method==='mark')return {ok:!bad,message:bad?'演示错误：标记未完成':'演示标记已记录（刷新复原）'};
 }
 if(object!=='lanekeep')return {ok:false,code:'demo_unknown_object',message:'预览未定义此 RPC'};
 if(method==='status')return clone(args[0]?{...status(),job:{state:'done',result:'applied',message:tr('演示应用已完成','Demo changes applied')}}:status());
 if(method==='nodes')return clone({ok:true,lifecycle:{enabled:!empty},nodes,total:nodes.length,offset:0,next:null,revision,uci_revision:revision,gate:status().gate,default_node:nodes[0]?.id||'',runtime_capacity:{message:'演示统计容量 '+(18+nodes.length*2)+' / 96',uncollected:[],uncollected_count:0}});
 if(method==='capabilities')return clone({ok:true,capabilities:catalog});
 if(method==='sub_list')return clone(subscriptions());
 if(method==='versions')return clone({ok:true,versions:empty?[]:[{id:'demo-version-3',kind:'applied',time_utc:stamp,summary:'演示：调整设备分组',result:'members_applied',same_current:true},{id:'demo-version-2',kind:bad?'failed':'applied',time_utc:'2026-11-13T18:30:00Z',summary:long?longName:'演示：更新规则',result:bad?'rolled_back':'applied',same_current:false}]});
 if(method==='node_test'||method==='exit_check')return clone(bad||scenario==='failed'?{ok:false,status:'timeout',message:'演示错误：连接测试超时'}:Object.assign({},test,{time_utc:new Date().toISOString(),verification_receipt:scenario==='verification'?'demo-receipt':undefined}));
 if(method==='trial_confirm')return {ok:true,message:'仅演示确认'};
 if(method==='apply')return bad?{ok:false,message:'演示错误：应用被拒绝'}:{ok:true,job_id:'demo-job',job:{id:'demo-job',state:'done',result:'applied'}};
 if(['validate','node_validate','rollback'].includes(method)){
  let draft={};try{draft=JSON.parse(args[0]||'{}');}catch{}
  if(bad)return {ok:false,message:'演示错误：校验未通过',errors:[{field:'node.name',message:'演示错误：名称或参数不符合要求'}]};
  if(['import_preview','source_preview','preview_page'].includes(draft.operation))return {ok:true,preview_id:'demo-preview',cache_version:'demo-cache',total:2,offset:0,next:null,matching_item_ids:['item_1','item_2'],items:[{item_id:'item_1',line:1,name:tr('演示导入节点 01','Imported demo node 01'),protocol:'vless',selectable:true,selected_default:true,status:'new',message:tr('可导入','Ready to import')},{item_id:'item_2',line:2,name:tr('演示导入节点 02','Imported demo node 02'),protocol:'vless',selectable:true,selected_default:true,status:'new',message:tr('可导入','Ready to import')}]};
  if(draft.node&&!draft.node.name&&draft.node.source!==null)return {ok:false,errors:[{field:'node.name',message:'请填写演示节点名称'}]};
  return {ok:true,draft_id:'demo-draft',change_kind:draft.operation==='default'?'rules':'metadata',impact:{restart_required:draft.operation==='default'},summary:{node_changes:[{name:draft.node?.name||nodes.find(n=>n.id===draft.id)?.name||tr('所选节点','Selected nodes'),action:draft.operation}]},trial_required:draft.node?.protocol==='chain'||['socks5','http'].includes(draft.node?.protocol),expires_in:1200};
 }
 if(method==='sub_diff')return {ok:true,total:1,offset:0,next:null,items:[{item_id:'item_1',name:tr('演示订阅节点','Demo subscription node'),selectable:true,status:'new',message:tr('新增','New'),targets:[]}],matching_item_ids:['item_1'],nodes_revision:revision,caps_revision:catalog.revision};
 if(method==='sub_save'||method==='sub_refresh')return {ok:!bad,message:bad?'演示错误：订阅操作失败':'演示订阅操作完成'};
 return {ok:false,code:'demo_unmapped',message:'预览未定义此 RPC'};
};
