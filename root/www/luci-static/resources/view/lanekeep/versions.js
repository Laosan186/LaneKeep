'require lanekeep.foundation as foundation';
'require lanekeep.i18n as lk';
"use strict";
'require view';
'require lanekeep as panel';

return foundation.view(view,{
 load:function() { return panel.rpc.versions().then(function(v) { return v.ok ? v : null; }).catch(function() { return null; }); },
 render:function(data) {
  if (!data) return panel.loadFailure();
  function restore(version, button) {
   if (panel.hasPending()) { panel.showFailure(lk.text("已有应用尚未确认，请先查询原任务状态。")); return; }
   button.disabled = true;
   panel.rpc.rollback(version.id, 'all').then(function(result) {
    if (!result.ok) {
     var errors = (result.errors || []).map(function(e) { return panel.text(e.message, lk.text("校验失败")); });
     panel.showFailure(errors.length ? errors.join('；') : result.message || lk.text("恢复草稿校验失败，当前配置未变。"));
     return;
    }
    panel.confirmValidated(result, null, version.kind === 'failed' ? lk.text("准备重试这次未成功的改动，请核对下面的差异。") : lk.text("准备撤销到这次操作之前，请核对下面的差异。"));
   }).catch(function() { panel.showFailure(lk.text("未取得恢复草稿校验结果，未发送应用。")); }).finally(function() { button.disabled = !!version.same_current; });
  }
  var rows = (data.versions || []).slice(0,20).map(function(version) {
   var action = panel.button(version.kind === 'failed' ? lk.text("重试这次改动") : lk.text("撤销到这次操作之前"), function() { restore(version,action); });
   action.disabled = !!version.same_current;
   return E('tr', {'class':'tr'}, [
    E('td', {'class':'td'}, [E('strong', {}, version.kind === 'failed' ? lk.text("未成功的改动") : lk.text("历史操作")), E('p', {}, version.id)]),
    E('td', {'class':'td'}, panel.utc(version.time_utc)),
    E('td', {'class':'td'}, panel.summary(version.summary)),
    E('td', {'class':'td'}, panel.resultLabel(version.result)),
    E('td', {'class':'td'}, version.same_current ? [action, E('p', {}, lk.text("与当前相同"))] : [action])
   ]);
  });
  return E('div', {}, [
   E('h2', {}, lk.text("版本")), panel.pendingNotice(),
   panel.notice(lk.text("每行对应一次操作。撤销会恢复该次操作之前的完整状态，所选操作及之后的改动会一起撤销；未成功的改动可重新校验后重试。失败草稿与同次操作合并显示。时间使用路由器时区，列表显示相对时间，悬停查看完整时间。")),
   panel.notice(lk.text("点击按钮先查看差异，确认后只恢复有变化的部分：先分组，再恢复规则和节点（含默认选择）。仅生成的核心配置有变化时重启核心。")),
   rows.length ? E('div', {'class':"lk-legacy-17"}, [E('table', {'class':'table'}, [E('tr', {'class':'tr'}, [lk.text("操作"),lk.text("时间"),lk.text("改动摘要"),lk.text("结果"),lk.text("操作")].map(function(t) { return E('th', {'class':'th'}, t); }))].concat(rows))]) : panel.message(lk.text("目前没有可显示的版本。"))
  ]);
 },
 handleSave:null, handleSaveApply:null, handleReset:null
});
