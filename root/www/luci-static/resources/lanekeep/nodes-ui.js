'require baseclass';
'use strict';
'require lanekeep.copy as copy';
'require lanekeep.i18n as i18n';
var words={chainDefault:['两跳链不能设为默认节点','A chain can’t be the default node'],exitDefault:['后置节点不能设为默认节点','An exit hop can’t be the default node'],trialDefault:['实验性节点不能设为默认节点','An experimental node can’t be the default node'],
 nodes:['节点','Nodes'],used:['用于','Used by'],lastTest:['最近测试','Last test'],unreachable:['失败','Failed'],reachable:['可用','Reachable'],notTested:['未测试','Not tested'],empty:['还没有节点','No nodes yet'],emptyHint:['新增节点，或从链接和订阅导入。','Add a node, or import from a link or subscription.'],defaultTitle:['把「{name}」设为默认节点？','Set “{name}” as the default node?'],defaultNode:['默认节点','Default node'],exitIP:['出口 IP','Exit IP'],unavailableDefault:['此节点不能设为默认','This node can’t be the default'],noFront:['没有可用的前置节点','No compatible entry hop'],testUnavailable:['此节点暂不支持测试','Testing is unavailable for this node'],noCache:['请先刷新订阅','Refresh the subscription first'],notReady:['此功能还在开发中','This feature is still in development'],name:['名称','Name'],protocol:['协议','Protocol'],combo:['组合','Combination'],advanced:['高级设置','Advanced'],noUsage:['未使用','Not in use'],upload:['上传','Upload'],download:['下载','Download'],total:['总量','Total'],expire:['到期','Expires'],bytes:['字节','bytes'],subscription:['订阅','Subscription'],unknown:['未知','Unknown'],experimental:['实验性','Experimental'],verified:['已验证','Verified'],pending:['待验证','Pending verification'],development:['开发中','In development'],keepSecret:['留空则不改','Leave blank to keep'],server:['服务器','Server'],port:['端口','Port'],more:['更多操作','More actions']};
