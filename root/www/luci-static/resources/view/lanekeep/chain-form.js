'require lanekeep.copy as copy';
'require lanekeep.nodes-ui as nui';
'require lanekeep.i18n as lk';
"use strict";
'require baseclass';
'require ui';
'require lanekeep as panel';
'require lanekeep-node-form as nodeForm';

function published(status){return status==='trial'||status==='loopback'||status==='verified';}
function kind(n){return /^[0-9.]+$/.test(n.server)?'ipv4':'domain';}
function pairReady(catalog,front,rear){
 var f=catalog.features&&catalog.features.chain_tcp;
 if(!f||!published(f.status)||!front||!rear||!front.chain_front_allowed||!rear.chain_rear_allowed||front.id===rear.id)return false;
 if(f.status==='trial')return true;
 return (f.validated_pairs||[]).filter(function(p){return p.front_combo===front.combo&&p.rear_combo===rear.combo&&published(p.status)&&(p.front_address_kinds||[]).indexOf(kind(front))>=0&&(p.rear_address_kinds||[]).indexOf(kind(rear))>=0&&p.tcp_two_hop===true&&p.final_domain_preserved===true&&p.fakeip_rejected===true&&p.data_gate_verified===true;}).length===1;
}
function udpReady(catalog,front,rear){
 var f=catalog.features&&catalog.features.chain_udp;
 if(!pairReady(catalog,front,rear)||!f||!published(f.status)||f.fixed_core!=='26.10.21'||rear.protocol!=='socks5'||rear.provider_udp!==true)return false;
 if(f.status==='trial')return true;
 return (f.validated_pairs||[]).filter(function(p){return p.front_combo===front.combo&&p.rear_combo===rear.combo&&p.front_flow===(front.flow||'')&&published(p.status)&&(p.front_address_kinds||[]).indexOf(kind(front))>=0&&(p.rear_address_kinds||[]).indexOf(kind(rear))>=0&&p.control_two_hop===true&&p.data_two_hop===true&&p.relay_variants===true&&p.gate_no_bypass===true&&p.original_dns===true&&p.udp443_guard===true&&p.l3w===true&&p.l3o===true;}).length===1;
}
function frontsFor(catalog,nodes,rear){return nodes.filter(function(n){return pairReady(catalog,n,rear);});}
function notices(){return E('div',{},[
 panel.notice(lk.text("链承载实际命中它的 TCP。UDP 默认关闭；未验证试用开启前须确认 SOCKS5 服务商支持并勾选试用确认；实际出口和故障阻断仍需测试。HTTP 后置不提供 UDP。")),
 panel.notice(lk.text("前置到后置的 SOCKS5 / HTTP 握手没有额外 TLS，前置端可接触后置认证信息和目标；HTTPS 内容仍由端到端 TLS 保护。")),
 panel.message(lk.text("默认节点门控关闭时，链数据也被阻断。原 UDP 443、DNS 和其他保护继续生效；未命中链的流量仍按原规则处理。"))
]);}
function edit(catalog,nodes,item,submit,quickSubmit,udpProbe){
 var value={id:item?item.id:'chain_'+Date.now().toString(36),name:item?item.name:'',protocol:'chain',front:item?item.front:'',rear:item?item.rear:'',udp:!!(item&&item.udp),udp_expected_ip:item&&item.udp_expected_ip||''},fields={};
 var trialMode=catalog.features&&catalog.features.chain_udp&&catalog.features.chain_udp.status==='trial';
 var receipt=null,validUntil=0,preserved=!!(item&&item.udp&&item.udp_test_valid),generation=0,testing=false,closed=false;
 var errors=E('div',{'class':'alert-message warning',role:'alert',hidden:'','data-lk-hidden-origin':'true','aria-hidden':'true'}),frontBox=E('div'),rearBox=E('div'),udpBox=E('div'),status=E('p'),result=E('p',{role:'status','aria-live':'polite'});
 var name=E('input',{type:'text','class':'cbi-input-text',maxlength:80,value:value.name,input:function(){value.name=this.value;}});
 panel.bindField(fields,'node.name',name,copy.t("F-386f75ab72"));fields.name=fields['node.name'];
 function fresh(){return preserved||!!(receipt&&Date.now()<validUntil);}
 function invalidate(){generation++;receipt=null;validUntil=0;preserved=false;value.udp=false;result.textContent=copy.t("F-58ee533acf");}
 var save=panel.button(copy.t("F-aed4fe3140"),function(){
  if(save.disabled||testing)return;
  if(value.udp&&!trialMode&&!fresh()){result.textContent=copy.t("F-43d6155ae4");draw();return;}
  var payload=Object.assign({},value);if(!payload.udp||!payload.udp_expected_ip)delete payload.udp_expected_ip;
  submit(payload,errors,fields,payload.udp?receipt:null);
 },true);
 function draw(){
  var fronts=nodes.filter(function(n){return ['chain','socks5','http'].indexOf(n.protocol)<0;}),frontOptions={'':copy.t("F-f575b9caed")};
  fronts.forEach(function(n){frontOptions[n.id]=n.name+' · '+n.id+(n.chain_front_allowed?'':copy.t("F-79542b7fa4"));});
  if(item&&value.front&&!frontOptions[value.front])frontOptions[value.front]=copy.t("F-b269ba0416");
  var pickFront=panel.select(frontOptions,value.front,function(v){value.front=v;value.rear='';invalidate();draw();});pickFront.disabled=testing;
  panel.bindField(fields,'node.front',pickFront,copy.t("F-e18a6f52ec"));fields.front=fields['node.front'];frontBox.replaceChildren(panel.message(copy.t("F-e18a6f52ec")),pickFront);
  var front=nodes.find(function(n){return n.id===value.front;}),rearOptions={'':copy.t("F-dd90bb8469")};
  nodes.filter(function(n){return ['socks5','http'].indexOf(n.protocol)>=0;}).forEach(function(n){rearOptions[n.id]=n.name+' · '+nui.protocol(n.protocol)+(pairReady(catalog,front,n)?'':copy.t("F-92b8f9ce4e"));});
  if(item&&value.rear&&!rearOptions[value.rear])rearOptions[value.rear]=copy.t("F-8d6d234640");
  var pickRear=panel.select(rearOptions,value.rear,function(v){value.rear=v;invalidate();draw();});pickRear.disabled=testing;
  panel.bindField(fields,'node.rear',pickRear,copy.t("F-675b4c8a53"));fields.rear=fields['node.rear'];rearBox.replaceChildren(panel.message(copy.t("F-675b4c8a53")),pickRear);
  var rear=nodes.find(function(n){return n.id===value.rear;}),ready=pairReady(catalog,front,rear),canUDP=udpReady(catalog,front,rear);
  var expected=E('input',{type:'text','class':'cbi-input-text',maxlength:15,placeholder:copy.t("F-9b3e61606b"),value:value.udp_expected_ip,input:function(){value.udp_expected_ip=this.value;invalidate();drawUDPControls();}});
  expected.disabled=testing;panel.bindField(fields,'node.udp_expected_ip',expected,copy.t("F-5508b81a93"));fields.udp_expected_ip=fields['node.udp_expected_ip'];
  var toggle=E('input',{type:'checkbox',checked:value.udp,change:function(){value.udp=this.checked;drawUDPControls();}});
  panel.bindField(fields,'node.udp',toggle,copy.t("F-40dccbd266"));fields.udp=fields['node.udp'];
  var test=panel.button(copy.t("F-bd148db4f3"),function(){
   if(test.disabled||testing)return;testing=true;var current=++generation,request=Object.assign({},value);draw();result.textContent=copy.t("F-f64cc4a8e1");
   Promise.resolve().then(function(){return udpProbe(request);}).then(function(reply){
    if(closed||current!==generation)return;
    if(reply&&reply.ok&&reply.udp_test_id){receipt=reply.udp_test_id;validUntil=Date.now()+Math.max(0,Math.min(1200,reply.expires_in||0))*1000;preserved=false;result.textContent=copy.t("F-1de7e88c6b");if(reply.verification_receipt)result.appendChild(panel.button(copy.t("F-81d898db88"),function(){panel.confirmVerification(reply);},true));}
    else{receipt=null;validUntil=0;preserved=false;value.udp=false;result.textContent=reply&&reply.message||copy.t("F-5c617d8788");}
   }).catch(function(){if(!closed&&current===generation){receipt=null;preserved=false;value.udp=false;result.textContent=copy.t("F-00471725dc");}}).finally(function(){testing=false;if(!closed)draw();});
  });
  function drawUDPControls(){
   var ipShape=/^(0|[1-9][0-9]{0,2})(\.(0|[1-9][0-9]{0,2})){3}$/.test(value.udp_expected_ip);
   test.disabled=testing||!canUDP||!ipShape||typeof udpProbe!=='function';
   toggle.disabled=testing||(!value.udp&&(!canUDP||(!trialMode&&!fresh())));toggle.checked=value.udp;
   save.disabled=testing||!ready||(value.udp&&(!canUDP||(!trialMode&&!fresh())));
  }
  drawUDPControls();
  var note=!rear?copy.t("F-56a151194b"):rear.protocol==='http'?copy.t("F-d25ad7ae7c"):rear.provider_udp!==true?copy.t("F-a0018dcce2"):!canUDP?copy.t("F-c60f94b081"):copy.t("F-a1fcf1549b");
  udpBox.replaceChildren(panel.message(note),panel.message(copy.t("F-5d47793ae8")),expected,test,result,E('label',{},[toggle,copy.t("F-d86969bb2a")]),panel.message(copy.t("F-54feb4a2f8")));
  status.textContent=ready?copy.t("F-4a13695ff2"):copy.t("F-1c1e6192ca");
 }
 draw();panel.showModal(item?copy.t("F-140d1a1d0e"):copy.t("F-e116c7ae4a"),[
  E('div',{'class':'lk-form-grid'},[frontBox,rearBox,nui.field('name',name)]),nui.details(copy.t('F-40dccbd266'),[udpBox]),status,
  panel.button(copy.t("F-9c98901df3"),function(){if(testing)return;closed=true;nodeForm.edit(catalog,null,quickSubmit,{role:'rear_only'});}),
  panel.message(copy.t("F-d16406b216")),errors,
  E('div',{'class':'right'},[panel.button(copy.t("F-6d289311c2"),function(){closed=true;ui.hideModal();}),save])
 ]);
}
return baseclass.extend({edit:edit,pairReady:pairReady,udpReady:udpReady,frontsFor:frontsFor,notices:notices});
