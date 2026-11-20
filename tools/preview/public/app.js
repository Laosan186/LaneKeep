'use strict';
window._=function(s){return s;};
String.prototype.format=function(){var args=arguments,i=0;return this.replace(/%[sd]/g,function(){return args[i++];});};
// Compatibility layer limited to the primitives these unchanged LuCI modules use.
window.E=function(tag,attrs,children){
 if(Array.isArray(tag)){const f=document.createDocumentFragment();tag.forEach(x=>f.append(x));return f;}
 if(attrs==null||typeof attrs!=='object'||Array.isArray(attrs)||attrs instanceof Node){children=attrs;attrs={};}
 const el=document.createElement(tag);
 Object.entries(attrs).forEach(([k,v])=>{if(v==null||v===false)return;if(typeof v==='function')el.addEventListener(k,v);else el.setAttribute(k,v===true?'':String(v));});
 function append(v){if(v==null)return;if(Array.isArray(v))v.forEach(append);else el.appendChild(v instanceof Node?v:document.createTextNode(String(v)));}append(children);return el;
};
const params=new URLSearchParams(location.search); document.documentElement.lang=params.get('lang')==='en'?'en':'zh-CN'; const pages={status:'状态',devices:'设备分组',rules:'规则',nodes:'节点',details:'详细数据',versions:'版本'};
const language=params.get('lang')==='en'?'en':'zh',shellTr=(zh,en)=>language==='en'?en:zh;
let page=pages[params.get('page')]?params.get('page'):'status',theme=params.get('theme')==='dark'?'dark':'light';
if(params.get('modal'))page='nodes';
if(params.has('capture'))document.body.classList.add('capture');
document.body.dataset.page='admin-services-lanekeep-'+page;
function pageURL(id){const p=new URLSearchParams({page:id,theme,lang:language,scenario:params.get('scenario')||'normal'});if(params.has('capture'))p.set('capture','1');return '?'+p;}
// Same markup luci-theme-argon renders for a firstchild menu node: ul.tabs > li.tabmenu-item-<name>[.active] > a.
document.querySelector('#tabmenu').append(E('ul',{class:'tabs'},Object.entries(pages).map(([id,label])=>E('li',{class:'tabmenu-item-'+id+(page===id?' active':'')},E('a',{href:pageURL(id),'data-page':id,'aria-current':page===id?'page':null},label)))));
document.querySelectorAll('.brand,#sidebar-lanekeep').forEach(a=>a.dataset.page='status');
function refreshLinks(){document.querySelectorAll('a[data-page]').forEach(a=>a.setAttribute('href',pageURL(a.dataset.page)));}
function setTheme(value){theme=value;document.documentElement.dataset.argonMode=value;document.documentElement.setAttribute('data-darkmode',value==='dark');document.documentElement.classList.toggle('dark',value==='dark');refreshLinks();}
setTheme(theme);
const ui={
 menu:{load:()=>Promise.resolve({children:{admin:{children:{services:{children:{lanekeep:{children:{details:{}}}}}}}}}),flushCache:()=>{}},
 showModal(title,children,...classes){const overlay=document.querySelector('#modal_overlay'),dlg=overlay.firstElementChild;dlg.className='modal';dlg.classList.add(...classes);dlg.replaceChildren(E('h4',{id:'modal-title'},title));children.forEach(x=>dlg.append(x));dlg.setAttribute('aria-labelledby','modal-title');document.body.classList.add('modal-overlay-active');overlay.scrollTop=0;overlay.focus();return dlg;},
 hideModal(){document.body.classList.remove('modal-overlay-active');document.querySelector('#modal_overlay').blur();}
};
document.querySelector('#modal_overlay').addEventListener('keydown',e=>{if(e.key==='Escape'){const button=document.querySelector('#modal_overlay .right>button');if(button)button.click();}});

const rpc={declare:def=>(...args)=>window.previewRPC(def.object,def.method,args),getBaseURL:()=>'/mock-rpc'};
const request={post:()=>Promise.reject(new Error('HTTP RPC is disabled in local preview'))};
const real=window.__lkReal;window.L=Object.create(window.LuCI.prototype);L.loaded=true;
real.env.base_url='/luci-static/resources';real.env.lang=document.documentElement.lang;real.env.resource='/luci-static/resources';
L.resource=p=>'/luci-static/resources/'+p;L.hasViewPermission=()=>true;
L.url=(...path)=>{const p=path.join('/').split('/').pop();return pages[p]?pageURL(p):'#preview-only';};
real.classes.ui=Object.assign(ui,{addNotification:(title,node)=>{window.lkOfflineNotifications.push({title:String(title),text:node&&node.textContent||''});}});
window.lkOfflineNotifications=[];real.classes.rpc=rpc;real.classes.request=request;
real.classes.uci={load:function(){return Promise.resolve();},sections:function(){return [{zonename:params.get('tz')||'Asia/Shanghai',timezone:params.has('tz')?'':'CST-8'}];}};
real.Request.get=async url=>{const response=await fetch(url);const source=await response.text();return {ok:response.ok,status:response.status,url,text:()=>source};};
real.Request.post=()=>Promise.reject(new Error('Network RPC forbidden in offline fixture'));
const realViewInit=real.View.prototype.__init__;
real.View.prototype.__init__=function(){window.lkOfflineViewReady=realViewInit.apply(this,arguments);return window.lkOfflineViewReady;};
window.previewLoadModule=loadModule;
async function loadModule(name){return L.require(window.LaneKeepModules[name]||name);}

