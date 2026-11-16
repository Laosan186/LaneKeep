'require lanekeep.copy as copy';
'require lanekeep.nodes-ui as nui';
'require lanekeep.i18n as lk';
'use strict';
'require baseclass';
'require ui';
'require lanekeep as panel';
// Uses existing administrator RPCs; all inputs are text nodes, never HTML.
function render(initial,capabilities,env){
 var root=E('div'),state=initial||{ok:false},busy=false,ready=['trial','loopback','verified'].indexOf(capabilities.features&&capabilities.features.subscriptions&&capabilities.features.subscriptions.status)>=0;
 function errBox(){return E('div',{'class':'alert-message warning',hidden:'','data-lk-hidden-origin':'true'});}
 function failure(box,text){panel.errors(box,[{field:'source',message:text||copy.t("F-f8146fd7f8")}],{});if(!box.isConnected)panel.showModal(copy.t("F-836956b9ae"),[box,E('div',{'class':'right'},[panel.button(copy.t("F-146fa84ed2"),ui.hideModal)])]);}
 function blocked(){return busy||env.blocked();}
 function call(method,data,box){if(blocked())return Promise.resolve(null);busy=true;env.setBusy(true);return panel.rpc[method](JSON.stringify(data)).then(function(r){if(!r||!r.ok){failure(box,r&&r.message);return null;}return r;}).catch(function(){failure(box,copy.t("F-a228efc90c"));return null;}).finally(function(){busy=false;env.setBusy(false);});}
 var loading=false,readOnce=false;
 function sourceError(){var messages={source_permission:copy.t("F-df06680377"),source_method:copy.t("F-0228e1a3dc"),source_busy:copy.t("F-8368f4c08d"),source_storage:copy.t("F-26a2553597"),source_backend:copy.t("F-0bb91a39ff"),source_response:copy.t("F-4977790426"),source_timeout:copy.t("F-0cc1436f07"),source_transport:copy.t("F-fe0ed1c8be")};return messages[state.code]||copy.t("F-60baa7e73a");}
 function reload(){if(loading)return Promise.resolve();loading=true;draw();return panel.rpc.sub_list().then(function(r){state=r||{ok:false,code:'source_response'};readOnce=true;}).catch(function(){state={ok:false,code:'source_transport'};readOnce=true;}).finally(function(){loading=false;draw();});}
 function edit(item){
  if(blocked())return;var box=errBox(),name=E('input',{type:'text',value:item?item.name:'',maxlength:80,'class':'cbi-input-text'}),url=E('input',{type:'password',autocomplete:'off',maxlength:4096,'class':'cbi-input-text'}),ua=E('input',{type:'text',value:item?item.ua:copy.t("F-e4681e5a47"),maxlength:256,'class':'cbi-input-text'}),channel=item?item.channel:'proxy';
  var confirm=E('input',{type:'checkbox'}),warning=E('div',{},[confirm,E('span',{},copy.t("F-536c99dea4"))]);
  function show(){warning.hidden=!(channel==='direct'&&(!item||item.channel!=='direct'));confirm.checked=false;}
  var choice=panel.select({proxy:copy.t("F-2e7f8c225d"),direct:copy.t("F-597f318a2e")},channel,function(v){channel=v;show();});show();
  function clear(){url.value='';}
  panel.showModal(item?copy.t('F-318dfd864e'):copy.t('F-c01e36700d'),[E('div',{'class':'lk-form-grid'},[
 nui.field('name',name),E('label',{'class':'lk-field'},[E('span',{'class':'lk-field-label'},copy.t('F-159a1a9d56')),url,E('small',{},copy.t('N-27'))]),
 E('label',{'class':'lk-field'},[E('span',{'class':'lk-field-label'},copy.t('F-71de8ac4b8')),ua]),
 E('label',{'class':'lk-field'},[E('span',{'class':'lk-field-label'},copy.t('F-fddd99ee87')),choice])]),warning,panel.message(copy.t('F-f5fe85c580')),panel.message(copy.t('F-4c010479cf')),box,E('div',{'class':'right'},[
   panel.button(copy.t("F-07003644f2"),function(){clear();ui.hideModal();}),panel.button(copy.t("F-61bc1d3436"),function(){var source={name:name.value,url:url.value,ua:ua.value,channel:channel};if(item)source.id=item.id;call('sub_save',{operation:'save',revision:state.revision,source:source,confirm_direct:confirm.checked},box).then(function(r){if(r){clear();ui.hideModal();reload();}});},true)
  ])]);
 }
 function remove(item){if(blocked())return;var box=errBox();panel.showModal(copy.t("F-9d3ea5cabf"),[panel.message(copy.t("F-fcf11e8ded")),box,E('div',{'class':'right'},[panel.button(copy.t("F-07003644f2"),ui.hideModal),panel.button(copy.t("F-c6a6c96f02"),function(){call('sub_save',{operation:'delete',revision:state.revision,id:item.id},box).then(function(r){if(r){ui.hideModal();reload();}});})])]);}
 function refresh(item){if(blocked())return;var box=errBox();panel.showModal(copy.t("F-11e1078193"),[panel.message(copy.t('F-e99a909652',{channel:item.channel==='direct'?copy.t('F-b4ee7511ed'):copy.t('F-a198b6c6c1')})),box,E('div',{'class':'right'},[panel.button(copy.t("F-07003644f2"),ui.hideModal),panel.button(copy.t("F-8acfebc016"),function(){call('sub_refresh',{id:item.id,source_revision:item.revision},box).then(function(r){if(r){ui.hideModal();reload();}});},true)])]);}
 function difference(source){
  if(blocked())return;var box=errBox(),list=E('div'),summary=E('p'),choices={},updates={},current=null,previous=[],filterInput=E('input',{type:'search',maxlength:80,placeholder:copy.t("F-0099f48c6c")}),prefix=E('input',{type:'text',maxlength:32,placeholder:copy.t("F-cf14b527ac")});
  var binding={id:source.id,source_revision:source.revision,cache_version:source.cache_version},closed=false;
  function draw(){if(!current)return;summary.textContent=copy.t("F-78ee7be410", {"total":(current.total),"page":(current.items.length),"selected":(Object.keys(choices).filter(function(k){return choices[k];}).length)});
   list.replaceChildren(E('table',{'class':'table'},[E('tr',{'class':'tr'},[copy.t("F-2d2fa295c7"),copy.t("F-0f47e87246"),copy.t("F-477218f276"),copy.t("F-8c83c2e944")].map(function(x){return E('th',{'class':'th'},x);} ))].concat(current.items.map(function(row){
    var check=E('input',{type:'checkbox',change:function(){choices[row.item_id]=this.checked;draw();}});check.disabled=!row.selectable;check.checked=choices[row.item_id]===true;var target=E('span',{},copy.t("F-6012af22cd"));
    if(row.targets&&row.targets.length){var options={'':copy.t("F-de97f70c96")};row.targets.forEach(function(x){options[x.id]=x.name+'（'+x.id+'）';});target=panel.select(options,updates[row.item_id]||'',function(v){if(v)updates[row.item_id]=v;else delete updates[row.item_id];});}
    return E('tr',{'class':'tr'},[E('td',{'class':'td'},[check]),E('td',{'class':'td'},row.name||copy.t("F-6012af22cd")),E('td',{'class':'td'},row.message||row.status),E('td',{'class':'td'},[target])]);
   }))));
  }
  function load(offset,back){call('sub_diff',Object.assign({},binding,{offset:offset,filter:filterInput.value}),box).then(function(r){if(!r||closed)return;if(current&&!back)previous.push(current.offset);current=r;binding.nodes_revision=r.nodes_revision;binding.caps_revision=r.caps_revision;draw();});}
  panel.showModal(copy.t("F-7877614501"),[panel.notice(copy.t("F-81612f508a")),filterInput,panel.button(copy.t("F-975efbd135"),function(){previous=[];current=null;load(0,true);}),summary,list,E('div',{},[panel.button(copy.t("F-000b7149aa"),function(){if(previous.length)load(previous.pop(),true);}),panel.button(copy.t("F-8c9af6fd51"),function(){if(current&&current.next!==null)load(current.next,false);}),panel.button(copy.t("F-c87d025af8"),function(){if(!current)return;if(current.matching_item_ids.length>21){failure(box,copy.t("F-4079ee91ff"));return;}current.matching_item_ids.forEach(function(id){choices[id]=true;});draw();}),panel.button(copy.t("F-e62be776d6"),function(){choices={};updates={};draw();})]),panel.message(copy.t("F-7c65693187")),prefix,box,E('div',{'class':'right'},[
   panel.button(copy.t("F-07003644f2"),function(){closed=true;ui.hideModal();}),panel.button(copy.t("F-bb69479596"),function(){
    var selected=Object.keys(choices).filter(function(k){return choices[k];});if(!selected.length||selected.length>21){failure(box,copy.t("F-d7db747a04"));return;}var selectedUpdates={};selected.forEach(function(id){if(updates[id])selectedUpdates[id]=updates[id];});
    if(blocked())return;busy=true;env.setBusy(true);panel.rpc.node_validate(JSON.stringify(env.draft('source_preview',{source_id:source.id,source_revision:binding.source_revision,cache_version:binding.cache_version,selected_item_ids:selected,prefix:prefix.value,updates:selectedUpdates}))).then(function(r){if(closed)return;if(!r.ok){failure(box,r.message);return;}ui.hideModal();env.showPreview(r);}).catch(function(){failure(box,copy.t("F-7981b2dc33"));}).finally(function(){busy=false;env.setBusy(false);});
   },true)
  ])]);load(0,true);
 }
 function draw(){
  var rows=(state.sources||[]).map(function(item){var refreshButton=panel.button(copy.t('F-199b5fa7ce'),function(){refresh(item);}),editButton=panel.button(copy.t('F-818b88a6a5'),function(){edit(item);}),removeButton=panel.button(copy.t('F-622a968fab'),function(){remove(item);}),diffButton=panel.button(copy.t('N-23'),function(){difference(item);});refreshButton.disabled=editButton.disabled=removeButton.disabled=!ready;diffButton.disabled=!item.cache_ready;
   var usage=item.usage?['upload','download','total','expire'].filter(function(k){return item.usage[k]!=null;}).map(function(k){return copy.t({upload:'F-08defc145e',download:'F-ce10648813',total:'F-f36d7a1ae3',expire:'F-a8a82a95db'}[k])+': '+(k==='expire'?panel.utc(new Date(item.usage[k]*1000).toISOString()):nui.bytes(item.usage[k]));}).join(' · '):'';
   var domain;try{domain=new URL(item.url_masked).hostname;}catch(e){domain='—';}
   return E('article',{'class':'lk-sub-row','data-source-id':item.id},[
    E('div',{'class':'lk-node-identity'},[E('span',{'class':'lk-row-icon','aria-hidden':'true'},nui.icon('rss')),E('div',{'class':'lk-node-name'},[E('strong',{title:item.name},item.name),E('p',{},copy.t('N-24',{domain:domain}))])]),
    E('div',{'class':'lk-sub-meta'},[E('p',{},copy.t('N-25',{n:item.count})+' · '+(item.channel==='direct'?copy.t('F-f549f0a739'):copy.t('F-307ca6d431'))),E('p',{},item.fetched_at?copy.t('F-f1e6d2a59a',{time:panel.utc(new Date(item.fetched_at*1000).toISOString())}):copy.t('F-0abe9a63aa')),usage?E('small',{},usage):E('span'),!item.cache_ready?panel.message(item.cache_message):E('span')]),
    E('div',{'class':'lk-row-actions'},[E('div',{},[refreshButton].concat(refreshButton.disabled?[E('small',{},nui.word('notReady'))]:[])),E('div',{},[diffButton].concat(diffButton.disabled?[E('small',{},nui.word('noCache'))]:[])),nui.menu([{button:editButton,reason:nui.word('notReady')},{button:removeButton,reason:nui.word('notReady')}])])]);
  });var readButton=panel.button(loading?copy.t('F-ae8fd3e5be'):copy.t('F-9f806e8ab4'),reload);readButton.disabled=loading;var add=panel.button(copy.t('F-c01e36700d'),function(){edit(null);},true);add.disabled=!ready||!state.ok||loading;
  root.className='lk-node-section lk-subscriptions';
  root.replaceChildren(E('div',{'class':'lk-section-heading'},[E('div',{},[E('h3',{},[copy.t('F-a324968ee7'),nui.badge(copy.t('F-7cfa80524c'),'warning')]),panel.message(copy.t('F-b40407daa2'))]),add]),ready?E('span'):panel.notice(copy.t('F-a69af5c86c')),state.ok?E('div',{'class':'lk-sub-list'},rows):E('div',{'class':'lk-error',role:'alert'},[panel.message(sourceError()),readButton]),state.ok&&!(state.sources||[]).length?E('div',{'class':'lk-empty'},copy.t('F-95bc0cc58c')):E('span'),readOnce&&state.ok?E('span',{'class':'lk-sr-only',role:'status'},copy.t('F-649c57dc2a')):E('span'));
 }

 draw();return root;
}
return baseclass.extend({render:render});
