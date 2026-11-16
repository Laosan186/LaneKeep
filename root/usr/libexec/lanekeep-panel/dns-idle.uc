// Candidate only: narrow UDP/53 lifetime change, applied after base invariants.
function canonical(v){
 if(type(v)=='object')return '{'+join(',',map(sort(keys(v)),k=>sprintf('%J',k)+':'+canonical(v[k])))+'}';
 if(type(v)=='array')return '['+join(',',map(v,canonical))+']';
 return sprintf('%J',v);
}
function clone(v){return json(canonical(v));}
function same(a,b){return canonical(a)==canonical(b);}
const TAG='lan-dns-udp-shortidle';
const GROUPS=['standard-transparent','global-transparent','enhanced-transparent','ondemand-transparent'];
function udp_rule(anchor){
 let expected={type:'field',inboundTag:GROUPS,port:'53',outboundTag:'lan-dns-out'};
 if(!same(anchor,expected))return null;
 let rule=clone(anchor);rule.network='udp';rule.outboundTag=TAG;return rule;
}
function enable(config){
 if(type(config)!='object'||type(config.routing?.rules)!='array'||type(config.outbounds)!='array')die('dns_idle_config_shape');
 // A generated config is patched once; reject collisions rather than alter unrelated policy.
 if(length(filter(config.outbounds,o=>o.tag==TAG)) || config.policy?.levels?.['53']!=null)die('dns_idle_reserved_collision');
 let candidates=filter(config.outbounds,o=>o.tag=='lan-dns-out');
 if(length(candidates)!=1 || candidates[0].protocol!='dns' || type(candidates[0].settings)!='object' || candidates[0].settings.userLevel!=null)die('dns_idle_dns_outbound_shape');
 let anchor={type:'field',inboundTag:GROUPS,port:'53',outboundTag:'lan-dns-out'};
 let positions=[];
 for(let i=0;i<length(config.routing.rules);i++)if(same(config.routing.rules[i],anchor))push(positions,i);
 if(length(positions)!=1)die('dns_idle_dns_rule_shape');
 let original=clone(config), next=clone(config), out=clone(candidates[0]), rule=udp_rule(anchor);
 out.tag=TAG;out.settings.userLevel=53;push(next.outbounds,out);
 rule.network='udp';rule.outboundTag=TAG;
 splice(next.routing.rules,positions[0],0,rule);
 if(next.policy==null)next.policy={};if(next.policy.levels==null)next.policy.levels={};
 // Xray v26.10.21 ActivityTimer polls rather than resetting a deadline.
 // Two idle polling ticks can be needed: 15s yields about 15-30s idle release.
 next.policy.levels['53']={connIdle:15};
 // Reverse precisely the three intended additions and prove the rest is identical.
 let reverse=clone(next);pop(reverse.outbounds);splice(reverse.routing.rules,positions[0],1);
 delete reverse.policy.levels['53'];
 if(original.policy?.levels==null)delete reverse.policy.levels;
 if(original.policy==null)delete reverse.policy;
 if(!same(reverse,original))die('dns_idle_unexpected_delta');
 config.outbounds=next.outbounds;config.routing=next.routing;config.policy=next.policy;
 return {dns_udp_outbound:TAG,userLevel:53,connIdle:15,nominal_idle_release_upper_seconds:30,scope:'four_transparent_inbounds_udp_53_only'};
}
export { enable, udp_rule };
