'use strict';
'require baseclass';
'require rpc';
'require ui';
'require lanekeep.i18n as lk';
var change=rpc.declare({object:'lanekeep',method:'lifecycle',params:['action','confirm'],expect:{'':{}},reject:true});
function render(data){
 var active=!!(data.lifecycle&&data.lifecycle.enabled),en=lk.language==='en';
 var title=active?(en?'LaneKeep is enabled':'LaneKeep 已启用'):(en?'LaneKeep is disabled':'LaneKeep 尚未启用');
 var description=active?(en?'You can disable interception and restore the previous DNS settings here.':'可在此停止接管并恢复启用前的 DNS 设置。'):(en?'Adding nodes and saving rules does not affect your network. Select a default node, disable LAN IPv6, then explicitly enable LaneKeep.':'添加节点和保存规则不会改变网络。请选择默认节点、关闭 LAN IPv6，再明确启用 LaneKeep。');
 var button=E('button',{'class':'cbi-button cbi-button-action',type:'button',disabled:!active&&!data.default_node,click:function(){
  var body=E('p',{},active?(en?'Disable LaneKeep and restore DNS and routing?':'停用 LaneKeep 并恢复 DNS 与路由？'):(en?'Enable traffic interception, protected DNS and the kill switch for the configured LAN? Existing connections may be interrupted.':'启用所选 LAN 的流量接管、受保护 DNS 和断线保护？现有连接可能短暂中断。'));
  ui.showModal(title,[body,E('div',{'class':'right'},[
   E('button',{'class':'cbi-button',click:ui.hideModal},en?'Cancel':'取消'),
   E('button',{'class':'cbi-button cbi-button-action',click:function(ev){ev.currentTarget.disabled=true;change(active?'disable':'enable',active?'DISABLE':'ENABLE').then(function(r){if(!r.ok)throw Error(r.message||'Action failed');ui.hideModal();window.location.reload();}).catch(function(e){body.textContent=e.message;ev.currentTarget.disabled=false;});}},active?(en?'Disable':'确认停用'):(en?'Enable':'确认启用'))
  ])]);
 }},active?(en?'Disable':'停用'):(en?'Enable LaneKeep':'启用 LaneKeep'));
 return E('section',{'class':'lk-card lk-activation','data-enabled':String(active)},[E('h3',{},title),E('p',{},description),button]);
}
return baseclass.extend({render:render});
