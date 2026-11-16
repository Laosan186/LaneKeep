'require lanekeep.foundation as foundation';
'require lanekeep.i18n as lk';
"use strict";
'require view';
'require lanekeep as panel';
'require lanekeep-history as history';

return foundation.view(view,{
 load:function() { return Promise.all([panel.loadStatus().catch(function() { return null; }), history.read('30m','none').catch(function() { return null; })]).then(function(a) { if(a[0])a[0].telemetry=a[1];return a[0]; }); },
 render:function(data) {
  if (!data) return panel.loadFailure();
  var core = data.core || {}, gate = data.gate || {}, last = data.last_apply || {}, current=data.default_node || {};
  var tested=current.last_test || {};
  var exitResult = E('div', {'role':'status', 'aria-live':'polite'});
  var check = panel.button(lk.text("测试默认节点"), function() {
   check.disabled = true;
   exitResult.replaceChildren(panel.message(lk.text("正在从隔离临时入口测试默认节点，限时10秒……")));
   panel.rpc.node_test(current.id).then(function(result) {
    exitResult.replaceChildren(panel.notice(result.ok ? lk.text("出口 ") + panel.text(result.ip) + lk.text("，地区 ") + panel.text(result.country) + '，' + panel.testDuration(result) + '；' + panel.utc(result.time_utc) : (result.message || lk.text("检测失败，未改为直连。")), !result.ok));
   }).catch(function() {
    exitResult.replaceChildren(panel.notice(lk.text("未取得检测结果；不自动重试，不改为直连。"), true));
   }).finally(function() { check.disabled = false; });
  }, true);
  check.disabled=!current.id;
  var rows = [
   [lk.text("默认节点"), panel.text(current.name)],
   [lk.text("最近测试出口"), tested.ok ? panel.text(tested.ip)+' · '+panel.text(tested.country)+' · '+panel.utc(tested.time_utc) : lk.text("暂无成功测试")],
   [lk.text("代理程序"), core.running ? lk.text("运行中") : lk.text("未运行")],
   [lk.text("保护开关"), (gate.state === 'OPEN' ? lk.text("开放") : gate.state === 'CLOSED' ? lk.text("关闭（保护中）") : lk.text("状态未知")) + (gate.fresh ? '' : lk.text("；状态记录不新鲜或未核实"))],
   [lk.text("当前版本"), panel.text(data.current_version)],
   [lk.text("上次应用时间"), panel.utc(last.time_utc || last.time)],
   [lk.text("上次应用结果"), panel.resultLabel(last.result)]
  ];
  return E('div', {}, [
   E('h2', {}, lk.text("分流管理 · 详细数据")), panel.pendingNotice(), history.render(data.telemetry, current), E('h3', {}, lk.text("打开页面时的配置摘要")),
   E('table', {'class':'table'}, rows.map(function(row) { return E('tr', {'class':'tr'}, [E('th', {'class':'th'}, row[0]), E('td', {'class':'td'}, row[1])]); })),
   E('h3', {}, lk.text("设备分组数量")),
   panel.notice(lk.text("数量统计 DHCP 静态绑定对应的配置分组，不代表当前在线设备数。常规组也承接未单独分组的其他 LAN 设备。")),
   E('table', {'class':'table'}, [E('tr', {'class':'tr'}, panel.groups.map(function(g) { return E('th', {'class':'th'}, panel.labels[g]); })), E('tr', {'class':'tr'}, panel.groups.map(function(g) { var n = (data.counts || {})[g]; return E('td', {'class':'td'}, panel.text(typeof n === 'object' && n ? n.static : n, lk.text("未知"))); }))]),
   E('div', {}, (data.warnings || []).map(function(w) { return panel.notice(typeof w === 'string' ? w : w.message || (lk.text("成员 ") + panel.text(w.ip) + lk.text(" 已失去 DHCP 静态绑定。")), true); })),
   E('h3', {}, lk.text("默认节点出口")),
   panel.message(lk.text("仅点击时经默认节点发一次限时小请求，显示实际出口，不自动切换。结果来自临时测试进程，主代理程序和业务路径另由保护开关及终端验收核对。")),
   check, exitResult,
   panel.notice(lk.text("测试由隔离临时进程发起。请求耗时包含代理连接和响应接收，不包含临时进程启动、等待和清理；超时不显示毫秒值。该结果不能代替手机、增强或按需的实际业务验收。"))
  ]);
 },
 handleSave:null, handleSaveApply:null, handleReset:null
});
