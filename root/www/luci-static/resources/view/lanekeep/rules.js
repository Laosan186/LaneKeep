'require lanekeep.foundation as foundation';
'require lanekeep.i18n as lk';
"use strict";
'require view';
'require lanekeep as panel';
'require view.lanekeep.chain-form as chainForm';

return foundation.view(view,{
 load:function() { return Promise.all([panel.loadStatus(),panel.rpc.nodes()]).then(function(results) { if (!results[1].ok) throw new Error('nodes_unavailable'); results[0].node_catalog=results[1]; return results[0]; }).catch(function() { return null; }); },
 render:function(data) {
  if (!data) return panel.loadFailure();
  var config = data.config || {}, rules = JSON.parse(JSON.stringify(config.rules || []));
  var groupNodes=Object.assign({standard:'',global:'',enhanced:'',ondemand:''},config.group_nodes || {});
  var groupBox=E('div');
  var fallbacks=JSON.parse(JSON.stringify(config.fallbacks || {})), realDns=(config.real_dns || []).slice();
  var dnsInput=E('textarea',{'class':'cbi-input-textarea',rows:7,spellcheck:'false',input:function(){realDns=this.value.split(/\r?\n/).map(function(x){return x.trim();}).filter(Boolean);}},realDns.join('\n'));
  var livePositions = data.rule_positions || {}, nodeCatalog=data.node_catalog || {}, nodeOptions={};
  (nodeCatalog.nodes || []).forEach(function(n) { if(n.route_allowed===true && n.role!=='rear_only')nodeOptions[n.id]=n.name+(n.protocol==='chain'?(n.udp?lk.text("（链 · TCP/UDP）"):lk.text("（链 · 仅 TCP）")):''); });
  rules.forEach(function(rule) { if (Array.isArray(rule.positions)) livePositions[rule.id] = rule.positions; delete rule.positions; });
  var currentGroup = 'standard', fields = {}, activeTabs = {}, fieldsBox = E('div'), builtinBox = E('div');
  var errorBox = E('div', {'class':'alert-message warning',role:'alert',hidden:'','data-lk-hidden-origin':'true','aria-hidden':'true'});
  var typeOptions = {domain:lk.text("域名及子域"),full:lk.text("完整域名"),keyword:lk.text("关键词"),dedicated:lk.text("专用入口"),geosite:lk.text("广告域名库")};
  var saved = {}; (config.rules || []).forEach(function(r){saved[r.id]=r;});
  function nextPort() { for(var p=10811;p<=10860;p++)if(!rules.some(function(r){return r.type==='dedicated' && r.value===String(p);}))return String(p);return null; }
  function changesEntry(rule,fn) { if(rule.type==='dedicated' && saved[rule.id] && saved[rule.id].enabled==='1')panel.entryWarning(fn);else fn(); }
  var generated = 0;
  function field(index, key, input, label) {
   return panel.bindField(fields, 'rules.' + index + '.' + key, input, panel.labels[rules[index].group] + lk.text("第 ") + (rules.filter(function(r, i) { return i <= index && r.group === rules[index].group; }).length) + lk.text(" 条 · ") + label);
  }
  function deleteRule(index) {
   changesEntry(rules[index],function(){rules.splice(index,1); renderGroup();});
  }
  function swap(index, direction) {
   for (var i = index + direction; i >= 0 && i < rules.length; i += direction) {
    if (rules[index].type !== 'dedicated' && rules[i].type !== 'dedicated' && rules[i].group === currentGroup) { var tmp = rules[i]; rules[i] = rules[index]; rules[index] = tmp; break; }
   }
   renderGroup();
  }
  function renderGroup() {
   fields = {};
   panel.bindField(fields,'settings',groupBox,lk.text("组代理节点 / 兜底出口 / 不使用假 IP 的域名"));
   var groupOptions=Object.assign({'':lk.text("跟随全局默认节点")},nodeOptions),selected=groupNodes[currentGroup];
   if(selected && !groupOptions[selected])groupOptions[selected]=lk.text("已保存节点 ")+selected+lk.text("（当前不可用，请重新选择）");
   var selector=panel.bindField(fields,'group_nodes.'+currentGroup,panel.select(groupOptions,selected,function(v){groupNodes[currentGroup]=v;renderGroup();}),panel.labels[currentGroup]+lk.text("组代理节点"));
   var selectedNode=(nodeCatalog.nodes || []).filter(function(n){return n.id===selected;})[0];
   groupBox.replaceChildren(E('h3',{},panel.labels[currentGroup]+lk.text("组 · 代理节点")),selector,
    panel.message(lk.text("影响本组内置代理分类、普通规则中的“本组代理节点”，以及选择“本组代理节点”的最终兜底。留空时沿用全局默认；直连、屏蔽、明确指定节点和专用入口各自保持。")),
    panel.message(lk.text("DNS仍沿用原解析路径；默认节点健康门控仍约束所有代理出口。选择后须校验，再确认应用；仅切换选项不会生效。")));
   if(selectedNode && selectedNode.protocol==='chain' && !selectedNode.udp)groupBox.appendChild(panel.notice(lk.text("此链仅承载命中它的 TCP；对应 UDP 会被阻断，不会自动改走默认节点或直连。")));
   if(currentGroup==='ondemand' && selectedNode && selectedNode.protocol==='chain')groupBox.appendChild(panel.message(lk.text("按需的 Google / Netflix IP 分类也跟随此链；应用时校验原分类库，数据变化时拒绝应用并要求重新核对。")));
   panel.errors(errorBox, [], fields);
   Object.keys(activeTabs).forEach(function(group) {
    activeTabs[group].className = group === currentGroup ? 'cbi-tab' : 'cbi-tab-disabled';
    activeTabs[group].firstChild.setAttribute('aria-selected', String(group === currentGroup));
   });
   var indices = [];
   rules.forEach(function(rule,index) { if (rule.group === currentGroup) indices.push(index); });
   indices.sort(function(a,b) { return (rules[a].type==='dedicated'?0:1)-(rules[b].type==='dedicated'?0:1) || a-b; });
   var domainIndices=indices.filter(function(i){return rules[i].type!=='dedicated';});
   var rows = indices.map(function(index, position) {
    var rule = rules[index], dedicated=rule.type==='dedicated', adblock=rule.type==='geosite';
    var type = field(index,'type',panel.select(typeOptions,rule.type,function(value) {
     if(value==='dedicated' && currentGroup==='standard'){panel.showFailure(lk.text("常规组暂不支持专用入口，请在全局、增强或按需组建立。"));renderGroup();return;}
     var port=value==='dedicated'?nextPort():null;
     if(value==='dedicated' && !port){panel.showFailure(lk.text("10811—10860端口均已占用；停用入口也保留端口。"));renderGroup();return;}
     changesEntry(rule,function(){rule.type=value;rule.value=value==='geosite'?'category-ads-all':port || '';if(value==='geosite'){rule.action='block';delete rule.node;}if(value==='dedicated' && rule.action==='block')rule.action='proxy';renderGroup();});
     renderGroup();
    }),lk.text("类型"));
    var value = field(index,'value',E('input', {type:dedicated?'number':'text',min:dedicated?10811:null,max:dedicated?10860:null,step:dedicated?1:null, 'class':'cbi-input-text',value:rule.value,readonly:adblock?'':null,maxlength:dedicated?5:253,input:function() { rule.value = this.value; }}),lk.text("值"));
    var action = field(index,'action',panel.select(adblock?{block:lk.text("阻断广告")}:dedicated?{proxy:lk.text("代理（默认节点）"),node:lk.text("指定节点"),direct:lk.text("直连")}:{proxy:lk.text("本组代理节点"),node:lk.text("指定节点"),direct:lk.text("直连"),block:lk.text("阻断")},rule.action,function(v) { rule.action = v; if (v !== 'node') delete rule.node; else if (!rule.node) rule.node=Object.keys(nodeOptions)[0] || ''; renderGroup(); }),lk.text("出口"));
    var exitControls=[action];
    if (rule.action === 'node') { exitControls.push(field(index,'node',panel.select(nodeOptions,rule.node || '',function(v) { rule.node=v; }),lk.text("指定节点"))); if (!Object.keys(nodeOptions).length) exitControls.push(panel.message(lk.text("请先在节点页添加节点。"))); }
    var enabled = field(index,'enabled',E('input', {type:'checkbox',change:function() { var next=this.checked?'1':'0';if(next==='0') {this.checked=rule.enabled==='1';changesEntry(rule,function(){rule.enabled=next;renderGroup();});}else {rule.enabled=next;renderGroup();} }}),lk.text("启用"));
    enabled.checked = rule.enabled === '1';
    var note = field(index,'note',E('textarea', {'class':'cbi-input-textarea',rows:2,maxlength:256,input:function() { rule.note = this.value; }},rule.note || ''),lk.text("备注"));
    var up = panel.button(lk.text("上移"),function() { swap(index,-1); }), down = panel.button(lk.text("下移"),function() { swap(index,1); });
    up.disabled = dedicated || domainIndices.indexOf(index) === 0; down.disabled = dedicated || domainIndices.indexOf(index) === domainIndices.length - 1;
    var valueControls=[value], downloads=[];
    if(dedicated) {
     valueControls.push(E('code',{},'socks5://'+(data.lan&&data.lan.address||window.location.hostname)+':'+rule.value));
     ['chrome','edge'].forEach(function(browser){
      var name=browser==='chrome'?'Chrome':'Edge', enable=panel.button(name+lk.text(" 启用"),function(){panel.downloadReg(browser,rule.value,true);});
      enable.disabled=rule.enabled!=='1' || !saved[rule.id] || saved[rule.id].enabled!=='1' || saved[rule.id].type!=='dedicated' || saved[rule.id].value!==rule.value;
      downloads.push(enable,panel.button(name+lk.text(" 关闭"),function(){panel.downloadReg(browser,null,false);}));
     });
     valueControls.push(E('div',{},downloads));
     if(!saved[rule.id] || saved[rule.id].value!==rule.value || saved[rule.id].enabled!=='1')valueControls.push(panel.message(lk.text("应用后刷新页面，即可下载启用文件。")));
    }
    var effective = livePositions[rule.id];
    var sequence = Array.isArray(effective) ? (effective.length ? effective.join('、') : lk.text("未生效")) : lk.text("待应用");
    return E('tr', {'class':'tr'}, [
     E('td', {'class':'td'}, sequence), E('td', {'class':'td'}, [type]), E('td', {'class':'td'}, valueControls),
     E('td', {'class':'td'}, exitControls), E('td', {'class':'td'}, [enabled]), E('td', {'class':'td'}, [note]),
     E('td', {'class':'td'}, [up,down,panel.button(lk.text("删除"),function() { deleteRule(index); })])
    ]);
   });
   function table(selected) {return E('table', {'class':'table'}, [E('tr', {'class':'tr'}, [lk.text("生效序号"),lk.text("类型"),lk.text("值 / 浏览器文件"),lk.text("出口"),lk.text("启用"),lk.text("备注"),lk.text("调整")].map(function(t) { return E('th', {'class':'th'}, t); }))].concat(selected));}
   var entryRows=rows.filter(function(r,i){return rules[indices[i]].type==='dedicated';}), domainRows=rows.filter(function(r,i){return rules[indices[i]].type!=='dedicated';});
   fieldsBox.replaceChildren();
   if(entryRows.length)fieldsBox.appendChild(E('div',{'class':"lk-legacy-17"},[E('h4',{},lk.text("专用入口（独立匹配，不参与上下排序）")),table(entryRows)]));
   if(domainRows.length)fieldsBox.appendChild(E('div',{'class':"lk-legacy-17"},[E('h4',{},lk.text("域名规则")),table(domainRows)]));
   if (!rows.length) fieldsBox.appendChild(panel.message(lk.text("此组尚无“我的规则”。")));
   var builtin = (data.builtin || {})[currentGroup];
   builtinBox.replaceChildren();
   if (!Array.isArray(builtin) || !builtin.length) {
    builtinBox.appendChild(panel.notice(lk.text("未取得现役内置顺序，暂时不能展示优先级。请先确认状态接口。"),true));
    return;
   }
   builtinBox.appendChild(E('div', {}, builtin.map(function(item) {
    if(item.kind==='fallback' && fallbacks[currentGroup]) {
     var group=currentGroup,f=fallbacks[group],controls=[E('strong',{},lk.text("序号 ")+panel.text(item.position)+lk.text("：本组最终默认 / 兜底出口 ")),panel.select({proxy:lk.text("本组代理节点"),node:lk.text("指定节点"),direct:lk.text("直连")},f.action,function(v){f.action=v;f.node=v==='node'?(f.node || Object.keys(nodeOptions)[0] || ''):'';renderGroup();})];
     if(f.action==='node')controls.push(panel.select(nodeOptions,f.node,function(v){f.node=v;}));
     controls.push(panel.message(lk.text("只影响未命中前面规则的流量，保存后经统一应用生效。")));
     return E('div',{'class':'cbi-value'},controls);
    }
    return E('p', {'class':item.kind === 'user_slot' ? 'alert-message notice' : ''}, [E('strong', {}, item.kind === 'user_slot' ? lk.text("“我的规则”插入位置：") : lk.text("序号 ") + panel.text(item.position) + '：'), document.createTextNode(panel.text(item.text))]);
   })));
  }
  var tabs = E('ul', {'class':'cbi-tabmenu',role:'tablist'}, panel.groups.map(function(group) {
   var tab = E('li', {}, [E('button', {type:'button',role:'tab','class':'cbi-button',click:function() { currentGroup = group; renderGroup(); }},panel.labels[group])]);
   activeTabs[group] = tab;
   return tab;
  }));
  var add = panel.button(lk.text("新增规则"),function() {
   var id;
   do { generated++; id = 'ui_' + Date.now().toString(36) + '_' + generated; } while (rules.some(function(r) { return r.id === id; }));
   var last = -1;
   rules.forEach(function(rule,index) { if (rule.group === currentGroup) last = index; });
   rules.splice(last < 0 ? rules.length : last+1,0,{id:id,group:currentGroup,type:'domain',value:'',action:'proxy',enabled:'1',note:''});
   renderGroup();
  });
  var save = panel.button(lk.text("校验规则改动"),function() {
   save.disabled = true;
   panel.validateDraft({revision:config.revision || data.revision,scope:'rules',rules:rules,group_nodes:groupNodes,fallbacks:fallbacks,real_dns:realDns,nodes_revision:nodeCatalog.revision},errorBox,fields).then(function(reply) {
    if (reply && !reply.ok && reply.errors && reply.errors.length) {
     var match = String(reply.errors[0].field || '').match(/^rules(?:\.|\[)(\d+)/);
     if (match && rules[+match[1]] && rules[+match[1]].group !== currentGroup) {
      currentGroup = rules[+match[1]].group; renderGroup(); panel.errors(errorBox,reply.errors,fields);
     }
    }
   }).finally(function() { save.disabled = false; });
  },true);
  renderGroup();
  return E('div', {}, [
   E('h2', {}, lk.text("分流规则")), panel.pendingNotice(),chainForm.notices(),
   panel.notice(lk.text("域名规则从上向下匹配，在标明的插入位置生效。专用入口先执行自身的私网、FakeIP和内部端口保护，再到选定出口。保存只提交规则草稿，不夹带设备换组。")),
   panel.message(lk.text("序号随我的规则增减而变化。这里显示当前已生效 routing.rules 中的位置（从 1 开始）；草稿应用后更新，插入位置不占编号。")),
   tabs, groupBox, E('h3', {}, lk.text("我的规则")),
   panel.message(lk.text("支持域名及子域、完整域名、关键词、专用入口和广告域名库。广告域名库使用内核现有规则，可在各组勾选或取消启用，经校验并应用后生效。域名请用 ASCII 或 Punycode；关键词须为至少3位的小写字母、数字、点或连字符。")),
   panel.message(lk.text("专用入口端口10811—10860，在所有组之间唯一，停用时仍保留。仅全局、增强、按需组支持；只能由该组成员在LAN访问，无认证，仅SOCKS5 TCP，不支持UDP。设备移出组后入口访问会被阻断。")),
   panel.message(lk.text("浏览器启用/关闭.reg只供你下载并自行运行，需要管理员权限。运行后完全退出浏览器再打开；设置页显示“由你的组织管理”属正常。文件绕过本地名称和所选 LAN 子网，便于访问LAN面板。已有同名浏览器代理策略会被替换，使用前请自行保留原设置；关闭文件只删除ProxySettings。")),
   panel.notice(lk.text("专用入口只覆盖浏览器网页流量。WebRTC等UDP、浏览器独立更新程序仍按设备组规则走。默认节点故障时，所有代理出口（含指定节点）受同一门控阻断，不自动改为直连。")),
   E('div',{},[panel.button(lk.text("Chrome 关闭文件"),function(){panel.downloadReg('chrome',null,false);}),panel.button(lk.text("Edge 关闭文件"),function(){panel.downloadReg('edge',null,false);})]),
   fieldsBox, add,
   E('h3', {}, lk.text("内置规则")),
   panel.message(lk.text("共同保护及分类匹配条件保持；内置代理分类跟随本组代理节点，最后一条兜底仍可独立选择。以下序号对应当前已生效配置，未应用的组选项不会改写这些序号。")), builtinBox,
   E('h3',{},lk.text("不使用假 IP 的域名（全局）")),
   panel.message(lk.text("每行一项：domain:example.com 包含子域，full:example.com 只匹配完整域名。通过代理真实DoH解析，不分配FakeIP；流量出口仍按所属组规则。最多200项。")),
   panel.message(lk.text("连接检查、NTP和系统探测的原有真实解析规则继续保留。移除运营商域名可能使Wi-Fi通话失效；此列表与兜底出口都可在版本页撤销。")),
   dnsInput,errorBox,save
  ]);
 },
 handleSave:null, handleSaveApply:null, handleReset:null
});
