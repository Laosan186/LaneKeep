'require lanekeep.copy as copy';
'require lanekeep.nodes-ui as nui';
'require lanekeep.i18n as lk';
'use strict';
'require baseclass';
'require ui';
'require lanekeep as panel';

// Schema-driven editor. It never grants a capability that the backend has not published.
return baseclass.extend({
 edit:function(catalog,item,submit,options) {
  options=options||{};
  var protocol=item?item.protocol:options.role==='rear_only'?'socks5':'vless',comboId=item?item.combo:null;
  var id=item?item.id:'n_'+Date.now().toString(36),values={},fields={},controls=[];
  var body=E('div'),comboBox=E('div',{'class':'lk-field'}),notice=E('div');
  var errors=E('div',{'class':'alert-message warning',role:'alert',hidden:'','data-lk-hidden-origin':'true','aria-hidden':'true'});
  var save=panel.button(copy.t("F-70537f7aae"),saveNode,true),active,clearRearAuth=false;
  function published(c){return c.legacy||c.status==='trial'||c.status==='loopback'||c.status==='verified';}
  function combos(){return (catalog.protocols[protocol].combos||[]).filter(function(c){return !item||item.model_version<3||!c.legacy;});}
  function comboLabel(c){return nui.comboName(c);}
  function clear(){controls.forEach(function(c){if(c.type==='password')c.value='';});Object.keys(values).forEach(function(k){if(catalog.fields[k]&&catalog.fields[k].secret)delete values[k];});}
  function drawCombo(){
   var list=combos(),options={};list.forEach(function(c){options[c.id]=comboLabel(c);});
   active=list.find(function(c){return c.id===comboId;})||list[0];comboId=active.id;
   var select=panel.select(options,comboId,function(v){clear();comboId=v;active=list.find(function(c){return c.id===v;});drawFields();});
   comboBox.replaceChildren(E('span',{'class':'lk-field-label'},nui.word('combo')),nui.comboSelect(select,list));drawFields();
  }
  function drawFields(){
   var previous={name:values.name,server:values.server,port:values.port};
   fields={};controls=[];values={id:id,protocol:protocol};
   clearRearAuth=false;
   var same=item&&item.combo===active.id,content=[];
   active.fields.forEach(function(key){
    if(['id','protocol','security','transport','method'].indexOf(key)>=0)return;
    var spec=catalog.fields[key],initial=same?item[key]:undefined;
    if(['name','server','port'].indexOf(key)>=0 && initial==null)initial=previous[key]!=null?previous[key]:item?item[key]:undefined;
    if(initial==null)initial=Object.prototype.hasOwnProperty.call(active.defaults||{},key)?active.defaults[key]:spec.default;
    if(key==='import_hints'){
     values[key]=same&&item.import_hints?Object.assign({},item.import_hints):null;
     content.push(nui.field(key,panel.select({none:copy.t("F-ef524b3456"),required:copy.t("F-0095156c72")},values[key]?'required':'none',function(v){values[key]=v==='required'?{support_x25519mlkem768:true}:null;})));return;
    }
    var control;
    if(spec.type==='bool'){
     values[key]=initial===true;control=E('input',{type:'checkbox',change:function(){values[key]=this.checked;}});control.checked=values[key];
     if((spec.enum||[]).length===1)control.disabled=true;
    }else if(spec.enum||key==='mode'){
     var allowed=key==='mode'?active.modes:spec.enum;
     if(key==='flow')allowed=active.flow||allowed;
     var options={};allowed.forEach(function(v){options[String(v)]=String(v)===''?copy.t("F-8e5787ecc4"):String(v);});
     values[key]=initial==null?allowed[0]:initial;control=panel.select(options,String(values[key]),function(v){values[key]=spec.type==='int'?Number(v):v;});
    }else{
     var value=spec.secret?'':Array.isArray(initial)?initial.join(','):initial==null?'':String(initial);
     control=E('input',{type:spec.secret?'password':'text','class':'cbi-input-text',value:value,autocomplete:'off',spellcheck:'false',maxlength:spec.max_bytes||4096,input:function(){values[key]=this.value;}});values[key]=value;
    }
    control.dataset.field=key;controls.push(control);panel.bindField(fields,'node.'+key,control,nui.fieldName(key));fields[key]=fields['node.'+key];
    var hint=spec.secret&&same?copy.t('F-ad7d56cbbd',{value:panel.text(item[key],copy.t('F-182455c533'))}):null;
    content.push(nui.field(key,control,hint));
   });
   if(active.role==='rear_only'&&item&&item.username){var clearAuth=E('input',{type:'checkbox',change:function(){clearRearAuth=this.checked;}});content.push(E('label',{},[clearAuth,copy.t("F-a0b276d485")]));}
   var common=['name','server','port'],advanced=['import_hints','spiderX','spider_x','mldsa65','alpn'];
   var top=E('div',{'class':'lk-form-grid'}),secrets=E('div',{'class':'lk-form-grid'}),more=[];
   var byKey={};content.forEach(function(el){if(el.dataset.field)byKey[el.dataset.field]=el;});
   if(byKey.name)top.appendChild(byKey.name);
   top.appendChild(nui.field('protocol',select,item?copy.t('N-26'):null));top.appendChild(comboBox);
   ['server','port'].forEach(function(k){if(byKey[k])top.appendChild(byKey[k]);});
   content.forEach(function(el){if(common.indexOf(el.dataset.field)>=0)return;if(advanced.indexOf(el.dataset.field)>=0)more.push(el);else secrets.appendChild(el);});
   body.replaceChildren(top,secrets);if(more.length)body.appendChild(nui.details(copy.t('N-28'),[E('div',{'class':'lk-form-grid'},more)]));
   var messages=[panel.notice(published(active)?active.status==='trial'?copy.t("F-304403090b"):active.status==='loopback'?copy.t("F-bf024c30e7"):copy.t("F-490940a6bd"):copy.t("F-9cb02046db"),!published(active))];
   if(active.role==='rear_only')messages.push(panel.notice(copy.t("F-def2f08011")));
   if(['ws','httpupgrade'].indexOf(active.transport)>=0&&byKey.path){var pathControl=byKey.path.querySelector('input'),hint=E('small',{},copy.t('F-751f41abe9'));byKey.path.appendChild(hint);function pathHint(){hint.hidden=!/[?&]ed=/.test(pathControl.value);}pathControl.addEventListener('input',pathHint);pathHint();}
   notice.replaceChildren.apply(notice,messages.filter(function(el){return el.textContent.trim();}));save.disabled=!published(active);
  }
  function saveNode(){
   if(!published(active))return;
   var payload={id:id,protocol:protocol};
   if(!active.legacy){payload.security=active.security;payload.transport=active.transport;if(active.method)payload.method=active.method;}
   active.fields.forEach(function(key){
    if(['id','protocol','security','transport','method'].indexOf(key)>=0)return;
    var spec=catalog.fields[key],v=values[key];
    if(key==='import_hints'){if(v||item&&item.import_hints)payload[key]=v;return;}
    if(spec.secret&&v===''){if(item)payload[key]='';return;}
    if(spec.type==='int')v=Number(v);
    if(spec.type==='array')v=String(v||'').split(',').map(function(x){return x.trim();}).filter(Boolean);
    if(v!=null)payload[key]=v;
   });
   if(active.role==='rear_only'&&clearRearAuth){payload.username=null;payload.password=null;}
   if(active.fields.indexOf('sni')>=0&&!payload.sni)payload.sni=payload.server;
   submit(payload,errors,fields,clear);
  }
  var protocolOptions={};Object.keys(catalog.protocols).forEach(function(k){if(options.role!=='rear_only'||(catalog.protocols[k].combos||[]).some(function(c){return c.role==='rear_only';}))protocolOptions[k]=nui.protocol(k);});
  var select=panel.select(protocolOptions,protocol,function(v){clear();protocol=v;comboId=null;drawCombo();});select.disabled=!!item;
  drawCombo();
  panel.showModal(item?copy.t("F-baef1797f5"):copy.t("F-8d11489f54"),[
   body,notice,panel.message(copy.t('F-28a1fff32a')),errors,
   E('div',{'class':'right'},[panel.button(copy.t("F-fa8a73f9ad"),function(){clear();ui.hideModal();}),save])
  ]);
 }
});
