'require lanekeep.foundation as foundation';
'require lanekeep.i18n as lk';
"use strict";
'require baseclass';
'require rpc';
'require request';
'require ui';

/* LuCI keeps menus for the login session. Invalidate an older panel menu once;
 * the next normal navigation fetches the installed LaneKeep menu without losing drafts. */
if (ui.menu && typeof ui.menu.load === 'function') {
 ui.menu.load().then(function(tree) {
  var branch = tree && tree.children && tree.children.admin &&
   tree.children.admin.children && tree.children.admin.children.services &&
   tree.children.admin.children.services.children && tree.children.admin.children.services.children.lanekeep;
  if (branch && branch.children && (!branch.children.details || branch.title !== 'LaneKeep')) ui.menu.flushCache();
 }).catch(function() { /* Menu refresh must not block a working panel. */ });
}

/* First creation. Explicit draft workflow; no LuCI UCI commit or service action. */
var methods = {};
var lanInfo=null;
[
 ['status', ['job_id']], ['validate', ['draft']], ['apply', ['draft_id', 'confirm', 'trial_ack']],
 ['versions', []], ['rollback', ['version_id', 'scope']], ['exit_check', []],
 ['nodes', ['offset','revision']], ['sub_list', []], ['sub_save', ['draft']], ['sub_refresh', ['draft']], ['sub_diff', ['draft']], ['capabilities', []], ['node_validate', ['draft']], ['node_test', ['id','front','udp','expected_ip','chain_id','trial_ack']], ['trial_confirm',['receipt_id','confirm_verified']]
].forEach(function(m) {
 var call = rpc.declare({ object: 'lanekeep', method: m[0], params: m[1], expect: { '': {} } });
 methods[m[0]]=['status','versions','nodes','capabilities','sub_list'].indexOf(m[0])>=0?function(){var args=arguments;return foundation.firstRead(m[0],function(){return call.apply(null,args);});}:call;
});
// Preserve source-list failures instead of converting nonzero ubus replies to {}.
// Return only fixed diagnostic categories; raw exception text may contain private data.
var sourceListRPC=rpc.declare({object:'lanekeep',method:'sub_list',params:[],expect:{'':{}},reject:true});
methods.sub_list=function(){return foundation.firstRead('sub_list',function(){return sourceListRPC();}).then(function(r){
 if(r&&r.ok===true&&Array.isArray(r.sources)&&typeof r.revision==='string')return r;
 if(r&&r.ok===false){
  if(r.code==='request'||/已有.*处理中|已有.*刷新/.test(r.message||''))return {ok:false,code:'source_busy'};
  if(r.code==='internal')return {ok:false,code:'source_storage'};
  return {ok:false,code:'source_backend'};
 }
 return {ok:false,code:'source_response'};
}).catch(function(e){var m=String(e&&e.message||'');
 return {ok:false,code:/ubus code 6:|error -32002:|HTTP error (401|403):/.test(m)?'source_permission':/ubus code [34]:/.test(m)?'source_method':/timeout|timed out|ubus code 7:/i.test(m)?'source_timeout':'source_transport'};
});};
// A subscription request has a 60-second worker deadline. Use a local transport
// instance, preserving the existing session, ACL and interceptors; no global timeout change.
var subscriptionRPC=Object.create(rpc);
subscriptionRPC.call=function(message,callback){return request.post(rpc.getBaseURL(),message,{timeout:65000,nobatch:true,credentials:true}).then(callback,callback);};
// Three bounded chain steps share this scoped transport; no global timeout change.
methods.node_test=subscriptionRPC.declare({object:'lanekeep',method:'node_test',params:['id','front','udp','expected_ip','chain_id','trial_ack'],expect:{'':{}}});
methods.sub_refresh=subscriptionRPC.declare({object:'lanekeep',method:'sub_refresh',params:['draft'],expect:{'':{}}});
var normalNodeValidate=methods.node_validate,subscriptionValidate=subscriptionRPC.declare({object:'lanekeep',method:'node_validate',params:['draft'],expect:{'':{}}});
methods.node_validate=function(draft){var value;try{value=JSON.parse(draft);}catch(e){return normalNodeValidate(draft);}return value.operation==='import_preview'&&value.subscription_url?trialConsent(lk.text("本次将拉取订阅并生成导入预览。"),function(){value.trial_ack=true;return subscriptionValidate(JSON.stringify(value));}):normalNodeValidate(draft);};
['sub_save','sub_refresh'].forEach(function(name){var call=methods[name];methods[name]=function(draft){return trialConsent(name==='sub_refresh'?lk.text("本次手动刷新订阅缓存。"):lk.text("本次修改订阅来源。"),function(){var value=JSON.parse(draft);value.trial_ack=true;return call(JSON.stringify(value));});};});
var rawNodeTest=methods.node_test;
methods.node_test=function(id,front,udp,expected,chainId){return methods.nodes().then(function(reply){var item=(reply.nodes||[]).find(function(n){return n.id===id;});if(!item)throw new Error('node_not_found');var needs=item.capability_status==='trial'||item.protocol==='chain'||front||udp;return needs?trialConsent(lk.text("本次只测试所选节点或两跳链；成功不会自动升级验证状态。"),function(){return rawNodeTest(id,front,udp,expected,chainId,true);}):rawNodeTest(id,front,udp,expected,chainId,false);});};
// The node picker still receives a complete, revision-bound list, via bounded RPC pages.
var nodePage=methods.nodes;
methods.nodes=function(){
 var result=null,seen={},pages=0;
 function next(offset,revision){if(++pages>128||seen[offset])return Promise.reject(new Error('node_page_invalid'));seen[offset]=true;
  return nodePage(offset,revision||'').then(function(r){if(!r||!r.ok)return r;if(!Array.isArray(r.nodes)||r.nodes.length>50||r.offset!==offset||r.total>64)throw new Error('node_page_shape');
   if(!result)result=Object.assign({},r,{nodes:[]});else if(r.revision!==result.revision||r.uci_revision!==result.uci_revision||r.default_node!==result.default_node||r.total!==result.total)throw new Error('node_page_changed');
   result.nodes=result.nodes.concat(r.nodes);if(result.nodes.length>64)throw new Error('node_page_limit');
   if(r.next!==null){if(!Number.isInteger(r.next)||r.next<=offset)return Promise.reject(new Error('node_page_cursor'));return next(r.next,r.revision);}
   if(result.nodes.length!==r.total)throw new Error('node_page_incomplete');result.next=null;return result;
  });
 }
 return next(0,'');
};
// Rule groups. The direct group has no rules: everything it captures leaves directly.
var groups = [ 'standard', 'global', 'enhanced', 'ondemand' ];
var memberGroups = [ 'global', 'enhanced', 'ondemand', 'standard', 'direct' ];
var labels = { standard: lk.text("常规"), global: lk.mode('global'), enhanced: lk.text("增强"), ondemand: lk.text("按需"), direct: lk.mode('direct') };
var actions = { proxy: lk.text("代理（默认节点）"), direct: lk.text("直连"), block: lk.text("阻断"), node: lk.text("指定节点") };
var types = { domain: lk.text("域名及子域"), full: lk.text("完整域名"), keyword: lk.text("关键词"), ip: lk.language==='en'?'IP / network':'IP / 网段', dedicated:lk.text("专用入口"), geosite:lk.text("广告域名库") };
var pendingKey = 'lanekeep.pending.draft';
var memoryPending = null;
var active = false;
var terminal = ['done', 'success', 'succeeded', 'applied', 'members_applied', 'failed', 'error', 'rolled_back', 'rejected'];

