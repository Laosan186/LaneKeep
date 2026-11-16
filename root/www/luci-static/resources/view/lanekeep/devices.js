'require lanekeep.foundation as foundation';
'require lanekeep.i18n as lk';
"use strict";
'require view';
'require lanekeep as panel';

return foundation.view(view,{
 load:function() { return panel.loadStatus().catch(function() { return null; }); },
 render:function(data) {
  if (!data) return panel.loadFailure();
  var config = data.config || {}, devices = data.devices || {}, members = config.members || {};
  var errorBox = E('div', {'class':'alert-message warning', role:'alert', hidden:'', 'data-lk-hidden-origin':'true', 'aria-hidden':'true'}), fields = {}, chosen = {}, known = {};
  var staticRows = (devices.static || []).map(function(d) {
   known[d.ip] = true;
   chosen[d.ip] = d.group || 'standard';
   var control = panel.select(panel.labels, chosen[d.ip], function(value) { chosen[d.ip] = value; });
   panel.bindField(fields, 'members.' + d.ip, control, d.ip + lk.text(" 分组"));
   return E('tr', {'class':'tr'}, [E('td', {'class':'td'}, panel.text(d.name, lk.text("未命名"))), E('td', {'class':'td'}, d.ip), E('td', {'class':'td'}, [control])]);
  });
  ['global','enhanced','ondemand'].forEach(function(g) {
   (members[g] || []).forEach(function(ip) {
    if (known[ip]) return;
    chosen[ip] = g;
    var options = {standard:lk.text("常规（移除失效成员）")}; options[g] = panel.labels[g] + lk.text("（当前）");
    var control = panel.select(options, g, function(value) { chosen[ip] = value; });
    panel.bindField(fields, 'members.' + ip, control, ip + lk.text(" 失效成员"));
    staticRows.push(E('tr', {'class':'tr'}, [E('td', {'class':'td'}, lk.text("静态绑定已缺失")), E('td', {'class':'td'}, ip), E('td', {'class':'td'}, [control])]));
   });
  });
  var save = panel.button(lk.text("校验分组改动"), function() {
   var draftMembers = {global:[],enhanced:[],ondemand:[]};
   Object.keys(chosen).forEach(function(ip) { if (chosen[ip] !== 'standard') draftMembers[chosen[ip]].push(ip); });
   save.disabled = true;
   panel.validateDraft({revision:config.revision || data.revision,scope:'members',members:draftMembers},errorBox,fields).finally(function() { save.disabled = false; });
  }, true);
  var dhcpPath = devices.dhcp_path;
  var validPath = Array.isArray(dhcpPath) && dhcpPath.join('/') === 'admin/network/dhcp';
  return E('div', {}, [
   E('h2', {}, lk.text("设备分组")), panel.pendingNotice(),
   panel.notice(lk.text("只修改分组。新连接按新组处理，已有连接可能暂沿原组；应用不重启核心，不改变共享 FakeDNS 映射。")),
   E('h3', {}, lk.text("DHCP 静态分配")),
   E('table', {'class':'table'}, [E('tr', {'class':'tr'}, [lk.text("主机名"),lk.text("IP 地址"),lk.text("分组")].map(function(t) { return E('th', {'class':'th'}, t); }))].concat(staticRows)),
   errorBox, save,
   E('h3', {}, lk.text("动态租约")),
   panel.message(lk.text("以下设备未固定 IP，需先固定才能分组。")),
   validPath ? E('a', {href:L.url.apply(L, dhcpPath)}, lk.text("前往 DHCP 页面设置静态分配")) : panel.notice(lk.text("DHCP 页面路径未核实，请从 LuCI 网络菜单进入。"), true),
   (devices.dynamic || []).length ? E('table', {'class':'table'}, [E('tr', {'class':'tr'}, [lk.text("主机名"),lk.text("IP 地址"),lk.text("状态")].map(function(t) { return E('th', {'class':'th'}, t); }))].concat((devices.dynamic || []).map(function(d) { return E('tr', {'class':'tr'}, [E('td', {'class':'td'}, panel.text(d.name, lk.text("未命名"))), E('td', {'class':'td'}, d.ip), E('td', {'class':'td'}, lk.text("未固定 IP"))]); }))) : panel.message(lk.text("当前没有未固定 IP 的动态租约。"))
  ]);
 },
 handleSave:null, handleSaveApply:null, handleReset:null
});