var fields={id:['节点编号','Node ID'],name:['名称','Name'],protocol:['协议','Protocol'],server:['服务器','Server'],port:['端口','Port'],security:['安全方式','Security'],transport:['传输','Transport'],uuid:['UUID','UUID'],password:['密码 / 密钥','Password / key'],username:['用户名','Username'],sni:['SNI','SNI'],flow:['Flow','Flow'],fingerprint:['TLS 指纹','TLS fingerprint'],public_key:['REALITY 公钥','REALITY public key'],short_id:['Short ID','Short ID'],mldsa65:['ML-DSA-65 验证值','ML-DSA-65 verification'],spiderX:['REALITY 路径','REALITY path'],import_hints:['ML-KEM 兼容','ML-KEM compatibility'],alpn:['ALPN（逗号分隔）','ALPN (comma-separated)'],insecure:['跳过证书验证','Skip certificate verification'],hop_ports:['端口跳跃','Port hopping'],pin_sha256:['证书指纹','Certificate pin'],path:['传输路径','Transport path'],host:['HTTP Host','HTTP Host'],service_name:['gRPC serviceName','gRPC serviceName'],authority:['gRPC authority','gRPC authority'],mode:['传输模式','Transport mode'],method:['加密方法','Cipher'],scy:['VMess 加密','VMess encryption'],aid:['VMess alterId','VMess alterId'],provider_udp:['服务商支持 UDP','Provider supports UDP']};
function pair(v){return v[i18n.language==='en'?1:0];}
// Decorative icons share one SVG contract; text labels remain the accessible names.
function icon(name){
 var shield='M12 3 4 6v5c0 5 3.6 8.2 8 10 4.4-1.8 8-5 8-10V6l-8-3Z';
 var shapes={
  'shield-check':[['path',{d:shield}],['path',{d:'m8.5 11.5 2.5 2.5 4.5-5'}]],
  'shield-alert':[['path',{d:shield}],['path',{d:'M12 8v5m0 3h.01'}]],
  'shield-question':[['path',{d:shield}],['path',{d:'M9.8 9a2.3 2.3 0 0 1 4.4 1c0 1.4-2.2 1.6-2.2 3m0 3h.01'}]],
  server:[['rect',{x:3,y:3,width:18,height:7,rx:2}],['rect',{x:3,y:14,width:18,height:7,rx:2}],['path',{d:'M7 6.5h.01M7 17.5h.01M11 6.5h6M11 17.5h6'}]],
  chain:[['path',{d:'M10 13a5 5 0 0 0 7.1 0l3-3a5 5 0 0 0-7.1-7.1l-1.7 1.7M14 11a5 5 0 0 0-7.1 0l-3 3a5 5 0 0 0 7.1 7.1l1.7-1.7'}]],
  rss:[['path',{d:'M4 4a16 16 0 0 1 16 16M4 10a10 10 0 0 1 10 10'}],['circle',{cx:5,cy:19,r:1}]],
  more:[['circle',{cx:5,cy:12,r:1}],['circle',{cx:12,cy:12,r:1}],['circle',{cx:19,cy:12,r:1}]],
  'chevron-down':[['path',{d:'m6 9 6 6 6-6'}]],
  'chevron-right':[['path',{d:'m9 6 6 6-6 6'}]],
  'arrow-right':[['path',{d:'M4 12h16m-6-6 6 6-6 6'}]],
  'circle-check':[['circle',{cx:12,cy:12,r:9}],['path',{d:'m8 12 2.5 2.5L16 9'}]],
  'circle-x':[['circle',{cx:12,cy:12,r:9}],['path',{d:'m9 9 6 6m0-6-6 6'}]],
  circle:[['circle',{cx:12,cy:12,r:9}]]
 };
 var ns='http://www.w3.org/2000/svg',svg=document.createElementNS(ns,'svg');
 var attrs={viewBox:'0 0 24 24',width:'24',height:'24',fill:'none',stroke:'currentColor','stroke-width':'2','stroke-linecap':'round','stroke-linejoin':'round','aria-hidden':'true',focusable:'false','class':'lk-icon','data-icon':name};
 Object.keys(attrs).forEach(function(k){svg.setAttribute(k,attrs[k]);});
 (shapes[name]||[]).forEach(function(shape){var child=document.createElementNS(ns,shape[0]);Object.keys(shape[1]).forEach(function(k){child.setAttribute(k,shape[1][k]);});svg.appendChild(child);});
 return svg;
}
function word(key,params){return pair(words[key]||[key,key]).replace(/\{(\w+)\}/g,function(_,k){return params&&params[k]!=null?params[k]:'—';});}
function fieldName(key){return pair(fields[key]||[key,key]);}
function protocol(key){return {vless:'VLESS',vmess:'VMess',trojan:'Trojan',shadowsocks:'Shadowsocks',hysteria2:'HY2',socks5:'SOCKS5',http:'HTTP CONNECT',chain:copy.t('N-19')}[key]||key;}
function comboName(c){var transports={raw:'TCP',tcp:'TCP',ws:'WebSocket',httpupgrade:'HTTPUpgrade',grpc:'gRPC',xhttp:'XHTTP',quic:'QUIC'},securities={none:i18n.language==='en'?'No TLS':'无 TLS',tls:'TLS',reality:'REALITY'};return (transports[c.transport]||String(c.transport).toUpperCase())+' / '+(securities[c.security]||c.security)+(c.method?' / '+c.method:'');}
function badge(label,kind){return E('span',{'class':'lk-tag '+(kind?'lk-tag-'+kind:'')},label);}
function p(text){return E('p',{},text);}
function field(key,control,hint){var label=E('label',{'class':'lk-field'},[E('span',{'class':'lk-field-label'},fieldName(key)),control]);if(hint)label.appendChild(E('small',{},hint));label.dataset.field=key;return label;}
function details(title,children){return E('details',{'class':'lk-disclosure'},[E('summary',{},title),E('div',{'class':'lk-disclosure-body'},children)]);}
function menu(items){var popup=E('div',{'class':'lk-menu-items',role:'menu'}),trigger=E('button',{type:'button','class':'cbi-button lk-more','aria-label':copy.t('N-21'),'aria-haspopup':'menu','aria-expanded':'false'},icon('more')),root=E('div',{'class':'lk-more-menu'},[trigger,popup]);popup.hidden=true;
 function close(){popup.hidden=true;trigger.setAttribute('aria-expanded','false');}
 items.forEach(function(item){var b=item.button||item;b.setAttribute('role','menuitem');if(b.disabled&&item.reason)b.setAttribute('aria-describedby','lk-reason-'+(++menu.serial));var reason=b.disabled&&item.reason?E('small',{id:b.getAttribute('aria-describedby')},item.reason):null;popup.appendChild(E('div',{'class':'lk-menu-item'},[b].concat(reason?[reason]:[])));b.addEventListener('click',close);});
 trigger.addEventListener('click',function(){var open=popup.hidden;document.querySelectorAll('.lk-more-menu').forEach(function(n){if(n!==root&&n._close)n._close();});popup.hidden=!open;trigger.setAttribute('aria-expanded',String(open));if(open)popup.querySelector('button:not(:disabled)')?.focus();});root._close=close;
 root.addEventListener('keydown',function(e){if(e.key==='Escape'){close();trigger.focus();e.stopPropagation();}if(['ArrowDown','ArrowUp','Home','End'].indexOf(e.key)>=0){e.preventDefault();var a=Array.from(popup.querySelectorAll('button:not(:disabled)')),i=a.indexOf(document.activeElement);if(!a.length)return;a[e.key==='Home'?0:e.key==='End'?a.length-1:(i+(e.key==='ArrowUp'?-1:1)+a.length)%a.length].focus();}});
 return root;
}menu.serial=0;
document.addEventListener('click',function(e){document.querySelectorAll('.lk-more-menu').forEach(function(n){if(!n.contains(e.target)&&n._close)n._close();});});
function comboStatus(c){return copy.t(c.legacy?'F-1846189b36':c.status==='trial'?'F-5a654739d9':c.status==='verified'?'F-1f2cd95728':c.status==='loopback'?'F-1eba822fbb':'F-82c36b5059').replace(/^[·（(\s]+|[）)\s]+$/g,'');}
function comboSelect(select,list){var box=E('div',{'class':'lk-combo-picker'}),label=E('button',{type:'button','class':'cbi-input-select','aria-haspopup':'listbox','aria-expanded':'false'}),options=E('div',{'class':'lk-combo-options',role:'listbox'});select.hidden=true;options.hidden=true;label.setAttribute('aria-label',word('combo'));
 function show(){var c=list.find(function(x){return x.id===select.value;});label.replaceChildren(E('span',{},comboName(c)));label.appendChild(badge(comboStatus(c),c.status==='trial'?'warning':''));label.appendChild(icon('chevron-down'));options.querySelectorAll('[role=option]').forEach(function(b){b.setAttribute('aria-selected',String(b.dataset.value===select.value));});}
 list.forEach(function(c){var b=E('button',{type:'button',role:'option','data-value':c.id,click:function(){select.value=c.id;select.dispatchEvent(new Event('change'));options.hidden=true;label.setAttribute('aria-expanded','false');show();label.focus();}},[E('span',{},comboName(c))]);b.appendChild(badge(comboStatus(c),c.status==='trial'?'warning':''));options.appendChild(b);});
 label.addEventListener('click',function(){options.hidden=!options.hidden;label.setAttribute('aria-expanded',String(!options.hidden));if(!options.hidden)(options.querySelector('[aria-selected=true]')||options.firstChild).focus();});box.addEventListener('keydown',function(e){if(e.key==='Escape'){options.hidden=true;label.setAttribute('aria-expanded','false');label.focus();e.stopPropagation();}if(['ArrowDown','ArrowUp','Home','End'].indexOf(e.key)>=0){e.preventDefault();var a=Array.from(options.children),i=a.indexOf(document.activeElement);options.hidden=false;label.setAttribute('aria-expanded','true');a[e.key==='Home'?0:e.key==='End'?a.length-1:(i+(e.key==='ArrowUp'?-1:1)+a.length)%a.length].focus();}});show();box.append(select,label,options);return box;}
