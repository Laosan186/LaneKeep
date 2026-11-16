 'use strict';
'require baseclass';
'require uci';
'require lanekeep.i18n as i18n';
'require lanekeep.time as time';
var version='20261116-style-r2', root=null, observed=new WeakSet(), stylesheet=null;
var initial=new Map(), errors=new Set(), scheduled=false;
function styles(){
 if(stylesheet)return stylesheet;
 var href=L.resource('lanekeep/panel.css');href+=(href.indexOf('?')<0?'?':'&')+'v='+version;
 var links=Array.prototype.slice.call(document.querySelectorAll('link[href*="/lanekeep/panel.css"]'));
 var link=document.getElementById('lanekeep-styles')||links[0]||document.createElement('link');
 links.forEach(function(other){if(other!==link)other.remove();});
 link.id='lanekeep-styles';link.rel='stylesheet';
 stylesheet=new Promise(function(resolve,reject){
  link.addEventListener('load',resolve,{once:true});
  link.addEventListener('error',function(){reject(new Error('LaneKeep stylesheet failed to load'));},{once:true});
  if(link.getAttribute('href')!==href)link.href=href;
  if(!link.isConnected)document.head.appendChild(link);
  if(link.sheet)resolve();
 });
 return stylesheet;
}
function mount(container){
 styles();root=container||document.getElementById('view');
 if(!root)return null;
 root.classList.add('lanekeep-root');root.dataset.page=document.body.dataset.page||'';
 root.dataset.lanekeepVersion=version;
 if(!observed.has(root)){new MutationObserver(schedule).observe(root,{subtree:true,childList:true,characterData:true});observed.add(root);}
 schedule();return root;
}
var ready=Promise.all([styles(),Promise.resolve().then(function(){return uci.load('system');}).then(function(){time.configure(uci.sections('system','system')[0]||{});},function(){time.configure({});})]);
function firstRead(key,read){var first=!initial.has(key);initial.set(key,true);var p=Promise.resolve().then(read).then(check);if(first)p=p.catch(function(){return Promise.resolve().then(read).then(check);});return p.then(function(r){errors.delete(key);schedule();return r;},function(e){errors.add(key);schedule();throw e;});}
function check(r){if(!r||r.ok===false)throw new Error('read_failed');return r;}
function decorate(){
 if(root&&root.isConnected){
  time.decorate(root);
  var bar=root.querySelector('[data-lk-read-error]');
  if(errors.size&&!bar){bar=E('div',{'class':'lk-error',role:'alert','data-lk-read-error':''},[E('span',{},i18n.text('读取失败，请重试。')),E('button',{type:'button','class':'cbi-button',click:function(){window.location.reload();}},i18n.text('重试'))]);root.prepend(bar);}else if(!errors.size&&bar)bar.remove();
 }
 document.querySelectorAll('.modal.lanekeep-root').forEach(function(d){time.decorate(d);});
}
function schedule(){if(scheduled)return;scheduled=true;queueMicrotask(function(){scheduled=false;decorate();});}
function modal(ui,title,children,classes){var d=ui.showModal(title,children,...(classes||[]));d.classList.add('lanekeep-root');if(document.body.dataset.page==='admin-services-lanekeep-nodes'){d.classList.add('lk-node-dialog');if(d.querySelector('input:not([type=checkbox]),select,textarea,table'))d.classList.add('lk-node-dialog-form');}new MutationObserver(schedule).observe(d,{subtree:true,childList:true,characterData:true});schedule();return d;}
// Every real LuCI view enters here; the preview must use the same view constructor.
function view(base,definition){
 var spec=Object.assign({},definition),load=spec.load,render=spec.render;
 spec.load=function(){mount();var result=load?load.apply(this,arguments):undefined;return Promise.all([ready,result]).then(function(a){return a[1];});};
 spec.render=function(){mount();var result=render?render.apply(this,arguments):undefined;schedule();return result;};
 return base.extend(spec);
}
mount();document.addEventListener('DOMContentLoaded',function(){mount();},{once:true});document.addEventListener('luci-loaded',function(){mount();},{once:true});ready.then(schedule);
setInterval(schedule,30000);
var exported={ready:ready,firstRead:firstRead,modal:modal,time:time,i18n:i18n,mount:mount,view:view,version:version};
return baseclass.extend({__init__:function(){Object.assign(this,exported);}});
