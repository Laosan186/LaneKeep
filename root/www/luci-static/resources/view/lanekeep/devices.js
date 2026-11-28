'require lanekeep.foundation as foundation';
'require lanekeep.i18n as lk';
"use strict";
'require view';
'require lanekeep as panel';

return foundation.view(view,{
 load:function() { return panel.loadStatus().catch(function() { return null; }); },
 render:function(data) {
  if (!data) return panel.loadFailure();
  function t(zh,en){return lk.language==='en'?en:zh;}
  var config = data.config || {}, devices = data.devices || {}, members = config.members || {}, unassigned = config.unassigned === 'direct' ? 'direct' : 'standard';
  var errorBox = E('div', {'class':'alert-message warning', role:'alert', hidden:'', 'data-lk-hidden-origin':'true', 'aria-hidden':'true'}), fields = {}, chosen = {}, known = {};
  // "auto" keeps a device out of every member set, so it follows the unassigned choice.
  // Only a concrete choice is saved as a member: a member whose static lease is later
  // deleted makes generation fail, so devices are never pinned without being asked.
  var choices = {auto:t('跟随默认（'+panel.labels[unassigned]+'）', 'Follow default ('+panel.labels[unassigned]+')')}; panel.memberGroups.forEach(function(g) { choices[g] = panel.labels[g]; });
  var staticRows = (devices.static || []).map(function(d) {
   known[d.ip] = true;
   chosen[d.ip] = d.explicit === false ? 'auto' : (d.group || 'auto');
   var control = panel.select(choices, chosen[d.ip], function(value) { chosen[d.ip] = value; });
   panel.bindField(fields, 'members.' + d.ip, control, d.ip + lk.text(" 分组"));
   return E('tr', {'class':'tr'}, [E('td', {'class':'td'}, panel.text(d.name, lk.text("未命名"))), E('td', {'class':'td'}, d.ip), E('td', {'class':'td'}, [control])]);
  });
  panel.memberGroups.forEach(function(g) {
   (members[g] || []).forEach(function(ip) {
    if (known[ip]) return;
    chosen[ip] = g;
    var options = {remove:t('移除失效成员', 'Remove stale member')}; options[g] = panel.labels[g] + lk.text("（当前）");
    var control = panel.select(options, g, function(value) { chosen[ip] = value; });
    panel.bindField(fields, 'members.' + ip, control, ip + lk.text(" 失效成员"));
    staticRows.push(E('tr', {'class':'tr'}, [E('td', {'class':'td'}, lk.text("静态绑定已缺失")), E('td', {'class':'td'}, ip), E('td', {'class':'td'}, [control])]));
   });
  });
  var save = panel.button(lk.text("校验分组改动"), function() {
   var draftMembers = {global:[],enhanced:[],ondemand:[],standard:[],direct:[]};
   Object.keys(chosen).forEach(function(ip) { if (draftMembers[chosen[ip]]) draftMembers[chosen[ip]].push(ip); });
   save.disabled = true;
   panel.validateDraft({revision:config.revision || data.revision,scope:'members',members:draftMembers},errorBox,fields).finally(function() { save.disabled = false; });
  }, true);
  var unassignedBox = E('div', {'class':'alert-message warning', role:'alert', hidden:'', 'data-lk-hidden-origin':'true', 'aria-hidden':'true'}), unassignedFields = {}, unassignedChoice = unassigned;
  var unassignedSelect = panel.select({direct:panel.labels.direct, standard:panel.labels.standard}, unassigned, function(value) { unassignedChoice = value; });
  panel.bindField(unassignedFields, 'unassigned', unassignedSelect, t('未分组设备去向', 'Devices without a mode'));
  var unassignedSave = panel.button(t('校验此项改动', 'Review this change'), function() {
   unassignedSave.disabled = true;
   panel.validateDraft({revision:config.revision || data.revision,scope:'rules',unassigned:unassignedChoice},unassignedBox,unassignedFields).finally(function() { unassignedSave.disabled = false; });
  }, true);
  var dhcpPath = devices.dhcp_path;
  var validPath = Array.isArray(dhcpPath) && dhcpPath.join('/') === 'admin/network/dhcp';
  function card(title,sub,body,actions){return E('section',{'class':'lk-rule-card'},[E('div',{'class':'lk-rule-card-head'},[E('div',{'class':'lk-rule-card-title'},[E('h3',{},title),E('p',{},sub)])].concat(actions?[E('div',{'class':'lk-rule-card-actions'},actions)]:[])),E('div',{'class':'lk-rule-card-body'},body)]);}
  function table(headers,rows){return E('div',{'class':'lk-table-scroll'},E('table', {'class':'table'}, [E('tr', {'class':'tr'}, headers.map(function(h) { return E('th', {'class':'th'}, h); }))].concat(rows)));}
  var tip=E('details',{'class':'lk-tip'},[E('summary',{},[E('span',{'class':'lk-tip-icon','aria-hidden':'true'},'!'),E('span',{},t('换模式后会发生什么？','What happens after switching?'))]),E('div',{'class':'lk-tip-body'},[E('p',{},t('只改设备所在的模式。应用后新连接按新模式的规则处理，已有连接可能暂时沿用原模式；不会重启代理核心，也不会改变共享的假 IP 映射。','Only the mode changes. New connections follow the new mode; existing ones may keep the old mode briefly. The proxy core is not restarted.')),E('p',{},t('没有固定 IP 的设备按下方“未分组设备去向”处理（当前：'+panel.labels[unassigned]+'）；要放进其他模式，先在 DHCP 页面给它固定 IP。','Devices without a fixed IP follow “Devices without a mode” below (now: '+panel.labels[unassigned]+'); fix the IP on the DHCP page first.')),E('p',{},t('选“跟随默认”的设备也按“未分组设备去向”处理；选了具体模式的设备固定在该模式，之后改“未分组设备去向”不影响它们。','Devices set to “Follow default” also follow “Devices without a mode”; a device set to a specific mode stays there when that choice changes later.'))])]);
  var dhcpLink=validPath ? E('a', {'class':'cbi-button cbi-button-neutral',href:L.url.apply(L, dhcpPath)}, lk.text("前往 DHCP 页面设置静态分配")) : null;
  return E('div', {'class':'lk-page lk-devices-page'}, [
   E('div',{'class':'lk-page-head'},[E('h2', {}, lk.text("设备分组")),E('p',{},t('把设备放进不同模式，每个模式使用自己的分流规则。','Put each device in a mode; every mode has its own rules.'))]),
   panel.pendingNotice(),
   card(lk.text("DHCP 静态分配"),t('已固定 IP 的设备可以选择模式；改完点底部“检查改动”。','Devices with a fixed IP can choose a mode.'),[tip,staticRows.length?table([lk.text("主机名"),lk.text("IP 地址"),lk.text("分组")],staticRows):E('p',{'class':'lk-empty-line'},t('还没有固定 IP 的设备。','No device has a fixed IP yet.'))]),
   errorBox,
   E('div',{'class':'lk-rules-footer-bar'},[E('p',{},t('检查后会列出改动，确认才会应用。','Review lists the changes before applying.')),save]),
   card(t('未分组设备去向', 'Devices without a mode'),t('没有固定 IP 的设备、新连上的陌生设备，以及从未选过模式的设备按这里处理。','Devices without a fixed IP, unknown new devices and devices never placed in a mode use this choice.'),[
    E('p',{},[unassignedSelect]),
    E('p',{},t('直连：全部直接上网，不经过任何代理节点，也不提供 DNS 和 WebRTC 防泄漏；国外网站可能打不开。可防止别人连上 Wi-Fi 后使用你的代理。','Direct: everything goes out directly, never through a proxy node, with no DNS or WebRTC leak protection; foreign sites may not open. Stops strangers on your Wi-Fi from using your proxy.')),
    E('p',{},t('常规：按常规模式分流，已知国外分类走代理。','Standard: split by Standard mode rules; known foreign categories use the proxy.')),
    E('p',{},t('改动会重启代理核心，全家网络预计中断约 10 秒（估计值）。直连组设备与其他组一样能打开路由器登录页，请保持管理密码足够强。','Changing this restarts the proxy core; the whole network pauses for about 10 seconds (estimate). Direct devices can still reach the router login page like any other mode, so keep the admin password strong.')),
    unassignedBox
   ],[unassignedSave]),
   card(lk.text("动态租约"),lk.text("以下设备未固定 IP，需先固定才能分组。"),[
    validPath ? null : panel.notice(lk.text("DHCP 页面路径未核实，请从 LuCI 网络菜单进入。"), true),
    (devices.dynamic || []).length ? table([lk.text("主机名"),lk.text("IP 地址"),lk.text("状态")],(devices.dynamic || []).map(function(d) { return E('tr', {'class':'tr'}, [E('td', {'class':'td'}, panel.text(d.name, lk.text("未命名"))), E('td', {'class':'td'}, d.ip), E('td', {'class':'td'}, lk.text("未固定 IP") + ' · ' + panel.labels[unassigned])]); })) : E('p',{'class':'lk-empty-line'},lk.text("当前没有未固定 IP 的动态租约。"))
   ].filter(Boolean),dhcpLink?[dhcpLink]:null)
  ]);
 },
 handleSave:null, handleSaveApply:null, handleReset:null
});
