'require lanekeep.foundation as foundation';
'require lanekeep.i18n as lk';
"use strict";
'require view';
'require lanekeep as panel';
'require view.lanekeep.chain-form as chainForm';

// New copy is written with final terms and bypasses lk.text substring replacement.
function t(zh,en){return lk.language==='en'?en:zh;}
function kids(list){return list.filter(function(x){return x!=null&&x!==false;});}
function tip(summary,body){return E('details',{'class':'lk-tip'},[E('summary',{},[E('span',{'class':'lk-tip-icon','aria-hidden':'true'},'!'),E('span',{},summary)]),E('div',{'class':'lk-tip-body'},kids(body))]);}
function list(items,ordered){return E(ordered?'ol':'ul',{'class':'lk-tip-list'},items.map(function(x){return E('li',{},x);}));}
function card(title,sub,body,actions,extra){
 return E('section',{'class':'lk-rule-card'+(extra?' '+extra:'')},kids([
  E('div',{'class':'lk-rule-card-head'},kids([E('div',{'class':'lk-rule-card-title'},kids([E('h3',{},title),sub?E('p',{},sub):null])),actions&&actions.length?E('div',{'class':'lk-rule-card-actions'},actions):null])),
  E('div',{'class':'lk-rule-card-body'},kids(body))
 ]));
}
function iconButton(label,title,click){var b=panel.button(label,click);b.classList.add('lk-icon-btn');b.title=title;b.setAttribute('aria-label',title);return b;}