// Preview-only switches live in the header; ?capture=1 hides them and keeps the LuCI tabs.
if(language==='en'){document.title='LaneKeep · Local preview';document.querySelector('.showSide').setAttribute('aria-label','Toggle navigation');document.querySelector('#preview-controls').setAttribute('aria-label','Local preview controls');var previewWords={'服务':'Services','演示场景':'Demo scenario','场景':'Scenario','弹窗':'Dialog','一切正常':'Normal','异常和报错':'Errors','空列表':'Empty','名称保真检查':'Name fidelity','名称超长':'Long names','18 个节点':'18 nodes','首次读取失败':'First read fails','断线保护已触发':'Kill switch triggered','断线保护未知':'Kill switch unknown','测试失败':'Test failed','实验性节点':'Experimental node','按钮不可用':'Disabled actions','RPC 读取失败':'Read failure','无':'None','新增节点':'Add node','新增两跳链':'Add chain','分享链接 / 订阅导入':'Import','本地假数据 · RPC 仅内存模拟 · 刷新复原':'Demo data · In-memory RPC · Reload to reset','浅色 / 深色':'Light / Dark','浅 / 深':'Theme'};document.querySelectorAll('#preview-controls,#mainmenu').forEach(root=>{var walker=document.createTreeWalker(root,NodeFilter.SHOW_TEXT);while(walker.nextNode()){var text=walker.currentNode,key=text.data.trim();if(previewWords[key])text.data=text.data.replace(key,previewWords[key]);}});}
function navigate(){const p=new URLSearchParams({page,scenario:document.querySelector('#scenario-select').value,theme,lang:language});const modal=document.querySelector('#modal-select').value;if(modal){p.set('page','nodes');p.set('modal',modal);}if(params.has('capture'))p.set('capture','1');location.search=p;}
document.querySelector('#scenario-select').value=params.get('scenario')||'normal';document.querySelector('#modal-select').value=params.get('modal')||'';
['scenario','modal'].forEach(id=>document.querySelector('#'+id+'-select').addEventListener('change',navigate));
document.querySelector('#appearance').addEventListener('click',()=>{setTheme(theme==='dark'?'light':'dark');params.set('theme',theme);history.replaceState(null,'','?'+params);});
document.querySelector('#language').addEventListener('click',()=>{const p=new URLSearchParams(params);p.set('lang',language==='en'?'zh':'en');p.set('theme',theme);location.search=p;});
const demo=document.querySelector('#preview-demo'),demoButton=demo.querySelector('button'),demoPanel=demo.querySelector('.preview-demo-panel');
function toggleDemo(open){demoPanel.hidden=!open;demoButton.setAttribute('aria-expanded',String(open));}
demoButton.addEventListener('click',()=>toggleDemo(demoPanel.hidden));
demo.addEventListener('keydown',e=>{if(e.key==='Escape'&&!demoPanel.hidden){toggleDemo(false);demoButton.focus();}});
// Argon's narrow-screen menu: .showSide opens .main-left.active over .darkMask.active.
const sidebar=document.querySelector('#mainmenu'),mask=document.querySelector('.darkMask');
function toggleMenu(open){sidebar.classList.toggle('active',open);mask.classList.toggle('active',open);}
document.querySelector('.showSide').addEventListener('click',()=>toggleMenu(!sidebar.classList.contains('active')));
mask.addEventListener('click',()=>toggleMenu(false));
document.querySelector('#mainmenu .menu').addEventListener('click',e=>{e.currentTarget.classList.toggle('active');e.currentTarget.nextElementSibling.classList.toggle('active');});
document.addEventListener('click',e=>{if(!demoPanel.hidden&&!demo.contains(e.target))toggleDemo(false);const a=e.target.closest('a');if(a?.getAttribute('href')==='#preview-only'){e.preventDefault();ui.showModal(shellTr('本地预览','Local preview'),[E('p',{},shellTr('此入口属于路由器其他页面，本期预览范围为分流管理六页。','This entry belongs to other router pages. The preview covers the six LaneKeep pages.')),E('div',{class:'right'},E('button',{class:'cbi-button',click:ui.hideModal},shellTr('关闭','Close')))]);}});
const viewModule=window.previewReady.then(()=>loadModule('view.lanekeep.'+page));
// Translate the tabs once the view's modules are cached, so they stay readable even if the view itself fails.
const shellText=viewModule.then(()=>loadModule('lanekeep.i18n')).then(dict=>{document.querySelectorAll('#tabmenu a').forEach(n=>n.textContent=dict.text(n.textContent));return dict;});shellText.catch(()=>{});
(async()=>{
 const module=await viewModule;await window.lkOfflineViewReady;if(window.lkOfflineNotifications.length)throw new Error('Real LuCI View initialization reported an error');
 const dict=await shellText;
 const modal=params.get('modal');if(modal){const label={node:'新增节点',chain:'新增两跳链',import:'导入'}[modal],button=document.querySelector('.lk-page-actions')?.children[{node:3,chain:2,import:1}[modal]]||[...document.querySelectorAll('#view button')].find(b=>b.textContent===dict.text(label));if(!button)throw new Error('Dialog trigger missing');button.click();}
 document.documentElement.dataset.ready='true';
})().catch(e=>{document.querySelector('#view').dataset.error='true';document.querySelector('#view').textContent='本地预览加载失败：'+e.message;console.error(e);document.documentElement.dataset.ready='error';});