function tabs(select){select.hidden=true;var tabs=E('div',{'class':'lk-import-tabs',role:'tablist'});Array.from(select.options).forEach(function(o){var b=E('button',{type:'button',role:'tab','aria-selected':String(o.value===select.value),click:function(){select.value=o.value;select.dispatchEvent(new Event('change'));tabs.querySelectorAll('button').forEach(function(x){x.setAttribute('aria-selected',String(x===b));});}},o.textContent);tabs.appendChild(b);});return E('div',{},[select,tabs]);}
function testState(result){return E('strong',{'class':'lk-test-state '+(!result?'lk-state-unknown':result.ok?'lk-state-ok':'lk-state-failed')},[icon(!result?'circle':result.ok?'circle-check':'circle-x'),word(!result?'notTested':result.ok?'reachable':'unreachable')]);}
function testResult(result,text){return E('div',{'class':'lk-test-result'},[testState(result),p(result?text:"")]);}
function help(){var groups=[['N-12',['N-13','F-6fd27af62b','F-0454c8ab2f']],['N-14',['F-88e42ddebe']],['N-15',['F-6329d6fd7f','F-6ae745f359','F-e4cf0b26e1']],['N-16',['F-8a3ce01e36','F-4176fe2965','N-17']]];return E('section',{'class':'lk-info-panel',hidden:'',id:'lk-node-help'},[E('div',{'class':'lk-section-heading'},[E('h3',{},copy.t('N-10')),E('button',{type:'button','class':'cbi-button',click:toggleHelp},copy.t('N-11'))]),E('div',{'class':'lk-info-grid'},groups.map(function(g){return E('div',{},[E('h4',{},copy.t(g[0]))].concat(g[1].map(function(id){return p(copy.t(id));})));}))]);}
function toggleHelp(){var box=document.getElementById('lk-node-help');if(!box)return;box.hidden=!box.hidden;document.querySelectorAll('[aria-controls=lk-node-help]').forEach(function(b){b.setAttribute('aria-expanded',String(!box.hidden));});}
function openHelp(){var box=document.getElementById('lk-node-help');if(box&&box.hidden)toggleHelp();}
function helpButton(label,openOnly){return E('button',{type:'button','class':'cbi-button','aria-controls':'lk-node-help','aria-expanded':'false',click:openOnly?openHelp:toggleHelp},label);}
function gate(data){var g=data.gate||{},known=g.fresh!==false,state=known&&g.state==='OPEN'?'standby':known&&g.state==='CLOSED'?'triggered':'unknown',name=(data.nodes||[]).find(function(n){return n.id===data.default_node;})?.name||word('unknown');var message=state==='triggered'?copy.t('N-06',{name:name}):state==='standby'?copy.t('F-b6bd4a0237').replace('演示节点 01',name).replace('Demo node 01',name):copy.t('N-08');
 if(state==='triggered')message+=' '+pair(['可以在下方把另一个可用节点设为默认。','You can make another reachable node the default below.']);
 var status=badge(copy.t(state==='standby'?'N-04':state==='triggered'?'N-05':'N-07'));
 if(state==='standby')status.prepend(E('span',{'class':'lk-status-dot','aria-hidden':'true'}));
 var more=helpButton(copy.t('N-09'),true);more.classList.add('lk-gate-link');more.appendChild(icon('chevron-right'));
 return E('section',{'class':'lk-gate lk-gate-'+state,'data-gate-state':state},[E('span',{'class':'lk-row-icon','aria-hidden':'true'},icon(state==='standby'?'shield-check':state==='triggered'?'shield-alert':'shield-question')),E('div',{'class':'lk-gate-copy'},[E('div',{'class':'lk-name-line'},[E('strong',{'class':'lk-gate-title'},copy.t('N-03')),status]),p(message)]),more]);}
function comparison(oldName,newName,from,to){return E('div',{'class':'lk-comparison'},[[word('defaultNode'),oldName,newName],[word('exitIP'),from,to]].map(function(row){return E('div',{},[E('span',{},row[0]),E('strong',{},row[1]),icon('arrow-right'),E('strong',{},row[2])]);}));}
function bytes(value){var n=Number(value);if(value==null||!isFinite(n)||n<0)return '—';var units=['B','KB','MB','GB','TB'],i=0;while(n>=1024&&i<units.length-1){n/=1024;i++;}return n.toLocaleString(i18n.language==='en'?'en-US':'zh-CN',{maximumFractionDigits:2})+' '+units[i];}
var exported = {bytes:bytes,icon:icon,word:word,fieldName:fieldName,protocol:protocol,comboName:comboName,badge:badge,field:field,details:details,menu:menu,comboSelect:comboSelect,tabs:tabs,testResult:testResult,testState:testState,help:help,helpButton:helpButton,gate:gate,comparison:comparison};
// LuCI instantiates modules; keep dictionary keys as own enumerable properties.
return baseclass.extend({ __init__: function() { Object.assign(this, exported); } });
