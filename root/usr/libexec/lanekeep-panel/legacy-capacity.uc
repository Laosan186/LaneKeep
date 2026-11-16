// Panel-side guard for the unchanged legacy sampler. Read-only; no new sampler API.
import * as fs from 'fs';
import * as uci from 'uci';
let MAX_NODES=21,MAX_METRICS=96,BASE_METRICS=51;
function state(){try{if(uci.cursor().get('lanekeep_runtime','main','enabled')!='1'){let defs=[];for(let i=0;i<BASE_METRICS;i++)push(defs,{id:'base_'+i});return {defs};}let p='/tmp/lanekeep-telemetry/state.json',s=fs.lstat(p);if(s?.type!='file'||s.uid!=0||s.size>1048576)return null;let v=json(fs.readfile(p));if(type(v?.defs)!='array'||length(v.defs)<BASE_METRICS||length(v.defs)>MAX_METRICS)return null;let seen={};for(let d in v.defs){if(type(d?.id)!='string'||seen[d.id])return null;seen[d.id]=true;}return v;}catch(e){return null;}}
function current_store(){try{return json(fs.readfile('/etc/lanekeep-proxy/nodes.json'));}catch(e){return null;}}
function project(defs,stores){let known={};for(let d in defs)known[d.id]=true;let before=length(keys(known));for(let s in stores)for(let n in s?.nodes||[])for(let dir in ['up','down'])known['out_node-'+n.id+'_'+dir]=true;return {metrics:length(keys(known)),added:length(keys(known))-before};}
function check_store(store){let saved=state(),current=current_store();if(!saved||type(current?.nodes)!='array')return {ok:false,code:'legacy_capacity_unavailable',message:'原采样器指标状态暂不可读，未增加节点'};
 let budget=project(saved.defs,[current,store]);if(length(store.nodes)>MAX_NODES||budget.metrics>MAX_METRICS)return {ok:false,code:'legacy_metric_capacity',message:'面板试用最多21节点；旧指标含已删节点仍占用，本次会超过96指标，未增加节点',projected_metrics:budget.metrics};
 return {ok:true,projected_metrics:budget.metrics,added_metrics:budget.added};}
function runtime(){let saved=state(),store=current_store();if(!saved||type(store?.nodes)!='array')return {ready:false,mode:'legacy_sampler',max_nodes:MAX_NODES,metric_limit:MAX_METRICS,message:'原采样器指标状态暂不可读；暂停新增节点'};
 let p=project(saved.defs,[store]),available=int((MAX_METRICS-p.metrics)/2),missing=[];
 for(let n in store.nodes)if(n.protocol=='chain')push(missing,'chain-'+n.id);else if(!length(filter(saved.defs,d=>d.id=='out_node-'+n.id+'_up'))||!length(filter(saved.defs,d=>d.id=='out_node-'+n.id+'_down')))push(missing,'node-'+n.id);
 let max=length(store.nodes)+available;if(max>MAX_NODES)max=MAX_NODES;
 return {ready:p.metrics<=MAX_METRICS,mode:'legacy_sampler',trial_max_nodes:MAX_NODES,max_nodes:max,metric_limit:MAX_METRICS,base_metrics:BASE_METRICS,metrics:length(saved.defs),reserved_metrics:p.metrics,additional_new_ids:max-length(store.nodes),uncollected:missing,uncollected_count:length(missing),chain_statistics:false,message:'面板试用上限21节点；当前最多再新增'+(max-length(store.nodes))+'个新编号。旧指标上限96，已删编号仍占用；链不统计流量，历史采样保持'};}
export {MAX_NODES,MAX_METRICS,BASE_METRICS,project,check_store,runtime};
