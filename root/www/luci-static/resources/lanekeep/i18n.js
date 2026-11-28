'require baseclass';
'require lanekeep.phase2-strings as phase2';
 'use strict';
'require lanekeep.zh as zh';
'require lanekeep.en as en';
var language=String(L.env&&L.env.lang||document.documentElement.lang||'zh').toLowerCase().startsWith('en')?'en':'zh';
var keys=Object.keys(zh).sort(function(a,b){return b.length-a.length;});
// Literal longest-match replacement: one pass, no rewriting of IDs, objects or form values.
function text(value){var s=String(value==null?'':value),dict=language==='en'?en:zh;if(document.body.dataset.page==='admin-services-lanekeep-nodes'&&phase2[s])return phase2[s][language==='en'?1:0];if(Object.prototype.hasOwnProperty.call(dict,s))return dict[s];var result='',i=0;while(i<s.length){var key=keys.find(function(k){return s.startsWith(k,i);});if(key){result+=dict[key];i+=key.length;}else result+=s[i++];}return result;}
// Only explicit fixed fields enter text(); user-owned strings stay raw at render sites.
function mode(id,full){var names={standard:['常规','Standard'],global:['全局','Global'],enhanced:['增强','Enhanced'],ondemand:['按需代理','On-demand'],direct:['直连','Direct']},a=names[id];return a?a[language==='en'?1:0]+(full?(language==='en'?' mode':'模式'):''):String(id||'');}
function reference(ref,nodes){
 if(typeof ref==='string'){
  var fixed=ref.match(/^(常规|全局|增强|按需)\s*\/\s*(组代理节点|兜底出口)$/);
  if(fixed){var group={常规:'standard',全局:'global',增强:'enhanced',按需:'ondemand'}[fixed[1]];return mode(group,true)+' · '+text(fixed[2]);}
  return ref;
 }
 if(!ref)return '';
 if(ref.type==='group_proxy')return mode(ref.group,true)+' · '+(language==='en'?'Proxy node':'代理节点');
 if(ref.type==='fallback')return mode(ref.group,true)+' · '+text('兜底出口');
 if(ref.type==='chain'){
  var chain=(nodes||[]).find(function(n){return n.id===ref.id;});
  if(chain)return (language==='en'?'Chain ':'两跳链 ')+String(chain.name||chain.id)+' · '+(ref.role==='front'?(language==='en'?'Entry':'前置'):(language==='en'?'Exit':'后置'));
 }
 var raw=String(ref.label||ref.name||ref.id||'');
 // The group prefix is structured; everything after it may be user input.
 if(ref.group&&['standard','global','enhanced','ondemand'].indexOf(ref.group)>=0){var at=raw.indexOf(' / ');if(at>=0)return mode(ref.group,true)+' / '+raw.slice(at+3);}
 return raw;
}
// Backend home.rule_text contains generated rule prose and node IDs, not names.
function ruleSummary(value){return text(String(value||''));}
var exported={text:text,language:language,mode:mode,reference:reference,ruleSummary:ruleSummary};
return baseclass.extend({__init__:function(){Object.assign(this,exported);}});