function pending(value) {
 if (arguments.length) {
  memoryPending = value;
  try { if (value) sessionStorage.setItem(pendingKey, value); else sessionStorage.removeItem(pendingKey); } catch (e) {}
 }
 try { return sessionStorage.getItem(pendingKey) || memoryPending; } catch (e) { return memoryPending; }
}
function text(value, fallback) { return value == null ? (fallback || '—') : String(value); }
function node(tag, value) { return E(tag, {}, text(value)); }
function resultLabel(value) {
 if (value === 'restored') return lk.text("已恢复");
 if (value === 'partial_restore') return lk.text("仅部分恢复，请检查结果");
 var map = { applied:lk.text("规则已应用"), members_applied:lk.text("分组已应用"), metadata_applied:lk.text("配置已保存（无需重启）"), unchanged:lk.text("无变化"), rolled_back:lk.text("失败后已回退"), members_rolled_back:lk.text("分组失败后已回退"), members_rollback_failed:lk.text("分组回退失败，需检查"), failed_blocked:lk.text("应用失败，保持阻断"), failed:lk.text("失败"), rejected:lk.text("已拒绝"), running:lk.text("进行中"), queued:lk.text("等待执行"), success:lk.text("成功"), succeeded:lk.text("成功"), done:lk.text("已结束"), snapshot:lk.text("应用前快照"), unknown:lk.text("未记录") };
 return map[value] || (value ? lk.text("结果待核对") : lk.text("未记录"));
}
function utc(value){return foundation.time.marker(value);}
function message(value) { return E('p', {}, text(value)); }
function notice(value, warning) { return E('div', { 'class': warning ? 'alert-message warning' : 'alert-message notice' }, [message(value)]); }
function testDuration(result) {
 if (result && result.status === 'timeout') return lk.text("超时");
 if (!result || !result.ok) return lk.text("失败");
 // v3: latency on an established tunnel (best of two); the first request includes the node handshake.
 if (result.measurement_version !== 3) return lk.text("旧测量结果，请重新测试");
 var en=lk.language==='en', ms=result.elapsed_ms, first=result.connect_ms;
 if (typeof ms !== 'number' || !isFinite(ms) || ms < 0) return lk.text("耗时未取得");
 var text=(en?'Latency ':'延迟 ')+ms+' ms';
 if (result.latency_basis === 'first_request') return text+(en?' (first request, handshake included)':'（首次请求，含握手）');
 if (typeof first === 'number' && isFinite(first) && first >= 0) text+=(en?' · first connection ':' · 首次连接 ')+first+' ms';
 return text;
}
function duration(seconds) {
 if (typeof seconds !== 'number' || !isFinite(seconds) || seconds < 0) return lk.text("未知");
 var s = Math.floor(seconds);
 return Math.floor(s / 3600) + lk.text(" 小时 ") + Math.floor(s % 3600 / 60) + lk.text(" 分 ") + s % 60 + lk.text(" 秒");
}
function optionSelect(values, value, onChange) {
 var select = E('select', { 'class':'cbi-input-select', 'change': function() { onChange(this.value); } }, Object.keys(values).map(function(key) { return E('option', { value:key }, values[key]); }));
 select.value = value;
 return select;
}
function button(label, click, primary) {
 return E('button', { type:'button', 'class':'cbi-button ' + (primary ? 'cbi-button-apply' : 'cbi-button-neutral'), click:click }, label);
}
function errorList(target, errors, fields) {
 while (target.firstChild) target.removeChild(target.firstChild);
 (target._marked || []).forEach(function(el) { el.removeAttribute('aria-invalid'); });
 target._marked = [];
 var visible = !!(errors && errors.length);
 target.hidden = !visible;
 target.setAttribute('aria-hidden', String(!visible));
 if (visible) target.removeAttribute('hidden'); else target.setAttribute('hidden','');
 if (!visible) return;
 target.appendChild(E('strong', {}, lk.text("校验未通过，尚未应用：")));
 target.appendChild(E('ul', {}, errors.map(function(error) {
  var field = String(error.field || 'draft').replace(/\[(\d+)\]/g, '.$1');
  var control = fields && fields[field];
  if (control) { control.setAttribute('aria-invalid','true'); target._marked.push(control); }
  return E('li', {}, [ E('a', { href:'#', click:function(ev) { ev.preventDefault(); if (control) control.focus(); } }, (control && control._fieldLabel ? control._fieldLabel : ({draft:lk.text("草稿"),revision:lk.text("配置版本"),scope:lk.text("改动类型"),members:lk.text("设备分组"),'members.global':lk.text("全局分组"),'members.enhanced':lk.text("增强分组"),'members.ondemand':lk.text("按需分组"),rules:lk.text("规则"),version_id:lk.text("版本编号"),job_id:lk.text("任务编号")})[field] || field) + '：' + text(error.message, lk.text("输入无效"))) ]);
 })));
 if (target._marked.length) {var parent=target._marked[0].parentElement;while(parent&&parent!==target.parentElement){if(parent.tagName==='DETAILS')parent.open=true;parent=parent.parentElement;}target._marked[0].focus();}
}
function trialConsent(detail,action){
 return new Promise(function(resolve,reject){var checked=false,go=button(lk.text("确认未验证试用"),function(){if(!checked)return;go.disabled=true;ui.hideModal();Promise.resolve().then(action).then(resolve,reject);},true);go.disabled=true;
  foundation.modal(ui,lk.text("未验证试用"),[notice(detail,true),message(lk.text("真实节点、链式行为和客户端效果尚需验收；本次确认不会自动标为已验证。")),E('label',{},[E('input',{type:'checkbox',change:function(){checked=this.checked;go.disabled=!checked;}}),lk.text(" 我确认进行未验证试用")]),E('div',{'class':'right'},[button(lk.text("取消"),function(){ui.hideModal();resolve({ok:false,cancelled:true,message:lk.text("已取消未验证试用操作")});}),go])]);
 });
}
function confirmVerification(result){
 if(!result||!result.ok||!result.verification_receipt)return;
 var checked=false,go=button(lk.text("确认验证通过"),function(){if(!checked)return;go.disabled=true;methods.trial_confirm(result.verification_receipt,true).then(function(reply){if(!reply.ok){showFailure(reply.message||lk.text("确认未提交，请重新测试"));return;}ui.hideModal();window.location.reload();}).catch(function(){showFailure(lk.text("确认结果未知，请刷新读取状态；未自动重试。"));});},true);go.disabled=true;
 foundation.modal(ui,lk.text("由你确认验证结果"),[message(lk.text("本次成功连接测试已完成。只把本次测试涉及的协议组合或具体链记录为 verified；这不代表全部服务端、防泄露或故障场景通过。")),message(lk.text("确认有效期为20分钟；节点、配置、能力版本或登录会话变化后须重新测试。")),E('label',{},[E('input',{type:'checkbox',change:function(){checked=this.checked;go.disabled=!checked;}}),lk.text(" 我已核对真实节点的测试结果，确认验证通过")]),E('div',{'class':'right'},[button(lk.text("暂不确认"),ui.hideModal),go])]);
}
function showFailure(value) {
 foundation.modal(ui,lk.text("操作未完成"), [message(value), E('div', {'class':'right'}, [button(lk.text("关闭"), ui.hideModal)])]);
}
function ruleText(r) {
 if (!r) return lk.text("规则");
 return (labels[r.group] || '') + ' · ' + (types[r.type] || lk.text("规则")) + ' ' + text(r.value, '') + ' → ' + (r.action === 'node' ? lk.text("指定节点 ") + text(r.node_name || r.node, '') : (r.action==='proxy' && r.type!=='dedicated'?lk.text("本组代理节点"):actions[r.action] || '')) + (r.enabled === '0' ? lk.text("（停用）") : '');
}
function summaryNodes(summary) {
 if (typeof summary === 'string') return message(summary);
 summary = summary || {};
 var lines = [];
  function fallbackName(f){return f.action==='direct'?lk.text("直连"):f.action==='proxy'?lk.text("本组代理节点"):lk.text("指定节点 ")+text(f.node);}
  (summary.group_node_changes || []).forEach(function(c){lines.push((labels[c.group] || c.group)+lk.text("组代理节点：")+(c.before || lk.text("全局默认"))+' → '+(c.after || lk.text("全局默认")));});
  (summary.fallback_changes || []).forEach(function(c){lines.push((labels[c.group] || c.group)+lk.text("组兜底出口：")+fallbackName(c.before)+' → '+fallbackName(c.after));});
  if(summary.unassigned_change){var uc=summary.unassigned_change;lines.push((lk.language==='en'?'Devices without a mode: ':'未分组设备：')+(labels[uc.before] || uc.before)+' → '+(labels[uc.after] || uc.after));}
  if(summary.real_dns_change){var dc=summary.real_dns_change;lines.push(lk.text("不使用假 IP 的域名："));lines.push(lk.text("原列表：")+(dc.before.join('、') || lk.text("空")));lines.push(lk.text("新列表：")+(dc.after.join('、') || lk.text("空")));}
 var before = {}, after = {}, touched = {}, implicit = summary.unassigned === 'direct' ? 'direct' : 'standard';
 (summary.member_changes || []).forEach(function(change) {
  if (change.ip) {
   lines.push(text(change.ip, '') + '：' + (labels[change.before || change.from] || labels[implicit]) + ' → ' + (labels[change.after || change.to] || labels[implicit]));
   return;
  }
  (change.before || []).forEach(function(ip) { before[ip] = change.group; touched[ip] = true; });
  (change.after || []).forEach(function(ip) { after[ip] = change.group; touched[ip] = true; });
 });
 Object.keys(touched).sort().forEach(function(ip) {
  if ((before[ip] || implicit) !== (after[ip] || implicit)) lines.push(ip + '：' + labels[before[ip] || implicit] + ' → ' + labels[after[ip] || implicit]);
 });
 (summary.added || []).forEach(function(rule) { lines.push(lk.text("新增：") + ruleText(rule)); });
 (summary.removed || []).forEach(function(rule) { lines.push(lk.text("删除：") + ruleText(rule)); });
 (summary.changed || []).forEach(function(rule) {
  lines.push(lk.text("修改：") + ruleText(rule.before) + lk.text("；改为 ") + ruleText(rule.after));
  if (rule.before && rule.after && rule.before.note !== rule.after.note) lines.push(lk.text("备注：") + text(rule.before.note, lk.text("空")) + ' → ' + text(rule.after.note, lk.text("空")));
 });
 (summary.node_changes || []).forEach(function(change) { lines.push(typeof change === 'string' ? change : lk.text("节点：") + text(change.name || change.id) + ' · ' + text(change.action || change.change) + (change.server ? ' · ' + text(change.protocol) + ' · ' + change.server + ':' + change.port : '')); });
 (summary.affected_chains||[]).forEach(function(c){lines.push(lk.text("受影响链：")+text(c.name)+' ['+text(c.id)+']；'+(c.role==='front'?lk.text("前置"):lk.text("后置"))+' '+text(c.dependency_id)+lk.text("；变更字段：")+(c.fields||[]).join('、'));});
 (summary.udp_invalidated||[]).forEach(function(c){lines.push(lk.text("UDP 失效：")+text(c.name)+' ['+text(c.id)+']；'+text(c.action));});
 if (summary.default_node_change) { var dc=summary.default_node_change; lines.push(lk.text("默认节点：") + text(dc.before_name || dc.before) + ' → ' + text(dc.after_name || dc.after)); }
 if (summary.order_changed) lines.push(lk.text("规则顺序有变化，请按当前表格顺序确认。"));
 if (!lines.length) lines.push(lk.text("没有规则、分组或节点内容变化；备注等信息变化以校验结果为准。"));
 return E('ul', {}, lines.map(function(line) { return E('li', {}, line); }));
}
function jobFinished(job) { return !!job && terminal.indexOf(job.state) >= 0; }
function clearIfFinished(reply) {
 if (reply && reply.ok && jobFinished(reply.job)) pending(null);
 return reply;
}
function finishModal(reply, onSuccess) {
 var job = reply.job || {};
 var success = ['done','success','succeeded','applied','members_applied'].indexOf(job.state) >= 0 && ['failed','rolled_back','rejected'].indexOf(job.result) < 0;
 foundation.modal(ui,success ? lk.text("应用已结束") : lk.text("应用结果"), [
  message(resultLabel(job.result || job.state)),
  message(job.message || lk.text("请根据状态页核对结果。")),
  notice(lk.text("以上是本次应用任务结果。新节点实际握手、出口和终端业务需另行核对；第一轮第5步已按用户现场验收通过记录。")),
  E('div', {'class':'right'}, [button(lk.text("关闭并刷新"), function() { ui.hideModal(); if (onSuccess) onSuccess(); else window.location.reload(); })])
 ]);
}
function inspectJob(id, onSuccess, attempt) {
 attempt = attempt || 0;
 return methods.status(id).then(function(reply) {
  clearIfFinished(reply);
  if (!reply.ok || !reply.job) throw new Error('status_unavailable');
  if (jobFinished(reply.job)) { active = false; finishModal(reply, onSuccess); return reply; }
  if (attempt < 44) return new Promise(function(resolve) { window.setTimeout(resolve, 2000); }).then(function() { return inspectJob(id, onSuccess, attempt + 1); });
  active = false;
  foundation.modal(ui,lk.text("任务仍待确认"), [notice(lk.text("任务尚未给出最终结果。请查询状态，不要再次提交。"), true), E('div', {'class':'right'}, [button(lk.text("关闭"), ui.hideModal), button(lk.text("查询任务状态"), function() { active = true; inspectJob(id, onSuccess, 0); }, true)])]);
  return reply;
 }).catch(function() {
  active = false;
  foundation.modal(ui,lk.text("暂时无法取得结果"), [notice(lk.text("提交结果尚未确认。页面保留了原任务编号，请只查询状态，不要重复应用。"), true), E('div', {'class':'right'}, [button(lk.text("关闭"), ui.hideModal), button(lk.text("查询任务状态"), function() { active = true; inspectJob(id, onSuccess, 0); }, true)])]);
 });
}
function applyValidated(validated, onSuccess) {
 if (active || pending()) { showFailure(lk.text("已有任务未确认。请先查询该任务状态。")); return Promise.resolve(); }
 active = true;
 pending(validated.draft_id);
 foundation.modal(ui,lk.text("正在应用"), [message(lk.text("正在执行已确认的应用。网络可能暂时不可用；结果未知时只查询原任务。"))]);
 return methods.apply(validated.draft_id, validated.change_kind === 'restore' ? 'restore' : validated.change_kind === 'rules' ? 'rules' : validated.change_kind === 'unchanged' ? 'unchanged' : 'members', validated.trial_ack===true).then(function(reply) {
  if (reply && reply.not_started === true && reply.uncertain !== true) {
   active = false; pending(null); showFailure(reply.message || lk.text("应用未开始，请重新校验草稿。")); return;
  }
  // A bridge error can occur after queue acceptance. Only an explicit not_started
  // acknowledgement clears the pending marker; all ambiguous replies read back
  // this same draft ID and never send a second apply.
  return inspectJob(validated.draft_id, onSuccess, 0);
 }).catch(function() { return inspectJob(validated.draft_id, onSuccess, 0); });
}
function confirmValidated(result, onSuccess, context) {
 if (!result.ok || !result.draft_id || ['rules','members','metadata','unchanged','restore'].indexOf(result.change_kind) < 0) { showFailure(lk.text("校验失败，未生成可应用草稿。")); return; }
 if (!result.impact || typeof result.impact.restart_required !== 'boolean' || (result.change_kind !== 'restore' && result.impact.restart_required !== (result.change_kind === 'rules'))) { showFailure(lk.text("改动类型与影响说明不一致，未发送应用。")); return; }
 if (result.change_kind === 'unchanged') { showFailure(lk.text("草稿与当前配置相同，无需应用。")); return; }
 var restart = result.impact && result.impact.restart_required;
 var contextParts=document.body.dataset.page==='admin-services-lanekeep-nodes'&&typeof context==='string'?context.split(/｜| \| /):null;
 var content=contextParts&&contextParts.length>1?contextParts.map(function(line,i){return E(i?'small':'p',{},line);}):[message(context || lk.text("确认以下实际改动："))];
 if (result.restore && result.restore.whole_state) {
  content.push(notice(result.restore.message, true));
  content.push(E('h4', {}, lk.text("以下后续操作也会被撤销")));
  var later = result.restore.later_operations || [];
  content.push(later.length ? E('ul', {}, later.map(function(op) { return E('li', {}, utc(op.time_utc) + ' · ' + text(op.summary) + ' · ' + resultLabel(op.result)); })) : message(lk.text("未查到后续已应用操作。")));
  if (!result.restore.history_complete) content.push(notice(lk.text("历史记录不完整，无法列全后续操作；请逐项核对下面的实际差异。"), true));
 }
 content.push(summaryNodes(result.summary));
 (result.impact.entry_warnings || []).forEach(function(w){content.push(notice(w,true));});
  (result.impact.settings_warnings || []).forEach(function(w){content.push(notice(w,true));});
 content.push(notice(restart ? lk.text("本次将重启核心，全家网络预计中断约10秒（估计值，实际待测）。应用最多等待60秒门控 OPEN；失败自动退回可能再重启一次并等待最多60秒。若原节点也不通，代理流量仍会保持阻断。") : lk.text("本次不重启核心。未使用节点或备注变动只更新保存的信息；分组变动只影响新连接。"), restart));
 if (result.change_kind === 'restore') content.push(notice(lk.text("一次确认后按顺序处理：先恢复有差异的分组，再恢复规则和节点（含默认节点选择）。生成配置没有变化时跳过核心重启；结果会说明每一步是否完成。")));
  var applyButton=button(result.change_kind === 'restore' ? (restart ? lk.text("确认恢复并重启核心") : lk.text("确认恢复")) : restart ? lk.text("确认重启核心并应用") : lk.text("确认应用"), function() { if(result.trial_required&&result.trial_ack!==true)return;ui.hideModal();applyValidated(result,onSuccess); },true);
  if(result.trial_required){result.trial_ack=false;applyButton.disabled=true;content.push(notice(lk.text("未验证试用：节点和链的真实连通、出口及故障阻断需由你验收。"),true));content.push(E('label',{},[E('input',{type:'checkbox',change:function(){result.trial_ack=this.checked;applyButton.disabled=!this.checked;}}),lk.text(" 我确认使用未验证试用功能")]));}
  content.push(E('div', {'class':'right'}, [button(lk.text("取消"), ui.hideModal),applyButton]));
 foundation.modal(ui,lk.text("校验通过，请确认影响"), content);
}
function validateDraft(draft, errorBox, fields, onSuccess) {
 if (active || pending()) { showFailure(lk.text("已有任务未确认。请先查询该任务状态。")); return Promise.resolve(); }
 errorList(errorBox, [], fields);
 active = true;
 return methods.validate(JSON.stringify(draft)).then(function(reply) {
  active = false;
  if (!reply.ok) { errorList(errorBox, reply.errors || [{field:'draft',message:reply.message || lk.text("草稿校验失败")}], fields); return reply; }
  confirmValidated(reply, onSuccess);
  return reply;
 }).catch(function() { active = false; errorList(errorBox, [{field:'draft',message:lk.text("未取得校验结果，未发送应用。请稍后重试校验。")}], fields); });
}
function regText(browser, port, enabled) {
 if (['chrome','edge'].indexOf(browser) < 0 || enabled && (!/^108[1-6][0-9]$/.test(String(port)) || Number(port)<10811 || Number(port)>10860)) throw new Error('invalid_registry_download');
 var path = browser === 'chrome' ? 'Google\\Chrome' : 'Microsoft\\Edge';
 var value = enabled ? JSON.stringify({ProxyMode:'fixed_servers', ProxyServer:'socks5://' + (lanInfo&&lanInfo.address||window.location.hostname) + ':' + port, ProxyBypassList:'<local>;' + (lanInfo&&lanInfo.subnet||window.location.hostname)}) : null;
 function quoted(v) { return '"' + v.replace(/\\/g,'\\\\').replace(/"/g,'\\"') + '"'; }
 return 'Windows Registry Editor Version 5.00\r\n\r\n[HKEY_LOCAL_MACHINE\\SOFTWARE\\Policies\\' + path + ']\r\n"ProxySettings"=' + (enabled ? quoted(value) : '-') + '\r\n';
}
function downloadReg(browser, port, enabled) {
 var content=regText(browser,port,enabled),bytes=new Uint8Array(2+content.length*2);
 bytes[0]=255;bytes[1]=254;
 for(var i=0;i<content.length;i++){var c=content.charCodeAt(i);bytes[2+i*2]=c&255;bytes[3+i*2]=c>>8;}
 var url=URL.createObjectURL(new Blob([bytes],{type:'application/octet-stream'}));
 var a=E('a',{href:url,download:'lanekeep-'+browser+'-'+(enabled?'enable-'+port:'disable')+'.reg'});
 document.body.appendChild(a);a.click();a.remove();window.setTimeout(function(){URL.revokeObjectURL(url);},1000);
}
function entryWarning(proceed) {
 foundation.modal(ui,lk.text("请先关闭浏览器专用入口"), [notice(lk.text("停用、删除或改变入口前，请先在增强运行该浏览器的“关闭”文件，否则该浏览器可能无法上网。此处只修改草稿，校验并确认后才会生效。"),true), E('div',{'class':'right'},[button(lk.text("取消"),ui.hideModal),button(lk.text("已了解，修改草稿"),function(){ui.hideModal();proceed();},true)])]);
}
function pendingNotice(onSuccess) {
 var id = pending();
 if (!id) return E('div');
 return E('div', {'class':'alert-message warning'}, [message(lk.text("有一项提交尚未确认结果。请先查询状态，避免重复应用。")), button(lk.text("查询原任务状态"), function() { if (!active) { active = true; inspectJob(id, onSuccess, 0); } }, true)]);
}
function loadStatus() { return methods.status('').then(function(reply) { if (!reply.ok) throw new Error('lanekeep_status'); lanInfo=reply.lan||lanInfo; return reply; }); }
function loadFailure() { return notice(lk.text("无法读取分流管理状态。请确认管理员已登录且管理接口可用；未发送任何配置改动。"), true); }
function bindField(fields, key, element, label) { fields[key] = element; element._fieldLabel = label; return element; }

return baseclass.extend({
 groups:groups, memberGroups:memberGroups, labels:labels, actions:actions, types:types, rpc:methods, confirmVerification:confirmVerification, trialConsent:trialConsent,
 regText:regText, downloadReg:downloadReg, entryWarning:entryWarning,
 text:text, utc:utc, node:node, message:message, notice:notice, duration:duration, testDuration:testDuration, select:optionSelect, button:button,
 errors:errorList, showFailure:showFailure, summary:summaryNodes, resultLabel:resultLabel,
 validateDraft:validateDraft, confirmValidated:confirmValidated, pendingNotice:pendingNotice,
 foundation:foundation, showModal:function(title,children){return foundation.modal(ui,title,children);}, loadStatus:loadStatus, loadFailure:loadFailure, bindField:bindField,
 hasPending:function() { return active || !!pending(); }
});