return foundation.view(view,{
 load:function() { return Promise.all([panel.loadStatus(),panel.rpc.nodes()]).then(function(results) { if (!results[1].ok) throw new Error('nodes_unavailable'); results[0].node_catalog=results[1]; return results[0]; }).catch(function() { return null; }); },
 render:function(data) {
  if (!data) return panel.loadFailure();
  var config = data.config || {}, rules = JSON.parse(JSON.stringify(config.rules || []));
  var groupNodes=Object.assign({standard:'',global:'',enhanced:'',ondemand:''},config.group_nodes || {});
  var fallbacks=JSON.parse(JSON.stringify(config.fallbacks || {})), realDns=(config.real_dns || []).slice();
  var dnsInput=E('textarea',{'class':'cbi-input-textarea lk-dns-input',rows:5,spellcheck:'false',placeholder:'domain:example.com',input:function(){realDns=this.value.split(/\r?\n/).map(function(x){return x.trim();}).filter(Boolean);}},realDns.join('\n'));
  var livePositions = data.rule_positions || {}, nodeCatalog=data.node_catalog || {}, nodeOptions={}, plainNodeOptions={}, chainIds={};
  (nodeCatalog.nodes || []).forEach(function(n) {
   if(n.protocol==='chain')chainIds[n.id]=true;
   if(n.route_allowed!==true || n.role==='rear_only')return;
   nodeOptions[n.id]=n.name+(n.protocol==='chain'?(n.udp?lk.text("（链 · TCP/UDP）"):lk.text("（链 · 仅 TCP）")):'');
   if(n.protocol!=='chain')plainNodeOptions[n.id]=n.name;
  });
  rules.forEach(function(rule) { if (Array.isArray(rule.positions)) livePositions[rule.id] = rule.positions; delete rule.positions; });
  var ipSupported=(data.rule_types || []).indexOf('ip')>=0 || rules.some(function(r){return r.type==='ip';});
  var currentGroup = 'standard', fields = {}, activeTabs = {};
  var groupBox=E('div'), customBox=E('div'), fallbackBox=E('div'), entryBox=E('div'), builtinBox=E('div');
  var errorBox = E('div', {'class':'alert-message warning',role:'alert',hidden:'','data-lk-hidden-origin':'true','aria-hidden':'true'});
  var typeOptions = {domain:lk.text("域名及子域"),full:lk.text("完整域名"),keyword:lk.text("关键词")};
  if(ipSupported)typeOptions.ip=t('IP / 网段','IP / network');
  typeOptions.dedicated=lk.text("专用入口");typeOptions.geosite=lk.text("广告域名库");
  var placeholders={domain:'example.com',full:'www.example.com',keyword:'example',ip:'1.2.3.4 / 1.2.3.0/24'};
  var saved = {}; (config.rules || []).forEach(function(r){saved[r.id]=r;});
  function nextPort() { for(var p=10811;p<=10860;p++)if(!rules.some(function(r){return r.type==='dedicated' && r.value===String(p);}))return String(p);return null; }
  function changesEntry(rule,fn) { if(rule.type==='dedicated' && saved[rule.id] && saved[rule.id].enabled==='1')panel.entryWarning(fn);else fn(); }
  var generated = 0;
  function newId(){var id;do { generated++; id = 'ui_' + Date.now().toString(36) + '_' + generated; } while (rules.some(function(r) { return r.id === id; }));return id;}
  function insertRule(rule){var last=-1;rules.forEach(function(r,index) { if (r.group === currentGroup) last = index; });rules.splice(last < 0 ? rules.length : last+1,0,rule);renderGroup();}
  function field(index, key, input, label) {
   return panel.bindField(fields, 'rules.' + index + '.' + key, input, panel.labels[rules[index].group] + lk.text("第 ") + (rules.filter(function(r, i) { return i <= index && r.group === rules[index].group; }).length) + lk.text(" 条 · ") + label);
  }
  function deleteRule(index) { changesEntry(rules[index],function(){rules.splice(index,1); renderGroup();}); }
  function swap(index, direction) {
   for (var i = index + direction; i >= 0 && i < rules.length; i += direction) {
    if (rules[index].type !== 'dedicated' && rules[i].type !== 'dedicated' && rules[i].group === currentGroup) { var tmp = rules[i]; rules[i] = rules[index]; rules[index] = tmp; break; }
   }
   renderGroup();
  }
  function groupChain(){return !!(groupNodes[currentGroup] && chainIds[groupNodes[currentGroup]]);}
  function sequence(rule){var effective = livePositions[rule.id];return Array.isArray(effective) ? (effective.length ? effective.join('、') : lk.text("未生效")) : lk.text("待应用");}
  function noteInput(index,rule){var input=E('input',{type:'text','class':'cbi-input-text lk-note-input',maxlength:256,placeholder:t('可选','Optional'),value:rule.note || '',title:rule.note || '',input:function(){rule.note=this.value;this.title=this.value;}});return field(index,'note',input,lk.text("备注"));}
  function enabledBox(index,rule){
   var enabled = field(index,'enabled',E('input', {type:'checkbox',change:function() { var next=this.checked?'1':'0';if(next==='0') {this.checked=rule.enabled==='1';changesEntry(rule,function(){rule.enabled=next;renderGroup();});}else {rule.enabled=next;renderGroup();} }}),lk.text("启用"));
   enabled.checked = rule.enabled === '1';return enabled;
  }
  function exitControls(index,rule){
   var dedicated=rule.type==='dedicated',adblock=rule.type==='geosite',ip=rule.type==='ip',options=ip?plainNodeOptions:nodeOptions;
   var action = field(index,'action',panel.select(adblock?{block:lk.text("阻断广告")}:dedicated?{proxy:lk.text("代理（默认节点）"),node:lk.text("指定节点"),direct:lk.text("直连")}:{proxy:lk.text("本组代理节点"),node:lk.text("指定节点"),direct:lk.text("直连"),block:lk.text("阻断")},rule.action,function(v) { rule.action = v; if (v !== 'node') delete rule.node; else if (!rule.node || !options[rule.node]) rule.node=Object.keys(options)[0] || ''; renderGroup(); }),lk.text("出口"));
   var out=[action];
   if (rule.action === 'node') { out.push(field(index,'node',panel.select(options,rule.node || '',function(v) { rule.node=v; }),lk.text("指定节点"))); if (!Object.keys(options).length) out.push(panel.message(ip?t('没有可用的普通节点（IP 规则不支持两跳链），请先在节点页添加。','No regular node available (IP rules cannot use chains).'):lk.text("请先在节点页添加节点。"))); }
   if (ip && rule.action==='proxy' && groupChain()) out.push(E('p',{'class':'lk-inline-warning'},t('本模式的节点是两跳链，IP 规则不支持；请改选指定节点、直连或阻断。','This mode uses a chain, which IP rules cannot use.')));
   return out;
  }
  function domainRow(index,domainIndices){
   var rule = rules[index], adblock=rule.type==='geosite';
   var type = field(index,'type',panel.select(typeOptions,rule.type,function(value) {
    if(value==='dedicated' && currentGroup==='standard'){panel.showFailure(lk.text("常规组暂不支持专用入口，请在全局、增强或按需组建立。"));renderGroup();return;}
    var port=value==='dedicated'?nextPort():null;
    if(value==='dedicated' && !port){panel.showFailure(lk.text("10811—10860端口均已占用；停用入口也保留端口。"));renderGroup();return;}
    changesEntry(rule,function(){rule.type=value;rule.value=value==='geosite'?'category-ads-all':port || '';if(value==='geosite'){rule.action='block';delete rule.node;}if(value==='dedicated' && rule.action==='block')rule.action='proxy';if(value==='ip' && rule.action==='node' && !plainNodeOptions[rule.node])rule.node=Object.keys(plainNodeOptions)[0] || '';renderGroup();});
    renderGroup();
   }),lk.text("类型"));
   var value = field(index,'value',E('input', {type:'text','class':'cbi-input-text',value:rule.value,readonly:adblock?'':null,maxlength:253,placeholder:placeholders[rule.type] || null,spellcheck:'false',input:function() { rule.value = this.value; }}),lk.text("值"));
   var position=domainIndices.indexOf(index);
   var up = iconButton('↑',lk.text("上移"),function() { swap(index,-1); }), down = iconButton('↓',lk.text("下移"),function() { swap(index,1); });
   up.disabled = position === 0; down.disabled = position === domainIndices.length - 1;
   return E('tr', {'class':'tr'}, [
    E('td', {'class':'td lk-col-seq'}, sequence(rule)), E('td', {'class':'td lk-col-type'}, [type]), E('td', {'class':'td lk-col-value'}, [value]),
    E('td', {'class':'td lk-col-exit'}, exitControls(index,rule)), E('td', {'class':'td lk-col-on'}, [enabledBox(index,rule)]), E('td', {'class':'td lk-col-note'}, [noteInput(index,rule)]),
    E('td', {'class':'td lk-col-actions'}, [E('div',{'class':'lk-row-buttons'},[up,down,panel.button(lk.text("删除"),function() { deleteRule(index); })])])
   ]);
  }
  function entryRow(index){
   var rule=rules[index];
   var value = field(index,'value',E('input', {type:'number',min:10811,max:10860,step:1,'class':'cbi-input-text lk-port-input',value:rule.value,maxlength:5,input:function() { rule.value = this.value; }}),lk.text("值"));
   var browsers=E('div',{'class':'lk-browser-files'},['chrome','edge'].map(function(browser){
    var name=browser==='chrome'?'Chrome':'Edge', enable=panel.button(lk.text("启用"),function(){panel.downloadReg(browser,rule.value,true);});
    enable.disabled=rule.enabled!=='1' || !saved[rule.id] || saved[rule.id].enabled!=='1' || saved[rule.id].type!=='dedicated' || saved[rule.id].value!==rule.value;
    enable.title=name+lk.text(" 启用");
    var off=panel.button(lk.text("关闭"),function(){panel.downloadReg(browser,null,false);});off.title=name+lk.text(" 关闭");
    return E('div',{'class':'lk-browser-line'},[E('span',{'class':'lk-browser-name'},name),enable,off]);
   }));
   var pending=!saved[rule.id] || saved[rule.id].value!==rule.value || saved[rule.id].enabled!=='1';
   return E('tr', {'class':'tr'}, [
    E('td', {'class':'td lk-col-seq'}, sequence(rule)),
    E('td', {'class':'td lk-col-port'}, [value,E('code',{'class':'lk-socks'},'socks5://'+(data.lan&&data.lan.address||window.location.hostname)+':'+rule.value)]),
    E('td', {'class':'td lk-col-exit'}, exitControls(index,rule)), E('td', {'class':'td lk-col-on'}, [enabledBox(index,rule)]),
    E('td', {'class':'td lk-col-browser'}, kids([browsers,pending?E('p',{},t('应用后刷新本页，才能下载“启用”文件。','Apply and reload to download the enable file.')):null])),
    E('td', {'class':'td lk-col-note'}, [noteInput(index,rule)]),
    E('td', {'class':'td lk-col-actions'}, [panel.button(lk.text("删除"),function() { deleteRule(index); })])
   ]);
  }
  function table(headers,rows){return E('div',{'class':'lk-table-scroll'},E('table', {'class':'table lk-rule-table'}, [E('tr', {'class':'tr'}, headers.map(function(h) { return E('th', {'class':'th'}, h); }))].concat(rows)));}
  function ruleHelp(){
   return tip(t('能添加哪些规则？怎么匹配？','Which rules can I add?'),[
    list(kids([
     t('域名及子域：填 example.com，同时匹配 www.example.com 等所有子域名。','Domain: example.com also matches all subdomains.'),
     t('完整域名：只匹配填写的这一个域名。','Full domain: matches exactly this name.'),
     t('关键词：域名里包含这段文字就匹配；至少 3 个小写字母、数字、点或连字符。','Keyword: matches any domain containing it (3+ chars).'),
     ipSupported?t('IP / 网段：填 1.2.3.4 或 1.2.3.0/24，只支持公网 IPv4。','IP / network: 1.2.3.4 or 1.2.3.0/24, public IPv4 only.'):null,
     t('广告域名库：内置广告列表，命中即阻断，可在每个模式单独开关。','Ad list: built-in ad domains, blocked when enabled.')
    ])),
    ipSupported?E('p',{'class':'lk-tip-key'},t('IP 规则只对“直接用 IP 地址连接”的流量生效，例如部分 App、游戏或你指定的服务器。用网址打开的网站会先按域名识别，用浏览器打开网站测不出 IP 规则，请改用域名规则。局域网、本机、组播和假 IP 地址不能填写；出口也不能是两跳链。','IP rules only match traffic that connects to a raw IP address (some apps, games, servers). Websites opened by name are matched by domain, so use a domain rule for them.')):null,
    E('p',{},t('规则从上到下匹配，先命中的生效，可用 ↑ ↓ 调整顺序。域名请用英文字母或 Punycode；每个模式最多 500 条。','Rules match top to bottom; reorder with ↑ ↓. Up to 500 rules per mode.')),
    E('p',{},t('生效序号：这条规则在当前已生效配置中的位置（从 1 开始）。“待应用”表示改动还没生效，应用后序号会更新。','Sequence: position in the active configuration; “pending” means not applied yet.'))
   ]);
  }
  function entryGuide(chromeOff,edgeOff){
   return tip(t('怎么启用和关闭？（第一次使用请先看）','How to turn it on and off (read first)'),[
    E('p',{},t('专用代理端口可以让电脑上的某个浏览器（Chrome 或 Edge）单独走代理，电脑上的其他程序不受影响。','A dedicated port sends one browser (Chrome or Edge) through the proxy without affecting other apps.')),
    E('h4',{},t('启用','Turn on')),
    list([
     t('点右上角“新增端口”，选好出口，再点页面底部“检查改动”并确认应用。','Click “Add port”, choose the exit, then “Review changes” at the bottom and apply.'),
     t('应用完成后刷新本页，在端口那一行点 Chrome 或 Edge 后面的“启用”，下载 .reg 文件。','Reload this page and click “Enable” next to Chrome or Edge to download a .reg file.'),
     t('在要使用的电脑上双击运行这个 .reg 文件，出现提示时选“是”（需要管理员权限）。','Double-click the .reg file on that computer and confirm (administrator rights needed).'),
     t('完全退出浏览器（包括右下角托盘图标）再重新打开。浏览器设置里显示“由你的组织管理”属于正常现象。','Fully quit and reopen the browser. “Managed by your organization” is expected.')
    ],true),
    E('h4',{},t('关闭（恢复原来的上网方式）','Turn off (restore normal browsing)')),
    list([
     t('点同一行的“关闭”，或下面的按钮，下载关闭文件。','Click “Disable” in the row, or a button below, to download the disable file.'),
     t('双击运行关闭文件，再完全退出并重新打开浏览器。','Run it, then fully quit and reopen the browser.'),
     t('要停用或删除端口时，必须先完成上面两步，否则这个浏览器会上不了网。','Do this before disabling or deleting a port, or the browser will lose internet access.')
    ],true),
    E('div',{'class':'lk-inline-actions'},[chromeOff,edgeOff]),
    E('h4',{},t('须知','Notes')),
    list([
     t('端口范围 10811—10860，所有模式共用且不能重复；停用的端口也会保留。','Ports 10811–10860 are shared by all modes and must be unique.'),
     t('只有本模式里的设备能在局域网内使用这个端口，设备移出本模式后会被拒绝。端口没有密码，只支持 SOCKS5 的 TCP，不支持 UDP。','Only devices in this mode can use the port on the LAN. No password, SOCKS5 TCP only.'),
     t('只有网页流量走这里；WebRTC 等 UDP 流量和浏览器自带的更新程序仍按本模式的规则处理。','Only web traffic uses it; UDP such as WebRTC and browser updaters follow the mode rules.'),
     t('每个端口先经过私网、假 IP 和内部端口保护，再交给所选出口；它不参与自定义规则的上下排序。','Each port has its own private-network, FakeIP and internal-port protection before the exit.'),
     t('.reg 文件会替换这个浏览器已有的代理策略，使用前请记下原设置；关闭文件只删除代理设置这一项。本机地址和所选 LAN 子网不走代理，方便打开路由器后台。','The .reg file replaces the browser proxy policy; the disable file removes only that setting.'),
     t('断线保护同样生效：默认节点不可用时会阻断，不会自动改为直连。','The kill switch still applies: traffic is blocked, never sent direct.')
    ])
   ]);
  }
  function renderNode(){
   var groupOptions=Object.assign({'':lk.text("跟随全局默认节点")},nodeOptions),selected=groupNodes[currentGroup];
   if(selected && !groupOptions[selected])groupOptions[selected]=lk.text("已保存节点 ")+selected+lk.text("（当前不可用，请重新选择）");
   var selector=panel.bindField(fields,'group_nodes.'+currentGroup,panel.select(groupOptions,selected,function(v){groupNodes[currentGroup]=v;renderGroup();}),panel.labels[currentGroup]+lk.text("组代理节点"));
   selector.classList.add('lk-node-select');
   var selectedNode=(nodeCatalog.nodes || []).filter(function(n){return n.id===selected;})[0];
   var ipProxy=rules.some(function(r){return r.group===currentGroup && r.type==='ip' && r.enabled==='1' && r.action==='proxy';});
   groupBox.replaceChildren(card(lk.mode(currentGroup,true)+t(' · 代理节点',' · proxy node'),t('本模式里出口为“本模式的节点”的规则和兜底都走这里；留空则跟随默认节点。','Rules and the fallback that use “this mode’s node” go here; empty follows the default node.'),[
    selector,
    selectedNode && selectedNode.protocol==='chain' && !selectedNode.udp?panel.notice(lk.text("此链仅承载命中它的 TCP；对应 UDP 会被阻断，不会自动改走默认节点或直连。")):null,
    currentGroup==='ondemand' && selectedNode && selectedNode.protocol==='chain'?panel.message(lk.text("按需的 Google / Netflix IP 分类也跟随此链；应用时校验原分类库，数据变化时拒绝应用并要求重新核对。")):null,
    ipProxy && groupChain()?panel.notice(t('本模式有 IP 规则的出口是“本模式的节点”，而两跳链不支持 IP 规则，检查改动时会被拒绝。请把这些 IP 规则改为指定节点。','IP rules here use this mode’s node, but chains do not support IP rules.'),true):null,
    tip(t('这个选项影响什么？','What does this affect?'),[list([
     t('影响：本模式的内置代理分类、自定义规则中出口为“本模式的节点”的规则，以及兜底出口选“本模式的节点”时。','Affects built-in proxy categories, rules using this mode’s node, and the fallback when set to it.'),
     t('不影响：直连、阻断、明确指定节点的规则和专用代理端口；DNS 解析路径也保持不变。','Does not affect direct, block, explicit-node rules, dedicated ports or DNS.'),
     t('断线保护对所有代理出口都生效：默认节点不可用时会阻断，不会自动改为直连。','The kill switch covers every proxy exit; nothing falls back to direct.'),
     t('选完要点页面底部“检查改动”并确认应用，只切换选项不会生效。','Click “Review changes” and confirm to apply; switching alone does nothing.')
    ])])
   ]));
  }
  function renderCustom(indices){
   var domainIndices=indices.filter(function(i){return rules[i].type!=='dedicated';});
   var add=panel.button(lk.text("新增规则"),function(){insertRule({id:newId(),group:currentGroup,type:'domain',value:'',action:'proxy',enabled:'1',note:''});},true);
   customBox.replaceChildren(card(lk.text("我的规则"),t('从上到下匹配，先命中的生效；没命中的流量继续按下方内置规则和兜底出口处理。','Matched top to bottom; unmatched traffic continues to built-in rules and the fallback.'),[
    ruleHelp(),
    domainIndices.length?table([lk.text("生效序号"),lk.text("类型"),t('匹配内容','Match'),lk.text("出口"),lk.text("启用"),lk.text("备注"),t('操作','Actions')],domainIndices.map(function(i){return domainRow(i,domainIndices);})):E('p',{'class':'lk-empty-line'},t('还没有自定义规则，点右上角“新增规则”添加。','No custom rules yet.'))
   ],[add]));
  }
  function renderEntries(indices){
   entryBox.replaceChildren();
   if(currentGroup==='standard')return;
   var entryIndices=indices.filter(function(i){return rules[i].type==='dedicated';});
   var chromeOff=panel.button(t('下载 Chrome 关闭文件','Chrome disable file'),function(){panel.downloadReg('chrome',null,false);}),edgeOff=panel.button(t('下载 Edge 关闭文件','Edge disable file'),function(){panel.downloadReg('edge',null,false);});
   var add=panel.button(t('新增端口','Add port'),function(){var port=nextPort();if(!port){panel.showFailure(lk.text("10811—10860端口均已占用；停用入口也保留端口。"));return;}insertRule({id:newId(),group:currentGroup,type:'dedicated',value:port,action:'proxy',enabled:'1',note:''});});
   entryBox.replaceChildren(card(lk.text("专用入口"),t('让某个浏览器单独走代理，独立匹配，不参与上面规则的排序。','Send one browser through the proxy; matched separately from the rules above.'),[
    entryGuide(chromeOff,edgeOff),
    entryIndices.length?table([lk.text("生效序号"),t('端口','Port'),lk.text("出口"),lk.text("启用"),t('浏览器设置文件','Browser file'),lk.text("备注"),t('操作','Actions')],entryIndices.map(entryRow)):E('p',{'class':'lk-empty-line'},t('本模式还没有专用代理端口。','No dedicated port in this mode.'))
   ],[add]));
  }
  function renderBuiltin(){
   fallbackBox.replaceChildren();builtinBox.replaceChildren();
   var builtin = (data.builtin || {})[currentGroup];
   if (!Array.isArray(builtin) || !builtin.length) {
    builtinBox.appendChild(panel.notice(lk.text("未取得现役内置顺序，暂时不能展示优先级。请先确认状态接口。"),true));
    return;
   }
   var items=builtin.map(function(item) {
    if(item.kind==='fallback' && fallbacks[currentGroup]) {
     var f=fallbacks[currentGroup],controls=[panel.select({proxy:lk.text("本组代理节点"),node:lk.text("指定节点"),direct:lk.text("直连")},f.action,function(v){f.action=v;f.node=v==='node'?(f.node || Object.keys(nodeOptions)[0] || ''):'';renderGroup();})];
     if(f.action==='node')controls.push(panel.select(nodeOptions,f.node,function(v){f.node=v;}));
     fallbackBox.appendChild(card(lk.text("兜底出口"),t('前面所有规则都没命中的流量走这里。','Traffic that matches no rule above uses this exit.'),[
      E('div',{'class':'lk-inline-controls'},controls),
      E('p',{'class':'lk-muted-line'},lk.text("生效序号 ")+panel.text(item.position)+t('；改动经底部“检查改动”确认后生效。','; applied after “Review changes”.'))
     ]));
     return E('li',{'class':'lk-builtin-fallback'},[E('span',{'class':'lk-builtin-pos'},panel.text(item.position)),E('span',{},t('兜底出口（在上方“兜底出口”中设置）','Fallback exit (set above)'))]);
    }
    // Built-in texts are generated prose with node IDs only; map fixed terms like the status page does.
    if(item.kind==='user_slot')return E('li',{'class':'lk-builtin-slot'},[E('span',{'class':'lk-builtin-pos'},'↳'),E('span',{},lk.ruleSummary(item.text)+t('（上方自定义规则在这里生效）',' (custom rules above apply here)'))]);
    return E('li',{},[E('span',{'class':'lk-builtin-pos'},panel.text(item.position)),E('span',{},lk.ruleSummary(item.text))]);
   });
   builtinBox.appendChild(E('details',{'class':'lk-disclosure lk-builtin'},[
    E('summary',{},lk.text("内置规则")+t('（'+builtin.length+' 项，只读，点此展开）',' ('+builtin.length+' items, read-only)')),
    E('div',{'class':'lk-disclosure-body'},[
     E('p',{'class':'lk-muted-line'},t('共同保护和分类匹配条件固定不变；内置代理分类跟随本模式的节点。序号对应当前已生效配置，未应用的改动不会改变它们。','Shared protections and categories are fixed; numbers follow the active configuration.')),
     E('ol',{'class':'lk-builtin-list'},items)
    ])
   ]));
  }
  function renderGroup() {
   fields = {};
   panel.bindField(fields,'settings',groupBox,lk.text("组代理节点 / 兜底出口 / 不使用假 IP 的域名"));
   renderNode();
   panel.errors(errorBox, [], fields);
   Object.keys(activeTabs).forEach(function(group) {
    activeTabs[group].className = group === currentGroup ? 'cbi-tab' : 'cbi-tab-disabled';
    activeTabs[group].firstChild.setAttribute('aria-selected', String(group === currentGroup));
   });
   var indices = [];
   rules.forEach(function(rule,index) { if (rule.group === currentGroup) indices.push(index); });
   renderCustom(indices);renderEntries(indices);renderBuiltin();
  }
  var tabs = E('ul', {'class':'cbi-tabmenu lk-mode-tabs',role:'tablist'}, panel.groups.map(function(group) {
   var tab = E('li', {}, [E('button', {type:'button',role:'tab','class':'cbi-button',click:function() { currentGroup = group; renderGroup(); }},panel.labels[group])]);
   activeTabs[group] = tab;
   return tab;
  }));
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
  var dnsCard=card(lk.text("不使用假 IP 的域名（全局）"),t('个别服务因假 IP 出问题时，把域名加到这里改用真实 IP；对所有模式生效。','Domains listed here get real IPs instead of FakeIP; applies to all modes.'),[
   dnsInput,
   tip(t('格式与注意事项','Format and notes'),[list([
    t('每行一项：domain:example.com 包含子域，full:example.com 只匹配这一个域名；最多 200 项。','One per line: domain:example.com includes subdomains, full:example.com is exact. Up to 200.'),
    t('经默认节点用真实 DoH 解析，不分配假 IP；流量最终走哪个出口仍按所在模式的规则。','Resolved with real DoH via the default node; the exit still follows the mode rules.'),
    t('连接检查、NTP 和系统探测原有的真实解析规则继续保留。删除运营商相关域名可能导致 Wi-Fi 通话失效。','Existing connectivity, NTP and probe exceptions stay. Removing carrier domains may break Wi-Fi calling.'),
    t('此列表和兜底出口都可以在“版本”页撤销。','This list and the fallback can be undone on the History page.')
   ])])
  ]);
  return E('div', {'class':'lk-page lk-rules-page'}, kids([
   E('div',{'class':'lk-page-head'},[E('h2', {}, lk.text("分流规则")),E('p',{},t('为每个模式设置网站和 IP 走代理、直连还是阻断。所有改动先保存在本页，点底部“检查改动”确认后才会生效。','Choose proxy, direct or block per mode. Changes stay on this page until you review and apply them.'))]),
   panel.pendingNotice(),
   Object.keys(chainIds).length?E('details',{'class':'lk-disclosure'},[E('summary',{},t('两跳链使用须知','Two-hop chain notes')),E('div',{'class':'lk-disclosure-body'},[chainForm.notices()])]):null,
   tabs, groupBox, customBox, fallbackBox, entryBox, builtinBox, dnsCard,
   errorBox,
   E('div',{'class':'lk-rules-footer-bar'},[E('p',{},t('检查后会列出全部改动，确认才会应用；本页不会带上设备换组。','Review lists every change before anything is applied.')),save])
  ]));
 },
 handleSave:null, handleSaveApply:null, handleReset:null
});
