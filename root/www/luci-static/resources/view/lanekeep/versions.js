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
    E('td', {'class':'td'}, [E('strong', {}, version.kind === 'failed' ? lk.text("未成功的改动") : lk.text("历史操作")), E('p', {'class':'lk-version-id'}, version.id)]),
    E('td', {'class':'td'}, panel.utc(version.time_utc)),
    E('td', {'class':'td'}, panel.summary(version.summary)),
    E('td', {'class':'td'}, panel.resultLabel(version.result)),
    E('td', {'class':'td'}, version.same_current ? [action, E('p', {}, lk.text("与当前相同"))] : [action])
   ]);
  });
  function t(zh,en){return lk.language==='en'?en:zh;}
  var tip=E('details',{'class':'lk-tip'},[E('summary',{},[E('span',{'class':'lk-tip-icon','aria-hidden':'true'},'!'),E('span',{},t('撤销是怎么工作的？','How does undo work?'))]),E('div',{'class':'lk-tip-body'},[
   E('p',{},t('每行是一次操作。“撤销到此之前”会恢复这次操作之前的完整状态，这次及之后的改动会一起撤销；未成功的改动可以重新检查后重试。','Each row is one operation. Undo restores the state before it, including later changes.')),
   E('p',{},t('点按钮会先列出差异，确认后才恢复有变化的部分：先恢复设备分组，再恢复规则和节点（含默认节点）。只有生成的代理配置有变化时才会重启代理核心。','You will see the differences first; only changed parts are restored.')),
   E('p',{},t('列表显示相对时间，鼠标悬停可看完整时间（路由器时区）。','Hover a time to see the full router-time value.'))
  ])]);
  return E('div', {'class':'lk-page lk-versions-page'}, [
   E('div',{'class':'lk-page-head'},[E('h2', {}, lk.text("版本")),E('p',{},t('查看最近 20 次改动，需要时撤销到某次操作之前。','Recent 20 changes; undo to before any of them.'))]),
   panel.pendingNotice(),
   E('section',{'class':'lk-rule-card'},[E('div',{'class':'lk-rule-card-body'},[tip,rows.length ? E('div', {'class':"lk-legacy-17"}, [E('table', {'class':'table'}, [E('tr', {'class':'tr'}, [lk.text("操作"),lk.text("时间"),lk.text("改动摘要"),lk.text("结果"),lk.text("操作")].map(function(h) { return E('th', {'class':'th'}, h); }))].concat(rows))]) : E('p',{'class':'lk-empty-line'},lk.text("目前没有可显示的版本。"))])])
  ]);
 },
 handleSave:null, handleSaveApply:null, handleReset:null
});
