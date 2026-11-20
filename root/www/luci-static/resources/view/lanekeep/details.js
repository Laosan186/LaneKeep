'require lanekeep.foundation as foundation';
'require lanekeep.i18n as lk';
"use strict";
'require view';
'require lanekeep as panel';
'require lanekeep-history as history';

function t(zh,en){return lk.language==='en'?en:zh;}
function kids(list){return list.filter(function(x){return x!=null&&x!==false;});}
function stat(label,value,sub,tone){return E('div',{'class':'lk-stat'+(tone?' lk-tone-'+tone:'')},kids([E('span',{'class':'lk-stat-label'},label),E('strong',{'class':'lk-stat-value'},value),sub?E('span',{'class':'lk-stat-sub'},sub):null]));}
function tip(summary,body){return E('details',{'class':'lk-tip'},[E('summary',{},[E('span',{'class':'lk-tip-icon','aria-hidden':'true'},'!'),E('span',{},summary)]),E('div',{'class':'lk-tip-body'},kids(body))]);}
function section(title,sub,body,actions){return E('section',{'class':'lk-rule-card'},kids([E('div',{'class':'lk-rule-card-head'},kids([E('div',{'class':'lk-rule-card-title'},kids([E('h3',{},title),sub?E('p',{},sub):null])),actions?E('div',{'class':'lk-rule-card-actions'},actions):null])),E('div',{'class':'lk-rule-card-body'},kids(body))]));}

return foundation.view(view,{
 load:function() { return Promise.all([panel.loadStatus().catch(function() { return null; }), history.read('30m','none').catch(function() { return null; })]).then(function(a) { if(a[0])a[0].telemetry=a[1];return a[0]; }); },
 render:function(data) {
  if (!data) return panel.loadFailure();
  var core = data.core || {}, gate = data.gate || {}, last = data.last_apply || {}, current=data.default_node || {};
  var tested=current.last_test || {};
  var exitResult = E('div', {'role':'status', 'aria-live':'polite','class':'lk-exit-result'});
  var check = panel.button(lk.text("测试默认节点"), function() {
   check.disabled = true;
   exitResult.replaceChildren(panel.message(t('正在经默认节点测试延迟和出口，最长约 15 秒……','Testing latency and exit through the default node, up to about 15 s…')));
   panel.rpc.node_test(current.id).then(function(result) {
    exitResult.replaceChildren(panel.notice(result.ok ? lk.text("出口 ") + panel.text(result.ip) + lk.text("，地区 ") + panel.text(result.country) + '，' + panel.testDuration(result) + '；' + panel.utc(result.time_utc) : (result.message || lk.text("检测失败，未改为直连。")), !result.ok));
   }).catch(function() {
    exitResult.replaceChildren(panel.notice(lk.text("未取得检测结果；不自动重试，不改为直连。"), true));
   }).finally(function() { check.disabled = false; });
  }, true);
  check.disabled=!current.id;
  var gateText=gate.state === 'OPEN' ? lk.text("开放") : gate.state === 'CLOSED' ? lk.text("关闭（保护中）") : lk.text("状态未知");
  var overview=E('div',{'class':'lk-stat-grid'},[
   stat(lk.text("默认节点"),panel.text(current.name),null,null),
   stat(lk.text("最近测试出口"),tested.ok?panel.text(tested.ip)+' · '+panel.text(tested.country):lk.text("暂无成功测试"),tested.ok?panel.utc(tested.time_utc):null,tested.ok?null:'muted'),
   stat(lk.text("代理程序"),core.running ? lk.text("运行中") : lk.text("未运行"),null,core.running?'ok':'bad'),
   stat(lk.text("保护开关"),gateText,gate.fresh?null:lk.text("状态记录不新鲜或未核实"),gate.state==='OPEN'&&gate.fresh?'ok':gate.state==='CLOSED'?'warn':'muted'),
   stat(lk.text("当前版本"),panel.text(data.current_version),null,null),
   stat(t('上次应用','Last apply'),panel.resultLabel(last.result),panel.utc(last.time_utc || last.time),null)
  ]);
  var counts=E('div',{'class':'lk-stat-grid lk-stat-grid-4'},panel.groups.map(function(g){var n=(data.counts || {})[g];return stat(lk.mode(g,true),panel.text(typeof n === 'object' && n ? n.static : n, lk.text("未知")),t('台设备','devices'),null);}));
  return E('div', {'class':'lk-page lk-details-page'}, kids([
   E('div',{'class':'lk-page-head'},[E('h2', {}, lk.text("详细数据")),E('p',{},t('查看配置摘要、默认节点出口和路由器运行曲线，排查卡顿时用。','Configuration summary, default exit and router metrics for troubleshooting.'))]),
   panel.pendingNotice(),
   (data.warnings || []).length?E('div',{'class':'lk-stack'},(data.warnings || []).map(function(w) { return panel.notice(typeof w === 'string' ? w : w.message || (lk.text("成员 ") + panel.text(w.ip) + lk.text(" 已失去 DHCP 静态绑定。")), true); })):null,
   section(lk.text("打开页面时的配置摘要"),null,[overview]),
   section(lk.text("设备分组数量"),t('按 DHCP 静态绑定统计，不是在线设备数。','Counted from static DHCP bindings, not online devices.'),[counts,tip(t('怎么算的？','How is this counted?'),[E('p',{},t('数量来自各模式里已做 DHCP 静态绑定的设备，不代表当前在线数量。没有单独分组的其他局域网设备都按常规模式处理。','Counts come from static DHCP bindings per mode, not online devices. Ungrouped LAN devices use Standard mode.'))])]),
   section(lk.text("默认节点出口"),t('点击后经默认节点发几次限时小请求，测量延迟并显示实际出口 IP，不会切换任何设置。','Sends a few short requests through the default node to measure latency and show the exit IP.'),[exitResult,tip(t('测试说明','About this test'),[E('p',{},t('只在点击时经默认节点测试：先在同一条连接上请求 www.gstatic.com/generate_204 测延迟，再另起连接经 ipinfo.io 查出口，不会自动切换。测试由隔离的临时进程发起；主代理程序和日常使用是否正常，还要看断线保护状态和设备上的实际体验。','Only runs when clicked: latency is timed with www.gstatic.com/generate_204 on one connection, then ipinfo.io reports the exit. It runs in an isolated temporary process and switches nothing.')),E('p',{},t('延迟取连接建立后两次请求的较小值；“首次连接”含与节点握手。超时不显示毫秒值。这个结果不能代替在手机、电脑或电视上的实际使用验收。','Latency is the faster of two requests on an established connection; “first connection” includes the node handshake. This does not replace testing on real devices.'))])],[check]),
   section(t('运行监控','Monitoring'),t('每 5 秒更新；红色竖线是你点“标记卡顿”的时刻。','Updates every 5 s; red lines mark when you flagged slowness.'),[history.render(data.telemetry, current)])
  ]));
 },
 handleSave:null, handleSaveApply:null, handleReset:null
});
