'require lanekeep.foundation as foundation';
'require lanekeep.i18n as lk';
'use strict';
'require baseclass';
'require rpc';
var pageRead=rpc.declare({object:'lanekeep_telemetry',method:'read_page',params:['window','snapshot','health_date','page','read_id'],expect:{}});
function decode(r){if(r&&r.encoding==='json-v1'){if(typeof r.payload!=='string'||r.payload.length>4194304)throw new Error('payload_invalid');return JSON.parse(r.payload);}return r;}
function integer(n,max){return typeof n==='number'&&isFinite(n)&&Math.floor(n)===n&&n>=0&&n<=max;}
function bounded(p){return new Promise(function(resolve,reject){var timer=setTimeout(function(){reject(new Error('read_timeout'));},10000);Promise.resolve(p).then(function(r){clearTimeout(timer);resolve(r);},function(e){clearTimeout(timer);reject(e);});});}
function fetchPage(window,snapshot,date,page,id){return foundation.firstRead('telemetry:'+window+':'+page,function(){return bounded(pageRead(window,snapshot,date,page,id)).then(decode);}).then(function(r){r=decode(r);if(!r||r.ok!==true){var e=new Error(r&&r.code||'read_failed');e.message_cn=r&&r.message;throw e;}if(r.page!==page||!integer(r.page_count,4)||r.page_count<1||!Array.isArray(r.rows)||!Array.isArray(r.probes)||!Array.isArray(r.events)||!integer(r.total_rows,1440)||!integer(r.total_probes,2048)||!integer(r.total_events,512))throw new Error('page_shape');return r;});}
function transaction(window,snapshot,date){
 return fetchPage(window,snapshot,date,0,'').then(function(first){
  if(first.window!==window||first.snapshot!==snapshot||typeof first.read_id!=='string'||first.read_id.length>128||!first.latest||typeof first.now!=='number'||!isFinite(first.now))throw new Error('page_header');
  var result=Object.assign({},first,{rows:first.rows.slice(),probes:first.probes.slice(),events:first.events.slice()}),page=1;
  function next(){
   if(page>=first.page_count){if(result.rows.length!==first.total_rows||result.probes.length!==first.total_probes||result.events.length!==first.total_events)throw new Error('page_incomplete');return result;}
   return fetchPage(window,snapshot,date,page,first.read_id).then(function(r){
    if(r.read_id!==first.read_id||r.page_count!==first.page_count||r.total_rows!==first.total_rows||r.total_probes!==first.total_probes||r.total_events!==first.total_events||r.now!==first.now||r.window!==window||r.snapshot!==snapshot)throw new Error('page_changed');
    result.rows=result.rows.concat(r.rows);result.probes=result.probes.concat(r.probes);result.events=result.events.concat(r.events);page++;return next();
   });
  }
  return next();
 });
}
function read(window,snapshot,date){
 window=window||'30m';snapshot=snapshot||'none';date=date||'';var started=performance.now();
 return transaction(window,snapshot,date).catch(function(e){if(e.message==='read_expired')return transaction(window,snapshot,date);throw e;}).then(function(r){r.now+=(performance.now()-started)/1000;r._received=performance.now();return r;});
}
return baseclass.extend({read:read,decode:decode});
