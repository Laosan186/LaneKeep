'require lanekeep.activation as activation';
'require lanekeep.foundation as foundation';
'require lanekeep.copy as copy';
'require lanekeep.nodes-ui as nui';
'require lanekeep.i18n as lk';
"use strict";
'require view';
'require ui';
'require lanekeep as panel';
'require lanekeep-node-form as nodeForm';
'require view.lanekeep.subscriptions as subscriptions';
'require view.lanekeep.chain-form as chainForm';

return foundation.view(view,{
 load:function() { return Promise.all([panel.rpc.nodes(),panel.rpc.capabilities(),panel.rpc.sub_list()]).then(function(all) { if(!all[0].ok || !all[1].ok)return null;all[0].capabilities=all[1].capabilities;all[0].subscriptions=all[2];return all[0]; }).catch(function() { return null; }); },
 render:function(data) {
  if (!data) return panel.loadFailure();
  var busy=false, testResults={}, nodes=data.nodes || [];
  function displayName(value) { return String(value || ''); }
  function blocked() { if (busy || panel.hasPending()) { panel.showFailure(copy.t("F-aa70bc49e8")); return true; } return false; }
  function draft(operation, extra) { return Object.assign({operation:operation,revision:data.uci_revision,nodes_revision:data.revision},extra || {}); }
  function resultText(result) {
   if (!result) return copy.t("F-c3693d5d41");
   if(result.test_kind==='chain_udp'){return (result.ok?copy.t("F-58b6fa5b22"):copy.t("F-2c777763bf"))+' · '+panel.text(result.message)+' · '+panel.utc(result.time_utc);}
   if(result.test_kind==='chain_tcp'){
    function step(label,v){return label+'：'+(!v||v.status==='skipped'?copy.t("F-13c87cd50e"):v.ok?copy.t("F-c6e2289ca0", {"latency":(panel.testDuration(v))}):copy.t("F-97d3377214"));}
    return copy.t('F-a99709fe1d',{front:step('',result.front).replace(/^：/,''),chain:step('',result.chain).replace(/^：/,''),ip:result.ok?panel.text(result.ip):'—',country:result.ok?panel.text(result.country):'—',time:panel.utc(result.time_utc)});
   }
   return (result.ok ? copy.t("F-ea92a6e0c5", {"ip":(panel.text(result.ip)),"country":(panel.text(result.country))}) : result.message || copy.t("F-736a9d0b3b")) + ' · '+panel.testDuration(result) + ' · ' + panel.utc(result.time_utc);
  }
  function validate(value, errors, fields, context, clear) {
   if (blocked()) return Promise.resolve();
   busy=true;
   return panel.rpc.node_validate(JSON.stringify(value)).then(function(reply) {
    if (!reply.ok) { panel.errors(errors,reply.errors || [{field:'draft',message:reply.message || copy.t("F-4f46f550d4")}],fields); return; }
    if (clear) clear();
    ui.hideModal();
    var details=(reply.imported || []).map(function(n) { return displayName(n.name)+' · '+n.protocol+' · '+n.server+':'+n.port; }).join('；');
    var formatNote=reply.summary && reply.summary.requires_paired_rollback ? copy.t("F-d3b625a35d") : '';
    panel.confirmValidated(reply,null,(context || copy.t("F-29745cf2c2"))+(details ? copy.t("F-ed25b91918", {"details":(details)}) : '')+formatNote);
   }).catch(function() { panel.errors(errors,[{field:'draft',message:copy.t("F-ffdd761d0a")}],fields); }).finally(function() { busy=false; });
  }
  function errorsBox() { return E('div',{'class':'alert-message warning',role:'alert',hidden:'','data-lk-hidden-origin':'true','aria-hidden':'true'}); }
  function editLegacy(item) {
   if (blocked()) return;
   var fields={}, controls=[], values={id:item ? item.id : 'n_'+Date.now().toString(36),protocol:item ? item.protocol : 'vless'}, body=E('div'), errors=errorsBox();
   var secretKeys=['uuid','password','public_key','short_id','mldsa65','obfs_password',copy.t("F-3a35f7e3d7")];
   function entry(key,label,secret,defaultValue) {
    var existing=item && item[key];
    var control=E('input',{type:secret?'password':'text','class':'cbi-input-text',value:secret?'':existing == null ? defaultValue || '' : Array.isArray(existing) ? existing.join(',') : String(existing),autocomplete:'off',spellcheck:'false',maxlength:4096,input:function() { values[key]=this.value; }});
    values[key]=control.value; controls.push(control); panel.bindField(fields,'node.'+key,control,label);
    var row=nui.field(key,control,secret&&item?copy.t('F-bf9af98b82',{value:panel.text(existing,copy.t('F-a4349c2430'))}):null);row.querySelector('.lk-field-label').textContent=label;return row;
   }
   function renderFields() {
    fields={}; controls=[];
    var contents=[entry('name',copy.t("F-ed7729b91d"),false),entry('server',copy.t("F-3388f2b740"),false),entry('port',copy.t("F-06a2b5f71d"),false,'443'),entry('sni',copy.t("F-33231324e8"),false)];
    if(values.protocol==='vless') contents=contents.concat([entry('uuid',copy.t("F-edddcf2c9c"),true),entry('flow',copy.t("F-f09bb0d0b7"),false,'xtls-rprx-vision'),entry('fingerprint',copy.t("F-8950c8c4cd"),false,'chrome'),entry('public_key',copy.t("F-0db490eb57"),true),entry('short_id',copy.t("F-bdedea9cf6"),true),entry('mldsa65',copy.t("F-1fe4fc6ded"),true),entry(copy.t("F-3a35f7e3d7"),copy.t("F-30845b2da9"),true)]);
    else contents=contents.concat([entry('password',copy.t("F-0f9ced841b"),true),entry('alpn',copy.t("F-28a12db198"),false),entry('hop_ports',copy.t("H-1"),false),entry('hop_interval',copy.t("H-3"),false),entry('down_mbps',copy.t("H-4"),false),entry('up_mbps',copy.t("H-5"),false),E('div',{'class':'lk-field','data-field':'hy2_tuning_note'},[panel.message(copy.t("H-6"))]),entry('pin_sha256',copy.t("H-2"),false),panel.message(copy.t("F-8932cdae75"))]);
    if(values.protocol==='vless') {
     values.import_hints=item && item.import_hints ? Object.assign({},item.import_hints) : null;
     var hint=panel.select({unspecified:copy.t("F-b2941e07c4"),required:copy.t("F-84ad1d3ea2")},values.import_hints?'required':'unspecified',function(v){values.import_hints=v==='required'?{support_x25519mlkem768:true}:null;});
     contents.push(E('div',{'class':'lk-field','data-field':'import_hints'},[panel.message(copy.t("F-bc8d27eb4a")),hint,panel.message(copy.t("F-98a1690ab1"))]));
    }
    if(values.protocol==='hysteria2') {
     values.insecure=item ? item.insecure===true : false;
     contents.push(panel.message(values.insecure ? copy.t("F-73e29dced7") : copy.t("F-faa266219d")));
    }
    var top=E('div',{'class':'lk-form-grid'}),rest=E('div',{'class':'lk-form-grid'}),advanced=[];
    function take(k){return contents.find(function(el){return el.dataset.field===k;});}
    if(take('name'))top.appendChild(take('name'));top.appendChild(nui.field('protocol',protocol,item?copy.t('N-26'):null));
    ['server','port'].forEach(function(k){if(take(k))top.appendChild(take(k));});
    contents.forEach(function(el){if(['name','server','port'].indexOf(el.dataset.field)>=0)return;if(['mldsa65','spiderX','alpn','hop_ports','hop_interval','down_mbps','up_mbps','hy2_tuning_note','pin_sha256','import_hints'].indexOf(el.dataset.field)>=0)advanced.push(el);else rest.appendChild(el);});
    body.replaceChildren(top,rest,nui.details(copy.t('N-28'),[E('div',{'class':'lk-form-grid'},advanced)]));
   }
   var protocolOptions={};Object.keys(data.capabilities.protocols).forEach(function(key){var c=data.capabilities.protocols[key];if((c.combos||[]).some(function(x){return x.legacy || x.status==='loopback' || x.status==='verified';}))protocolOptions[key]=nui.protocol(key);});
   var protocol=panel.select(protocolOptions,values.protocol,function(v) { values={id:values.id,protocol:v}; renderFields(); });
   if(item) protocol.disabled=true;
   renderFields();
   panel.showModal(item?copy.t("F-6f4c8c00df"):copy.t("F-ae11504ce2"),[
    panel.notice(copy.t("F-54e2bdd909")),
    body,item&&item.source?panel.message(copy.t("F-8e22d717fe")):E('span'),errors,
    E('div',{'class':'right'},[panel.button(copy.t("F-e46b03dbdd"),ui.hideModal),panel.button(copy.t("F-876103d055"),function() {
     var payload=Object.assign({},values); payload.port=Number(payload.port);
     if(payload.protocol==='hysteria2') {payload.alpn=payload.alpn ? payload.alpn.split(',').map(function(x){return x.trim();}).filter(Boolean):[];payload.insecure=values.insecure===true;}
     validate(draft('save',{node:payload}),errors,fields,null,function() {controls.forEach(function(c){if(c.attributes && c.attributes.type==='password' || c.type==='password')c.value='';});secretKeys.forEach(function(k){delete values[k];});});
    },true)])
   ]);
  }
  function edit(item) {
   if(blocked())return;
   if(item && item.protocol==='chain')return editChain(item);
   if(item && !item.extended_model)return editLegacy(item);
   nodeForm.edit(data.capabilities,item,function(payload,errors,fields,clear){return validate(draft('save',{node:payload}),errors,fields,null,clear);});
  }
  function editChain(item) {
   if(blocked())return;
   chainForm.edit(data.capabilities,nodes,item,function(payload,errors,fields,receipt){var change={node:payload};if(receipt)change.udp_test_id=receipt;return validate(draft('save',change),errors,fields,copy.t("F-5092606e22"));},function(payload,errors,fields,clear){return validate(draft('save',{node:payload}),errors,fields,copy.t("F-6a1f8d54f0"),clear);},function(value){return panel.rpc.node_test(value.rear,value.front,true,value.udp_expected_ip,value.id);});
  }
  function showPreview(preview) {
   var errors=errorsBox(),choices={},list=E('div'),current=preview,history=[],filterInput=E('input',{type:'search',maxlength:80,placeholder:copy.t("F-b71074445e")}),summary=E('p'),closed=false;
   function remember(items){items.forEach(function(item){if(choices[item.item_id]==null)choices[item.item_id]=item.selectable===true&&item.selected_default===true&&Object.keys(choices).filter(function(k){return choices[k];}).length<21;});}
   function draw(){remember(current.items||[]);summary.textContent=copy.t("F-de0344212c", {"total":(current.total),"selected":(Object.keys(choices).filter(function(id){return choices[id];}).length)});
    list.replaceChildren(E('table',{'class':'table'},[E('tr',{'class':'tr'},[copy.t("F-d742f255fe"),copy.t("F-610d2dd1f6"),copy.t("F-ed7729b91d"),copy.t("F-648f73eeae"),copy.t("F-9c88318abd")].map(function(t){return E('th',{'class':'th'},t);} ))].concat((current.items||[]).map(function(item){
     var checkbox=E('input',{type:'checkbox',change:function(){choices[item.item_id]=this.checked;draw();}});checkbox.checked=choices[item.item_id]===true;checkbox.disabled=!item.selectable;
     return E('tr',{'class':'tr'},[E('td',{'class':'td'},[checkbox]),E('td',{'class':'td'},String(item.line)),E('td',{'class':'td'},displayName(item.name)||copy.t("F-8ea9d0b5a1")),E('td',{'class':'td'},item.protocol||copy.t("F-8ea9d0b5a1")),E('td',{'class':'td'},(item.param?item.param+'：':'')+(item.message||copy.t("F-7b51820344"))+(item.changed_fields?copy.t("F-9c628f0546", {"fields":(item.changed_fields.join('、'))}):''))]);
    }))));
   }
   function load(offset,back){if(blocked())return;busy=true;panel.rpc.node_validate(JSON.stringify(draft('preview_page',{preview_id:preview.preview_id,cache_version:preview.cache_version,offset:offset,filter:filterInput.value}))).then(function(reply){if(closed)return;if(!reply.ok){panel.errors(errors,reply.errors||[{field:'preview',message:reply.message}],{});return;}if(!back)history.push(current.offset);current=reply;draw();}).catch(function(){panel.errors(errors,[{field:'preview',message:copy.t("F-90aa612588")}],{});}).finally(function(){busy=false;});}
   draw();panel.showModal(copy.t("F-6b7de718ab"),[
    panel.notice(preview.message||copy.t("F-e00f7c5ea1")),panel.message(copy.t("F-56cf23032f")),filterInput,panel.button(copy.t("F-3622dbe2ec"),function(){history=[];load(0,true);}),summary,E('div',{'class':"lk-legacy-17"},[list]),
    E('div',{},[panel.button(copy.t("F-f0a717473d"),function(){if(history.length)load(history.pop(),true);}),panel.button(copy.t("F-981b2d7fce"),function(){if(current.next!==null)load(current.next,false);}),panel.button(copy.t("F-071466accc"),function(){if(current.matching_item_ids.length>21){panel.errors(errors,[{field:'selection',message:copy.t("F-a49ecb7b30")}],{});return;}current.matching_item_ids.forEach(function(id){choices[id]=true;});draw();}),panel.button(copy.t("F-4d7efb1689"),function(){Object.keys(choices).forEach(function(id){choices[id]=false;});draw();})]),errors,
    E('div',{'class':'right'},[panel.button(copy.t("F-e46b03dbdd"),function(){closed=true;ui.hideModal();}),panel.button(copy.t("F-639692a1ac"),function(){var selected=Object.keys(choices).filter(function(id){return choices[id];});if(!selected.length||selected.length>21){panel.errors(errors,[{field:'selected_item_ids',message:copy.t("F-65c6b07560")}],{});return;}validate(draft('import',{preview_id:preview.preview_id,cache_version:preview.cache_version,selected_item_ids:selected}),errors,{},copy.t("F-1698feff75"));},true)])
   ]);
  }
  function importNodes() {
   if(blocked())return;
   var closed=false,errors=errorsBox(),content=E('textarea',{'class':'cbi-input-textarea',rows:6,autocomplete:'off',spellcheck:'false',maxlength:262144}),url=E('input',{type:'password','class':'cbi-input-text',autocomplete:'off',maxlength:4096});
   var quick='';var quickControl=panel.select({'':copy.t("F-fcbe5c34b1"),socks5:copy.t("F-537c20bb3f"),http:copy.t("F-33284d8c6e")},'',function(v){quick=v;url.value='';url.disabled=!!v;});
   function clear(){content.value='';url.value='';}
   panel.showModal(copy.t("F-a57d23c666"),[
    panel.message(copy.t("F-64f37d0a21")),
    nui.tabs(quickControl),panel.message(copy.t("F-386e954190")),
    panel.message(copy.t("F-547235e15f")),content,panel.message(copy.t("F-8f763575e5")),url,panel.message(copy.t('N-27')),
    panel.notice(copy.t("F-82decaa8dd")),errors,
    E('div',{'class':'right'},[panel.button(copy.t("F-e46b03dbdd"),function(){closed=true;clear();ui.hideModal();}),panel.button(copy.t("F-1a4b5cd369"),function(){
     if(blocked())return;
     if (!!content.value.trim() === !!url.value.trim()) { panel.errors(errors,[{field:'content',message:copy.t("F-2a00ed3c30")}],{}); return; }
     busy=true;
     panel.rpc.node_validate(JSON.stringify(draft('import_preview',Object.assign({content:content.value,subscription_url:url.value},quick?{quick_protocol:quick}:{})))).then(function(reply){
      if(closed)return;
      if(!reply.ok){panel.errors(errors,reply.errors||[{field:'content',message:reply.message||copy.t("F-0feb4d19c7")}],{});return;}
      clear();ui.hideModal();showPreview(reply);
     }).catch(function(){if(!closed)panel.errors(errors,[{field:'content',message:copy.t("F-a7c9d045cf")}],{});}).finally(function(){busy=false;});
    },true)])
   ]);
  }
  function unlinkSource(item) {
   if(blocked())return;var errors=errorsBox();
   panel.showModal(copy.t("F-805f9b77ab"),[panel.message(copy.t("F-cd821f66c4", {"name":(displayName(item.name))})),errors,E('div',{'class':'right'},[panel.button(copy.t("F-e46b03dbdd"),ui.hideModal),panel.button(copy.t("F-23e03cc5a1"),function(){validate(draft('save',{node:{id:item.id,source:null}}),errors,{},copy.t("F-b9e16c88fe"));})])]);
  }
  function removeNode(item) {
   if(blocked())return;
   var errors=errorsBox();
   panel.showModal(copy.t("F-d61425ef72"),[panel.message(copy.t("F-3848e25f56", {"name":(displayName(item.name))})),errors,E('div',{'class':'right'},[panel.button(copy.t("F-e46b03dbdd"),ui.hideModal),panel.button(copy.t("F-68fa644fc8"),function(){validate(draft('delete',{id:item.id}),errors,{},copy.t("F-88a4ccc2eb", {"name":(displayName(item.name))}));})])]);
  }
  function testNode(item, target, after, front) {
   if(blocked())return;
   busy=true;
   target.replaceChildren(panel.message(item.protocol==='chain'||front?copy.t("F-f3bfe05f78"):copy.t("F-c4fcab8351")));
   return panel.rpc.node_test(item.id,front||'',false,'','').then(function(result){
    testResults[item.id]=result;
    target.replaceChildren(nui.testResult(result,resultText(result)));if(result.ok&&result.verification_receipt)target.appendChild(panel.button(copy.t("F-3af4faddb3"),function(){panel.confirmVerification(result);},true));
    return result;
   }).catch(function(){var result={ok:false,message:copy.t("F-23ac7287c0")};testResults[item.id]=result;target.replaceChildren(nui.testResult(result,result.message));return result;}).then(function(result){busy=false;if(after)after(result);return result;},function(){busy=false;});
  }
  function testWithFront(item,target) {
   if(item.role!=='rear_only')return testNode(item,target);
   if(blocked())return;
   var fronts=chainForm.frontsFor(data.capabilities,nodes,item),options={'':copy.t("F-881022271c")},front='';
   fronts.forEach(function(n){options[n.id]=displayName(n.name)+' · '+n.id;});
   var go=panel.button(copy.t("F-dd2a532102"),function(){if(!front)return;ui.hideModal();testNode(item,target,null,front);},true);go.disabled=true;
   panel.showModal(copy.t("F-3a1fc15291"),[panel.message(copy.t("F-6129ba7673")),panel.select(options,'',function(v){front=v;go.disabled=!v;}),E('div',{'class':'right'},[panel.button(copy.t("F-e46b03dbdd"),ui.hideModal),go])]);
  }
  function setDefault(item,target) {
   testNode(item,target,function(result){
    var old=nodes.find(function(n){return n.id===data.default_node;}), before=old && (testResults[old.id] || old.last_test), errors=errorsBox();
    var from=before && before.ok ? before.ip : copy.t("F-d02ea95c9a"), to=result.ok ? result.ip : copy.t("F-438056e470");
    var context=copy.t('F-e91cac346b',{old:old?displayName(old.name):nui.word('unknown'),new:displayName(item.name),from:from,to:to});
    panel.showModal(nui.word('defaultTitle',{name:displayName(item.name)}),[
     nui.comparison(old?displayName(old.name):nui.word('unknown'),displayName(item.name),from,to),
     result.ok?E('span'):panel.notice(copy.t('F-ffc1896e92'),true),
     panel.notice(copy.t('F-e05b787c8f'),true),panel.message(copy.t('F-19c37af0f0')),errors,
     E('div',{'class':'right'},[panel.button(copy.t('F-fa8a73f9ad'),ui.hideModal),panel.button(result.ok?copy.t('F-7eb5b42d27'):copy.t('F-ef02154a43'),function(){validate(draft('default',{id:item.id,allow_failed:!result.ok}),errors,{},context);},true)])
    ]);
   });
  }
  var rows=nodes.map(function(item){
   var references=item.references || [],isDefault=item.id===data.default_node || item.default===true;
   var coverage=data.runtime_capacity||{},missing=(coverage.uncollected||[]).indexOf((item.protocol==='chain'?'chain-':'node-')+item.id)>=0;
   var statsNote=missing?(coverage.error==='byte_budget_not_validated'?copy.t('F-c5b1c6f4ea'):copy.t('F-062ade4c0c')):'';
   var testCell=E('div',{'class':'lk-node-test','role':'status','aria-live':'polite'},[nui.testResult(item.last_test,resultText(item.last_test))]);
   var select=panel.button(copy.t('F-abd8e10a5e'),function(){setDefault(item,testCell);});select.disabled=isDefault || item.default_allowed!==true;
   var test=panel.button(item.role==='rear_only'?copy.t('F-1f1ecbdcfd'):copy.t('F-d71773f39d'),function(){testWithFront(item,testCell);});test.disabled=item.role==='rear_only'?chainForm.frontsFor(data.capabilities,nodes,item).length===0:item.test_allowed!==true;
   var remove=panel.button(copy.t('F-b37a70203b'),function(){removeNode(item);});remove.disabled=isDefault || references.length>0;
   var use=references.map(function(ref){return lk.reference(ref,data.nodes);});
   if(isDefault)use.unshift(copy.t('F-1df842546b'));
   var tags=[];
   if(isDefault)tags.push(nui.badge(copy.t('F-73e692ead2'),'accent'));
   if(item.protocol==='chain')tags.push(nui.badge(copy.t('N-19')));
   if(item.source)tags.push(nui.badge(copy.t('N-20')));
   if(item.role==='rear_only')tags.push(nui.badge(copy.t('F-c1611a38cb')));
   if(item.capability_status==='trial')tags.push(nui.badge(copy.t('F-7cfa80524c'),'warning'));
   if(item.capability_status==='pending')tags.push(nui.badge(copy.t('F-a731565a26')));
   var subline=item.protocol==='chain'?(displayName(item.composition.front.name)+' → '+displayName(item.composition.rear.name)+' · '+copy.t(item.udp?'F-b836eeed28':'F-b5e339b738')):nui.protocol(item.protocol)+' · '+item.server+':'+item.port;
   var actions=[{button:panel.button(copy.t('F-138fc374a1'),function(){edit(item);})},{button:select,reason:isDefault?copy.t('N-22'):nui.word(item.protocol==='chain'?'chainDefault':item.role==='rear_only'?'exitDefault':item.capability_status==='trial'?'trialDefault':'unavailableDefault')},{button:remove,reason:isDefault?copy.t('F-3c6b5ba751'):copy.t('F-c3ada69ead')}];
   if(item.protocol==='chain')actions.push({button:panel.button(copy.t('F-ffddf4d88b'),function(){editChain(item);})});
   if(item.source)actions.push({button:panel.button(copy.t('F-805f9b77ab'),function(){unlinkSource(item);})});
   return E('article',{'class':'lk-node-row','data-node-id':item.id},[
    E('div',{'class':'lk-node-identity'},[E('span',{'class':'lk-row-icon','aria-hidden':'true'},nui.icon(item.protocol==='chain'?'chain':'server')),E('div',{'class':'lk-node-name'},[E('div',{'class':'lk-name-line'},[E('strong',{title:item.name},displayName(item.name))].concat(tags)),E('p',{},subline)])]),
    E('div',{'class':'lk-node-use'},[E('small',{},copy.t('F-47c9a89eb8')),E('div',{'class':'lk-tags'},use.length?use.map(function(x){return nui.badge(x);}):[E('span',{},copy.t('F-17369dabab'))])]),
    E('div',{'class':'lk-node-result'},[E('span',{'class':'lk-sr-only'},copy.t('F-8c23d1a11c')),testCell,statsNote?panel.message(statsNote):E('span')]),
    E('div',{'class':'lk-row-actions'},[E('div',{},[test].concat(test.disabled?[E('small',{},nui.word(item.role==='rear_only'?'noFront':'testUnavailable'))]:[])),nui.menu(actions)])]);
  });
  var actions=E('div',{'class':'lk-page-actions'},[nui.helpButton(copy.t('N-02')),panel.button(copy.t('F-9fd26900ba'),importNodes),panel.button(copy.t('F-5a4a98bcbc'),function(){editChain(null);}),panel.button(copy.t('F-bcd10e8a95'),function(){edit(null);},true)]);
  return E('div',{'class':'lk-nodes-page'},[activation.render(data),
   E('header',{'class':'lk-nodes-heading'},[E('div',{},[E('h2',{},copy.t('F-07935c1762')),panel.message(copy.t('N-01'))]),actions]),
   panel.pendingNotice(),nui.gate(data),nui.help(),
   E('section',{'class':'lk-node-section'},[E('div',{'class':'lk-section-heading'},[E('h3',{},[copy.t('F-07935c1762'),nui.badge(nodes.length+' / 21')]),E('small',{},copy.t('N-18',{chains:nodes.filter(function(n){return n.protocol==='chain';}).length}))]),E('div',{'class':'lk-node-list'},rows.length?rows:[E('div',{'class':'lk-empty'},[E('h4',{},nui.word('empty')),panel.message(nui.word('emptyHint'))])])]),
   subscriptions.render(data.subscriptions,data.capabilities,{blocked:blocked,draft:draft,showPreview:showPreview,setBusy:function(v){busy=v;}})
  ]);
 },
 handleSave:null,handleSaveApply:null,handleReset:null
});
