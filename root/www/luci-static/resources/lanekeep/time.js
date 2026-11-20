 'use strict';
'require baseclass';
'require lanekeep.i18n as i18n';
var zone=null,offset=null,zoneLabel='',prefix='[[lk-time-'+Math.random().toString(36).slice(2)+':';
function configure(system){
 system=system||{};zone=null;offset=null;zoneLabel='';
 if(system.zonename){try{new Intl.DateTimeFormat('en',{timeZone:system.zonename}).format(0);zone=system.zonename;zoneLabel=zone;}catch(e){}}
 if(!zone){var m=String(system.timezone||'').match(/^(?:<[^>]+>|[A-Za-z]+)([+-]?\d{1,2})(?::(\d{2}))?$/);if(m){var hours=Number(m[1]),mins=Number(m[2]||0);offset=-(hours*60+(hours<0?-mins:mins));zoneLabel=String(system.timezone);}}
}
function date(v){if(typeof v==='number')return new Date(v*1000);var s=String(v||'').replace(/^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z$/,'$1-$2-$3T$4:$5:$6Z');return new Date(s);}
function full(v){var d=date(v);if(!isFinite(+d))return '—';if(!zone&&offset===null)return i18n.language==='en'?'Router time zone unavailable':'路由器时区未取得';if(offset!==null)d=new Date(+d+offset*60000);return d.toLocaleString(i18n.language==='en'?'en-GB':'zh-CN',{timeZone:zone||'UTC',hour12:false,year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',second:'2-digit'})+' · '+zoneLabel;}
// Same router time zone as full(), without the zone suffix; used where the zone is stated once per page.
function parts(v,opts){var d=date(v);if(!isFinite(+d))return '—';if(!zone&&offset===null)return '—';if(offset!==null)d=new Date(+d+offset*60000);return d.toLocaleString(i18n.language==='en'?'en-GB':'zh-CN',Object.assign({timeZone:zone||'UTC',hour12:false},opts));}
function plain(v){return parts(v,{year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',second:'2-digit'});}
function axis(v,withDate){return parts(v,withDate?{month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit'}:{hour:'2-digit',minute:'2-digit'});}
function zoneName(){return zoneLabel;}
function relative(v,now){var seconds=Math.round((+date(v)-(now==null?Date.now():now))/1000),n=Math.abs(seconds);if(!isFinite(n))return '—';var unit=n<60?'second':n<3600?'minute':n<86400?'hour':'day',value=Math.round(seconds/(unit==='second'?1:unit==='minute'?60:unit==='hour'?3600:86400));return new Intl.RelativeTimeFormat(i18n.language==='en'?'en':'zh-CN',{numeric:'auto',style:'short'}).format(value,unit);}
function marker(v){var d=date(v);return isFinite(+d)?prefix+Math.floor(+d/1000)+']]':'—';}
function decorate(root){
 var walk=document.createTreeWalker(root,NodeFilter.SHOW_TEXT),nodes=[];
 while(walk.nextNode())if(walk.currentNode.data.includes(prefix)&&!walk.currentNode.parentElement.closest('input,textarea,code,pre,script,style'))nodes.push(walk.currentNode);
 nodes.forEach(function(node){var s=node.data,last=0,start,end,frag=document.createDocumentFragment();while((start=s.indexOf(prefix,last))>=0){end=s.indexOf(']]',start);if(end<0)break;var value=Number(s.slice(start+prefix.length,end));if(!isFinite(value))break;frag.append(s.slice(last,start));var t=document.createElement('time');t.dataset.lkTime=String(value);t.dateTime=date(value).toISOString();t.title=full(value);t.textContent=relative(value);frag.append(t);last=end+2;}if(last){frag.append(s.slice(last));node.replaceWith(frag);}});
 root.querySelectorAll('time[data-lk-time]').forEach(function(t){var value=Number(t.dataset.lkTime),label=relative(value),title=full(value);if(t.textContent!==label)t.textContent=label;if(t.title!==title)t.title=title;});
}
var exported={configure:configure,full:full,plain:plain,axis:axis,zoneName:zoneName,relative:relative,marker:marker,decorate:decorate};
return baseclass.extend({__init__:function(){Object.assign(this,exported);}});
