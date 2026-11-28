import * as lan from './network.uc';
// LANEKEEP panel private helper. This file never accepts commands or arbitrary paths.
import * as fs from 'fs';
import * as uci from 'uci';
import * as nodes from './nodes.uc';
import * as caps from './caps.uc';
import * as previews from './import-preview.uc';
import * as dedicated from './dedicated.uc';
import * as ip_rule from './ip-rule.uc';
import * as settings from './settings.uc';
import * as dns_idle from './dns-idle.uc';
import * as subscriptions from './subscriptions.uc';
import * as sizes from './rpc-size.uc';
import * as metric_capacity from './legacy-capacity.uc';
import * as home from './home.uc';
import * as udp_proofs from './chain-udp-proofs.uc';
import { public_ip } from './chain-udp.uc';
// ucode binds closures in source order; declare shared bindings before use.
let reject_import, sub_api, require_store_capacity, check_udp_receipts, capacity_runtime, udp_proof_api, node_udp_test;
let ROOT = '/tmp/lanekeep-panel';
let CODE = '/usr/libexec/lanekeep-panel';
let ENGINE = '/usr/libexec/lanekeep-xray';
let PROXY = '/etc/lanekeep-proxy';
let GROUPS = ['standard', 'global', 'enhanced', 'ondemand'];
// Groups that can own dedicated entries and must have a UCI section since 0.1.
let MEMBERS = ['global', 'enhanced', 'ondemand'];
// Every explicit member set. Standard/direct sections are optional in 0.2.x configurations.
let ASSIGN = ['global', 'enhanced', 'ondemand', 'standard', 'direct'];
let OPTIONAL_LABELS = {standard:'常规模式', direct:'直连'};
let TAGS = {standard:'standard-transparent', global:'global-transparent', enhanced:'enhanced-transparent', ondemand:'ondemand-transparent'};
let LABELS = {standard:'常规', global:'全局', enhanced:'增强', ondemand:'按需', direct:'直连'};
let GENERATOR_SHA = 'b1417339097a7612adb06dad3437d6fdcd95153b5eeaad542f8454f8ddddb32d';
let failure = null;
function enabled(){return uci.cursor().get('lanekeep_runtime','main','enabled')=='1';}
let may_have_started = false;
function reject(field, message) { failure = {ok:false, message:message, errors:[{field:field, message:message}]}; die('rejected'); }
function has(list, value) { return index(list, value) >= 0; }
function q(value) { return "'" + replace(value, /'/g, "'\\''") + "'"; }
function run(command) {
    let p = fs.popen(command + ' 2>/dev/null', 'r');
    if (!p) return null;
    let result = p.read('all'); let code = p.close();
    return code == 0 ? result : null;
}
function obj(path) { let content = fs.readfile(path); if (content == null) return null; return json(content); }
function text(value, max) { return type(value) == 'string' && length(value) <= max && !match(value, /[[:cntrl:]]/); }
function regular(path) { return fs.lstat(path)?.type == 'file'; }
function write(path, value) {
    if (fs.lstat(path)?.type == 'link' || fs.lstat(path + '.next') != null) reject('storage','私有任务状态异常');
    if (fs.writefile(path + '.next', sprintf('%J\n',value)) == null) reject('storage','无法保存私有任务状态');
    fs.chmod(path + '.next', 384);
    if (!fs.rename(path + '.next', path)) reject('storage','无法提交私有任务状态');
}
function fingerprint(path) {
    if (!regular(path)) reject('revision','当前输入不可读取');
    let value = run('sha256sum ' + q(path));
    let digest = split(value || '', ' ')[0];
    if (!match(digest, /^[a-f0-9]{64}$/)) reject('revision','无法核验配置摘要');
    return digest;
}
function current_nodes() { return nodes.read_store(PROXY+'/nodes.json'); }
function nodes_revision() { return fingerprint(PROXY+'/nodes.json'); }
function ensure_root() {
    if (fs.lstat(ROOT) == null) fs.mkdir(ROOT,448);
    if (fs.lstat(ROOT)?.type != 'directory') reject('storage','私有草稿目录异常');
    fs.chmod(ROOT,448);
}
function valid_id(id) { return type(id)=='string' && match(id,/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/) != null; }
function uuid() { let id = trim(fs.readfile('/proc/sys/kernel/random/uuid') || ''); if (!valid_id(id)) reject('storage','无法分配任务编号'); return id; }
function safe_keys(value, allowed, field) {
    if (type(value) != 'object') reject(field,'格式必须是对象');
    for (let key in keys(value)) if (!has(allowed,key)) reject(field,'包含不支持的字段');
}
function clean_name(value) { return text(value,80) ? value : '未命名设备'; }
function ip_ok(value) {return lan.member(value);}
function read_config(dir) {
    if (!regular(dir + '/lanekeep') || fs.stat(dir + '/lanekeep').size > 524288) reject('config','用户配置不可读取或过大');
    let cursor = uci.cursor(dir, '/tmp/lanekeep-panel-empty-' + uuid());
    if (!cursor.load('lanekeep')) reject('config','用户配置无法解析');
    let data = settings.defaults();data.members={global:[],enhanced:[],ondemand:[],standard:[],direct:[]};data.labels={standard:OPTIONAL_LABELS.standard,direct:OPTIONAL_LABELS.direct};data.rules=[];let seen={},setting_sections={};
    cursor.foreach('lanekeep',null,function(s) {
        if(settings.section(data,s,setting_sections))return;
        if (s['.type']=='group') {
            let g=s['.name']; if (!has(ASSIGN,g) || seen[g]) reject('config','分组格式不受支持'); seen[g]=true;
            data.members[g]=s.member || []; data.labels[g]=s.label || OPTIONAL_LABELS[g] || LABELS[g];
            return;
        }
        if (s['.type']!='rule') reject('config','用户配置中有不支持的区段');
        push(data.rules,{id:s['.name'],group:s.group,type:s.type,value:s.value,action:s.action,enabled:s.enabled || '1',note:s.note || '',node:s.node || ''});
    });
    for (let g in MEMBERS) if (!seen[g]) reject('config','用户配置缺少分组');
    cursor.unload('lanekeep'); return data;
}
function bindings() {
    let cursor=uci.cursor('/etc/config','/tmp/lanekeep-panel-empty-' + uuid());
    if (!cursor.load('dhcp')) reject('devices','DHCP配置不可读取');
    let result=[]; let seen={};
    cursor.foreach('dhcp','host',function(s) {
        if (!ip_ok(s.ip) || seen[s.ip]) return;
        seen[s.ip]=true; push(result,{name:clean_name(s.name),ip:s.ip});
    }); cursor.unload('dhcp'); return result;
}
// A page loaded before the upgrade does not know the standard and direct groups. Missing keys keep the
// saved members, except addresses the draft now places in another group.
function keep_optional_members(value, saved) {
    if(type(value)!='object') return value;
    let out={},placed={};
    for(let k in value){out[k]=value[k];if(type(value[k])=='array')for(let a in value[k])placed[a]=true;}
    for(let g in ['standard','direct'])if(!exists(value,g))out[g]=filter(saved?.[g] || [],a=>!placed[a]);
    return out;
}
function validate_members(value, hosts) {
    safe_keys(value,ASSIGN,'members'); let assigned={},seen={},out={};
    for (let host in hosts) assigned[host.ip]=true;
    for (let g in ASSIGN) {
        let list=value[g] ?? (has(MEMBERS,g) ? null : []); if (type(list)!='array' || length(list)>253) reject('members.'+g,'成员必须是固定IP列表');
        out[g]=[];
        for (let address in list) {
            if (!ip_ok(address)) reject('members.'+g,'成员 IP 必须位于所选 LAN 子网内');
            if (!assigned[address]) reject('members.'+g,'设备必须先有DHCP静态绑定');
            if (seen[address]) reject('members.'+g,'同一IP不能重复或跨组');
            seen[address]=true; push(out[g],address);
        }
        out[g]=sort(out[g]);
    }
    return out;
}
function validate_rules(list, current, store) {
    if (type(list)!='array' || length(list)>2000) reject('rules','规则必须是列表，每组最多500条');
    let ports={},ids={},same={},actions={},counts={standard:0,global:0,enhanced:0,ondemand:0}, out=[];
    for (let i=0;i<length(list);i++) {
        let r=list[i], f='rules.'+i;
        safe_keys(r,['id','group','type','value','action','enabled','note','node'],f);
        if (!text(r.id,64) || !match(r.id,/^[A-Za-z][A-Za-z0-9_]{0,63}$/) || has(ASSIGN,r.id) || has(['real_dns','unassigned','fallback_standard','fallback_global','fallback_enhanced','fallback_ondemand','group_proxy_standard','group_proxy_global','group_proxy_enhanced','group_proxy_ondemand'],r.id) || ids[r.id]) reject(f+'.id','规则编号无效或重复');
        ids[r.id]=true;
        if(r.action=='node' && (!nodes.valid_node_id(r.node) || !length(filter((store || current_nodes()).nodes,n=>n.id==r.node)))) reject(f+'.node','指定节点不存在');
        if(r.action=='node'){let node_store=store||current_nodes();nodes.assert_reference(filter(node_store.nodes,n=>n.id==r.node)[0],node_store);}
        if (type(r.group)!='string' || !has(GROUPS,r.group)) reject(f+'.group','请选择有效分组');
        if (type(r.type)!='string' || !has(['domain','full','keyword','ip','dedicated','geosite'],r.type)) reject(f+'.type','只支持域名、完整域名、关键词、IP、专用入口和广告域名库');
        if (type(r.action)!='string' || !has(['proxy','direct','block','node'],r.action)) reject(f+'.action','请选择代理、直连或阻断');
        if (type(r.enabled)!='string' || r.enabled!='0' && r.enabled!='1') reject(f+'.enabled','启用值无效');
        if (!text(r.note,256)) reject(f+'.note','备注最多256字节，不能含控制字符');
        if (!text(r.value,253)) reject(f+'.value','匹配值无效或过长');
        let value=r.value;
        if(r.type=='geosite') {
            if(value!='category-ads-all' || r.action!='block' || (r.node!=null && r.node!=''))reject(f+'.value','广告域名库固定使用 category-ads-all 和阻断，可按组启用或停用');
        } else if(r.type=='dedicated') {
            if(!has(MEMBERS,r.group))reject(f+'.group','常规组暂不支持专用入口，请选择全局、增强或按需组');
            if(!dedicated.valid_port(value))reject(f+'.value','专用入口端口须为10811—10860的整数');
            if(ports[value])reject(f+'.value','专用入口端口在所有组中必须唯一，停用入口也保留端口');
            ports[value]=true;
            if(r.action=='block')reject(f+'.action','专用入口只能使用默认节点、指定节点或直连');
        } else if (r.type=='domain' || r.type=='full') {
            value=replace(lc(trim(value)),/\.$/,'');
            if (!match(value,/^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$/)) reject(f+'.value','请输入合法域名，不含协议、路径或通配符');
            for (let label in split(value,'.')) if (length(label)>63) reject(f+'.value','域名每段最多63个字符');
        } else if (r.type=='keyword') {
            if (!match(value,/^[a-z0-9.-]{3,}$/)) reject(f+'.value','关键词至少3个小写字母、数字、点或连字符');
        } else if (r.type=='ip') {
            let lan_subnet=null;try{lan_subnet=lan.context().subnet;}catch(e){}
            let parsed=ip_rule.normalize(value,lan_subnet);
            if(!parsed.ok) reject(f+'.value',({host:'网段写法有误：主机位须为 0，例如 1.2.3.0/24',reserved:'局域网、本机、组播、假 IP 等保留地址不能设置'})[parsed.code] || '请填写一个 IPv4 地址或网段，例如 1.2.3.4 或 1.2.3.0/24');
            value=parsed.value;
            if(r.action=='node' && filter((store || current_nodes()).nodes,n=>n.id==r.node)[0]?.protocol=='chain') reject(f+'.node','IP 规则暂不支持两跳链，请选择普通节点');
        }
        let key=r.group+'|'+r.type+'|'+value, ak=r.group+'|'+value;
        if (same[key]) reject(f+'.value','同组规则重复');
        if (actions[ak]!=null && actions[ak]!=(r.action=='node'?'node:'+r.node:r.action)) reject(f+'.action','同组同一匹配值的出口冲突');
        same[key]=true; actions[ak]=r.action=='node'?'node:'+r.node:r.action;
        counts[r.group]++; if(counts[r.group]>500) reject(f+'.group','每组最多500条规则');
        push(out,{id:r.id,group:r.group,type:r.type,value:value,action:r.action,enabled:r.enabled,note:r.note,node:r.action=='node'?r.node:''});
    }
    return out;
}
function quote_uci(value) { return "'" + replace(value,/'/g,"'\\''") + "'"; }
function encode(data) {
    let lines=settings.encode(data,quote_uci);
    for(let g in ASSIGN) {
        push(lines,'config group '+quote_uci(g));
        push(lines,'\toption label '+quote_uci(data.labels[g]));
        for(let address in data.members[g]) push(lines,'\tlist member '+quote_uci(address));
        push(lines,'');
    }
    for(let r in data.rules) {
        push(lines,'config rule '+quote_uci(r.id));
        for(let k in ['group','type','value','action','enabled','note']) push(lines,'\toption '+k+' '+quote_uci(r[k]));
        if(r.action=='node') push(lines,'\toption node '+quote_uci(r.node));
        push(lines,'');
    }
    return join('\n',lines)+'\n';
}
function canonical(value) {
    if(type(value)=='object') return '{'+join(',',map(sort(keys(value)),(key)=>sprintf('%J',key)+':'+canonical(value[key])))+'}';
    if(type(value)=='array') return '['+join(',',map(value,(item)=>canonical(item)))+']';
    return sprintf('%J',value);
}
function equal(a,b) { return canonical(a)==canonical(b); }
function clone(value) { return json(canonical(value)); }
function validate_settings(value,store) {
    try {return settings.validate(value,store);}catch(e){let issue=nodes.take_error();if(issue)reject_import(issue.code,issue.param,issue.message);reject('settings','组代理节点须为可用的具体节点或留空；兜底出口须为本组代理节点、有效指定节点或直连；真实解析名单只接受 domain:域名 或 full:完整域名，最多200项，不可重复。');}
}
function exit_label(f) {
    return f.action=='direct'?'直连':f.action=='proxy'?'本组代理节点':'指定节点 '+f.node;
}
function same_settings(a,b) {return equal(a.group_nodes,b.group_nodes) && equal(a.fallbacks,b.fallbacks) && equal(a.real_dns,b.real_dns) && (a.unassigned ?? 'standard')==(b.unassigned ?? 'standard');}
function last_test(id) {
    let value=regular(ROOT+'/node-tests.json')?obj(ROOT+'/node-tests.json')?.[id]:null;
    let n=filter(current_nodes().nodes,x=>x.id==id)[0];
    if(value&&has(['chain_tcp','chain_udp'],value.result?.test_kind)&&(value.result.revision!=nodes_revision()||value.result.caps_revision!=caps.revision()))return null;
    return value && n && equal(value.node,n)?value.result:null;
}
function historical_rules(rules) {
    let result=clone(rules);
    // Only the exact archived migration entry is normalized. No API accepts new regexp.
    return result;
}
function same_members(a,b) {
    for(let group in ASSIGN) {
        if(type(a[group])!='array' || type(b[group])!='array' || !equal(sort(clone(a[group])),sort(clone(b[group])))) return false;
    }
    return true;
}
function config_kind(summary, generated, previous) {
    if(!equal(obj(generated),obj(previous)) || summary?.unassigned_change!=null) return 'rules';
    if(length(summary.member_changes || [])) return 'members';
    return summary.apply_kind=='unchanged' ? 'unchanged' : 'metadata';
}
function attach_notes(summary, before, after) {
    let old={},now={}; for(let r in before) old[r.id]=r; for(let r in after) now[r.id]=r;
    summary.added=map(summary.added,(r)=>now[r.id]);
    summary.removed=map(summary.removed,(r)=>old[r.id]);
    summary.changed=map(summary.changed,(r)=>({before:old[r.before.id],after:now[r.after.id]}));
    return summary;
}
function group_for(ip,members,unassigned) { for(let g in ASSIGN) if(has(members[g] || [],ip)) return g; return unassigned ?? 'standard'; }
// Static-lease devices that have no explicit set and therefore follow the unassigned choice.
function unassigned_hosts(hosts,members) { return filter(hosts,h=>!length(filter(ASSIGN,g=>has(members[g] || [],h.ip)))); }
function public_summary(s) {
    return {added:s?.added || [],removed:s?.removed || [],changed:s?.changed || [],order_changed:s?.order_changed==true,
        group_node_changes:s?.group_node_changes || [],fallback_changes:s?.fallback_changes || [],real_dns_change:s?.real_dns_change,unassigned_change:s?.unassigned_change,unassigned:s?.unassigned,
        member_changes:s?.member_changes || [],rule_count:s?.rule_count || 0,node_changes:s?.node_changes || [],affected_chains:s?.affected_chains || [],udp_invalidated:s?.udp_invalidated || [],active_chain_count:s?.active_chain_count,active_referenced_records:s?.active_referenced_records,default_node_change:s?.default_node_change};
}
function summary_text(s) {
    let lines=[];
    for(let c in s?.group_node_changes || [])push(lines,LABELS[c.group]+'组代理节点：'+(c.before || '全局默认')+' → '+(c.after || '全局默认'));
    for(let change in s?.fallback_changes || [])push(lines,LABELS[change.group]+'组兜底：'+exit_label(change.before)+' → '+exit_label(change.after));
    if(s?.real_dns_change)push(lines,'不使用假 IP 的域名：'+length(s.real_dns_change.before)+' → '+length(s.real_dns_change.after)+'项');
    if(s?.unassigned_change)push(lines,'未分组设备：'+LABELS[s.unassigned_change.before]+'组 → '+LABELS[s.unassigned_change.after]+'组');
    for(let pair in [['added','新增规则'],['removed','删除规则'],['changed','修改规则'],['member_changes','分组变化']])
        if(length(s?.[pair[0]] || []))push(lines,pair[1]+length(s[pair[0]]));
    if(s?.order_changed)push(lines,'规则顺序改变');
    for(let n in s?.node_changes || [])push(lines,(n.action || '修改')+'节点「'+n.name+'」');
    if(s?.default_node_change)push(lines,'默认节点：'+s.default_node_change.before_name+' → '+s.default_node_change.after_name);
    return length(lines)?join('；',lines):'未记录规则、分组或节点内容变化';
}
function store_diff(before,after) {
    let out={node_changes:[]};
    for(let n in after.nodes){let old=filter(before.nodes,x=>x.id==n.id)[0];if(!old || !equal(old,n))push(out.node_changes,{id:n.id,name:n.name,action:old?'修改':'新增'});}
    for(let n in before.nodes)if(!length(filter(after.nodes,x=>x.id==n.id)))push(out.node_changes,{id:n.id,name:n.name,action:'删除'});
    if(before.default_node!=after.default_node)out.default_node_change={before_name:(filter(before.nodes,x=>x.id==before.default_node)[0]?.name || ''),after_name:(filter(after.nodes,x=>x.id==after.default_node)[0]?.name || '')};
    return out;
}
function snapshot_nodes(dir) {
    if(!regular(dir+'/manifest.sha256') || system('cd '+q(dir)+' && sha256sum -c manifest.sha256 >/dev/null 2>&1')!=0)die('invalid_snapshot');
    return regular(dir+'/nodes.json')?nodes.read_store(dir+'/nodes.json'):nodes.migrate(obj(dir+'/config.json'));
}
function job_state(id) {
    if (!valid_id(id)) reject('job_id','任务编号格式不合法');
    let dir=ROOT+'/'+id;
    if (fs.lstat(dir)?.type!='directory' || !regular(dir+'/state.json')) return {id:id,state:'unknown',result:'unknown',message:'未找到任务；请检查当前状态，不要盲目重提'};
    let s=obj(dir+'/state.json');
    if(s.state=='pending' && time()-(s.started_at || time())>15 || s.state=='running' && type(s.worker_pid)=='int' && !fs.stat('/proc/'+s.worker_pid))
        return {id:id,state:'unknown',result:'unknown',phases:s.phases || [],message:(length(s.phases || [])?'已有部分恢复步骤完成；':'')+'工作进程状态不明，先核对当前配置与门控，不要重复应用'};
    return {id:id,state:s.state,result:s.result || '',message:s.message || '',started_at:s.started_at,finished_at:s.finished_at,phases:s.phases || []};
}
function ensure_no_active() {
    for(let name in fs.lsdir(ROOT) || []) {
        if(!valid_id(name) || fs.lstat(ROOT+'/'+name)?.type!='directory' || !regular(ROOT+'/'+name+'/state.json')) continue;
        let s=obj(ROOT+'/'+name+'/state.json');
        if(s?.state=='pending' || s?.state=='running') reject('apply','已有任务未结束，请先查看状态');
    }
}
function gc() {
    // Only our expired, never-submitted drafts are removed; no historical snapshots.
    for(let id in fs.lsdir(ROOT) || []) {
        if(!valid_id(id) || fs.lstat(ROOT+'/'+id)?.type!='directory') continue;
        let dir=ROOT+'/'+id, s=regular(dir+'/state.json') ? obj(dir+'/state.json') : null;
        if(!has(['validated','invalid','success','failed','rolled_back'],s?.state)) continue;
        let retention=has(['validated','invalid'],s.state)?1800:86400;
        if(time()-(s.created_at || time())<retention) continue;
        // Generated output can contain credentials; unlink only explicit regular files.
        let root_files=['state.json','lanekeep','dhcp','generator-output','meta.json','apply-private.log','exit-code','nodes.json','test-config.json','test-private.log','test-response','node-test-result.json'];
        let generated_files=['config.json','phone-pilot.nft','members.nft','normalized-rules.json','summary.json','invariant-template.json','invariant-output.json','invariant.sha256','validated','generator-private.log','xray-private.log','error.json','nodes.json'];
        let allowed={'':root_files,'/generated':generated_files,'/members':root_files,'/members/generated':generated_files,'/rules':root_files,'/rules/generated':generated_files};
        let valid=true;
        for(let suffix in keys(allowed)) for(let file in fs.lsdir(dir+suffix) || []) {
            if(allowed[suffix+'/'+file]!=null && fs.lstat(dir+suffix+'/'+file)?.type=='directory') continue;
            if(!has(allowed[suffix],file) || !regular(dir+suffix+'/'+file)) valid=false;
        }
        if(!valid) continue;
        for(let suffix in ['/members/generated','/rules/generated','/generated','/members','/rules','']) {
            for(let file in allowed[suffix]) if(regular(dir+suffix+'/'+file)) fs.unlink(dir+suffix+'/'+file);
            fs.rmdir(dir+suffix);
        }
    }
}
function prepare(draft, origin) {
    safe_keys(draft,['revision','scope','members','rules','nodes_revision','fallbacks','real_dns','group_nodes','unassigned'],'draft');
    if(!has(['rules','members'],draft.scope)) reject('scope','请分别提交规则或设备分组');
    if(type(draft.revision)!='string' || !match(draft.revision,/^[a-f0-9]{64}$/)) reject('revision','配置版本无效，请刷新');
    if(draft.scope=='rules' && draft.members!=null || draft.scope=='members' && draft.rules!=null) reject('scope','规则和成员不能混合提交');
    if(draft.scope=='members' && (draft.fallbacks!=null || draft.real_dns!=null || draft.group_nodes!=null || draft.unassigned!=null))reject('scope','设备换组不能夹带组代理节点、兜底出口、DNS或未分组设备改动');
    if(draft.unassigned!=null && !settings.unassigned_ok(draft.unassigned))reject('unassigned','未分组设备只能进入直连组或常规组');
    let cap_revision=caps.revision();
    let before=fingerprint('/etc/config/lanekeep'), dhcp=fingerprint('/etc/config/dhcp'), node_revision=nodes_revision();
    if(draft.group_nodes!=null && draft.nodes_revision!=node_revision || draft.nodes_revision!=null && draft.nodes_revision!=node_revision)reject('revision','节点已改变，请刷新');
    if(draft.revision!=before) reject('revision','配置已被修改，请刷新后重新编辑');
    if(fingerprint(ENGINE+'/lanekeep-gen.uc')!=GENERATOR_SHA) reject('generator','现役生成器版本不同，请先核对广播/组播保护');
    let data=read_config('/etc/config'), hosts=bindings(), previous_rules=data.rules;
    for(let g in ASSIGN) if(!text(data.labels[g],80)) reject('config','分组名称异常');
    let previous_unassigned=data.unassigned;
    if(draft.scope=='members') data.members=validate_members(keep_optional_members(draft.members,data.members),hosts);
    else {
        // A settings-only draft (for example the unassigned choice) keeps the saved rules.
        data.rules=validate_rules(draft.rules ?? previous_rules,data.rules);
        data.unassigned=draft.unassigned ?? data.unassigned;
        let next=validate_settings({fallbacks:draft.fallbacks ?? data.fallbacks,real_dns:draft.real_dns ?? data.real_dns,group_nodes:draft.group_nodes ?? data.group_nodes},current_nodes());
        data.group_nodes=next.group_nodes;data.fallbacks=next.fallbacks;data.real_dns=next.real_dns;
        for(let i=0;i<length(data.rules);i++) {
            let r=data.rules[i], selected=data.group_nodes[r.group] || '';
            if(r.type=='ip' && r.enabled=='1' && r.action=='proxy' && selected!='' && filter(current_nodes().nodes,n=>n.id==selected)[0]?.protocol=='chain')
                reject('rules.'+i+'.action','本模式的节点是两跳链，IP 规则暂不支持两跳链；请改选“指定节点”、直连或阻断');
        }
    }
    ensure_root(); gc(); ensure_no_active();
    let id=uuid(),dir=ROOT+'/'+id;
    if(fs.lstat(dir)!=null || !fs.mkdir(dir,448)) reject('storage','不能新建草稿');
    write(dir+'/state.json',{state:'invalid',created_at:time(),message:'草稿尚未通过校验'});
    fs.writefile(dir+'/lanekeep',encode(data)); fs.chmod(dir+'/lanekeep',384);
    fs.writefile(dir+'/dhcp',fs.readfile('/etc/config/dhcp')); fs.chmod(dir+'/dhcp',384);
    write(dir+'/nodes.json',current_nodes());
    if(fingerprint('/etc/config/lanekeep')!=before || fingerprint('/etc/config/dhcp')!=dhcp) reject('revision','校验期间配置发生变化，请刷新');
    let output=run(ENGINE+'/lanekeep-gen --config-dir '+q(dir)+' --nodes-file '+q(dir+'/nodes.json')+' --output-dir '+q(dir+'/generated')+' --previous-dir /etc/config >'+q(dir+'/generator-output')+' 2>&1');
    if(output==null || !regular(dir+'/generated/validated')) {
        reject('draft','生成器拒绝草稿；未写入生产配置，请核对规则或静态绑定');
    }
    let summary=obj(dir+'/generated/summary.json'), kind=config_kind(summary,dir+'/generated/config.json',PROXY+'/config.json');
    // Notes are editable user metadata; include them in the confirmation diff.
    let old_by_id={},new_by_id={};
    for(let r in previous_rules) old_by_id[r.id]=r;
    for(let r in data.rules) new_by_id[r.id]=r;
    summary.added=map(summary.added,(r)=>new_by_id[r.id]);
    summary.removed=map(summary.removed,(r)=>old_by_id[r.id]);
    summary.changed=map(summary.changed,(r)=>({before:old_by_id[r.before.id],after:new_by_id[r.after.id]}));
    if(!has(['rules','members','metadata','unchanged'],kind)) reject('draft','无法判定改动类型');
    if(draft.scope=='members' && kind=='rules' || draft.scope=='rules' && length(summary.member_changes || [])) reject('draft','拒绝规则与成员混合变化');
    let impact={restart_required:enabled()&&kind=='rules',message:kind=='rules' ? '应用规则会重启核心；失败会自动回退，可能再重启一次。预计约10秒短暂中断；这是估计，非本次实测。最多等待60秒门控OPEN。' : '仅成员或元数据应用，不重启核心、不清连接、不重建共享FakeDNS。已有连接可能沿旧组，新连接按新组。'};
    impact.entry_warnings=dedicated.warnings(previous_rules,data.rules);
    impact.settings_warnings=settings.warnings(summary);
    if(previous_unassigned!=data.unassigned){let moving=unassigned_hosts(hosts,data.members);
        if(length(moving))push(impact.settings_warnings,'以下已固定 IP 但没有明确分组的设备会随之进入'+LABELS[data.unassigned]+'组：'+join('、',map(moving,h=>h.name+'（'+h.ip+'）'))+'。如需保持原模式，请先在设备页把它们从“跟随默认”改成具体模式并应用。');}
    let meta={id:id,base_uci:before,base_dhcp:dhcp,base_nodes:node_revision,kind:kind,scope:draft.scope,summary:public_summary(summary),impact:impact,origin:origin || 'edit',created_at:time()};
    if(caps.revision()!=cap_revision)reject_import('revision_changed','capabilities','校验期间能力表变化');
    meta.node_caps_revision=cap_revision;
    write(dir+'/meta.json',meta); write(dir+'/state.json',{state:'validated',created_at:time(),message:'校验通过，尚未应用'});
    return {ok:true,draft_id:id,change_kind:kind,summary:meta.summary,impact:impact,errors:[]};
}
function builtins(config) {
    let store=current_nodes();
    let result={standard:[],global:[],enhanced:[],ondemand:[]};
    let positions={}, layout={builtin:result,positions:positions,verified:false};
    if(fingerprint(PROXY+'/template.json')!='e96ccc016c0a0c169becc0b341b5a6dbdaf526dc86adec0558b895dbb8907633') return layout;
    let template=obj(PROXY+'/template.json'),active=obj(PROXY+'/config.json');
    try{active=settings.standard_dns_base(active);}catch(e){return layout;}
    let live=active?.routing?.rules,offset=0;
    if(type(live)!='array') return layout;
    let roots=store.default_node?[store.default_node]:[];for(let r in config.rules)if(r.enabled=='1'&&r.action=='node')push(roots,r.node);
    for(let g in GROUPS){if(config.group_nodes[g])push(roots,config.group_nodes[g]);if(config.fallbacks[g].action=='node')push(roots,config.fallbacks[g].node);}
    try{nodes.assert_chain_outbounds(active,store,nodes.chain_closure(store,roots));}catch(e){nodes.take_error();return layout;}
    for(let user in config.rules) positions[user.id]=[];
    let names={'geosite:private':'私有域名分类','domain:lan':'.lan域名及子域','domain:local':'.local域名及子域',
        'geosite:category-doh':'已知DoH域名分类','geosite:icloudprivaterelay':'iCloud Private Relay域名分类',
        'geosite:geolocation-!cn':'明确非中国域名分类','geosite:cn':'中国域名分类',
        'geosite:apple':'Apple域名分类','geosite:microsoft':'Microsoft域名分类','geosite:google':'Google域名分类',
        'geosite:github':'GitHub域名分类','geosite:steam':'Steam域名分类','geosite:youtube':'YouTube域名分类',
        'geosite:netflix':'Netflix域名分类','geosite:disney':'Disney域名分类',
        'geoip:private':'私有IP分类','geoip:cn':'中国IP分类',
        'ext:lanekeep-services.dat:google':'Google IP分类','ext:lanekeep-services.dat:netflix':'Netflix IP分类'};
    let actions={'direct':'直连','proxy-default':'代理','block':'阻断','lan-dns-out':'共享DNS处理','direct-router-dns':'路由器DNS（dnsmasq）'};
    for(let i=0;i<length(template.routing.rules);i++) {
        let r=template.routing.rules[i];
        let entries=dedicated.active(config.rules);
        if(dedicated.dns_anchor(r))for(let entry in entries)for(let generated in dedicated.routes(entry,store)) {
            if(!equal(live[offset],json(lan.expand(sprintf('%J',generated)))))return layout;
            push(positions[entry.id],offset+1);offset++;
        }
        r=settings.route(dedicated.protected_rule(r,length(entries)>0),config,store);
        if(r.__lanekeep_user_slot!=null) {
            let g=r.__lanekeep_user_slot;
            if(!has(GROUPS,g)) return layout;
            push(result[g],{position:null,kind:'user_slot',text:'我的规则插入位置'+(g=='ondemand'?'；代理域名和IP自动先附加相同目标的UDP443保护':'')});
            let generated=[],ids=[],guard=[],guard_ids=[],guard_ip=[],guard_ip_ids=[],current=null;
            for(let user in config.rules) {
                if(user.group!=g || user.enabled!='1' || user.type=='dedicated') continue;
                if(user.type=='geosite') {
                    if(user.value!='category-ads-all' || user.action!='block' || user.node!='')return layout;
                    push(generated,{type:'field',inboundTag:[TAGS[g]],domain:['geosite:category-ads-all'],outboundTag:'block'});
                    push(ids,[user.id]);current=null;continue;
                }
                // Mirrors lanekeep-gen render_group: IP entries never share a row with domains.
                let field=user.type=='ip'?'ip':'domain',entry=user.type=='ip'?user.value:user.type+':'+user.value,outbound=(user.action=='node'?nodes.route_tag(user.node,store):user.action=='proxy'?settings.proxy_tag(config,g,store):{direct:'direct',block:'block'}[user.action]);
                if(g=='ondemand' && (user.action=='proxy' || user.action=='node')) {if(field=='ip'){push(guard_ip,entry);push(guard_ip_ids,user.id);}else{push(guard,entry);push(guard_ids,user.id);}}
                if(current==null || current.outboundTag!=outbound || current[field]==null) {
                    current=field=='ip'?{type:'field',inboundTag:[TAGS[g]],ip:[],outboundTag:outbound}:{type:'field',inboundTag:[TAGS[g]],domain:[],outboundTag:outbound};push(generated,current);push(ids,[]);
                }
                push(current[field],entry);push(ids[length(ids)-1],user.id);
            }
            if(length(guard)) {
                if(!equal(live[offset],{type:'field',inboundTag:[TAGS.ondemand],network:'udp',port:'443',domain:guard,outboundTag:'block'})) return layout;
                for(let id in guard_ids) push(positions[id],offset+1);offset++;
            }
            if(length(guard_ip)) {
                if(!equal(live[offset],{type:'field',inboundTag:[TAGS.ondemand],network:'udp',port:'443',ip:guard_ip,outboundTag:'block'})) return layout;
                for(let id in guard_ip_ids) push(positions[id],offset+1);offset++;
            }
            for(let n=0;n<length(generated);n++)for(let row in nodes.chain_rules(generated[n],store)){
                if(!equal(live[offset],json(lan.expand(sprintf('%J',row)))))return layout;
                for(let id in ids[n])push(positions[id],offset+1);offset++;
            }
            continue;
        }
        for(let row in nodes.chain_rules(r,store)){
            let udp_dns=dns_idle.udp_rule(row);
            if(udp_dns!=null){if(!equal(live[offset],udp_dns))return layout;offset++;
                for(let g in GROUPS)if(has(udp_dns.inboundTag,TAGS[g]))push(result[g],{position:offset,kind:'fixed',text:'UDP，目标端口 53 → 共享DNS处理'});
            }
            if(!equal(live[offset],json(lan.expand(sprintf('%J',row)))))return layout;offset++;
            for(let g in GROUPS){
                if(!has(row.inboundTag||[],TAGS[g]))continue;let conditions=[];
                if(row.network)push(conditions,row.network=='tcp,udp'?'TCP或UDP':uc(row.network));
                if(row.port)push(conditions,'目标端口 '+row.port);
                for(let field in ['domain','ip'])if(type(row[field])=='array')push(conditions,join(' / ',map(row[field],v=>names[v]||v)));
                let final=settings.fallback_group(r)==g&&row.outboundTag==r.outboundTag;
                let end=row.domain==null&&row.ip==null&&row.port==null?'（本组最终默认）':'';
                push(result[g],{position:offset,kind:final?'fallback':'fixed',text:join('，',conditions)+' → '+(final?exit_label(config.fallbacks[g]):actions[row.outboundTag]||(substr(row.outboundTag,0,6)=='chain-'?'链 '+substr(row.outboundTag,6):substr(row.outboundTag,0,5)=='node-'?'节点 '+substr(row.outboundTag,5):'固定内部处理'))+end});
            }
        }
    }
    layout.verified=offset==length(live);return layout;
}
function logs() {
    let result=[];
    for(let line in split(fs.readfile(PROXY+'/panel-apply.log') || '', '\n')) {
        if(!length(line) || length(line)>65536) continue;
        try { let entry=json(line); if(type(entry)=='object' && text(entry.version,48)) push(result,entry); } catch(e) {}
    }
    return result;
}
function public_log(entry) {
    if(!entry) return null;
    let allowed=['applied','rolled_back','failed_blocked','members_applied','metadata_applied','members_rolled_back','members_rollback_failed'];
    return {version:entry.version,time_utc:entry.time_utc,result:has(allowed,entry.result)?entry.result:'unknown',elapsed_seconds:entry.elapsed_seconds,
        summary:summary_text(entry.changes)};
}
function historical_log(entry,history) {
    let result=public_log(entry);if(!result || entry.changes?.node_summary_version==1)return result;
    if(!has(['applied','members_applied','metadata_applied'],entry.result))return result;
    try {
        let before=snapshot_nodes(PROXY+'/versions/'+entry.version),after=null,pos=-1;
        for(let i=0;i<length(history);i++)if(history[i].version==entry.version)pos=i;
        // Only use the immediately following operation's BEFORE snapshot, never a failed draft.
        if(pos>=0 && pos+1<length(history))after=snapshot_nodes(PROXY+'/versions/'+history[pos+1].version);
        else if(pos==length(history)-1)after=current_nodes();
        if(after){let d=store_diff(before,after),s=clone(entry.changes || {});s.node_changes=d.node_changes;s.default_node_change=d.default_node_change;result.summary=summary_text(s)+(length(d.node_changes)||d.default_node_change?'（节点明细由相邻状态对照补全）':'');}
    } catch(e) { failure=null;result.summary+='；旧记录的节点明细不可还原'; }
    return result;
}
function restore_history(version) {
    let history=logs(),base=replace(version,/^failed-/,''),pos=-1,items=[];
    for(let i=0;i<length(history);i++)if(history[i].version==base)pos=i;
    if(pos>=0)for(let i=pos+1;i<length(history);i++) {
        let e=history[i];if(has(['applied','members_applied','metadata_applied','failed_blocked','members_rollback_failed'],e.result))push(items,historical_log(e,history));
    }
    return {whole_state:true,selected_operation:base,later_operations:items,history_complete:pos>=0,
        message:'这是完整状态恢复：所选操作及之后的规则、专用入口、分组、节点和默认选择都可能被撤销。最终以当前状态与目标快照的差异为准。'};
}
// Kill-switch snapshot shared by status and the nodes page. A missing or stale gate file yields fresh:false.
function gate_snapshot(service,uptime) {
    let gate={};
    for(let line in split(fs.readfile('/tmp/lanekeep-dns-gate/status') || '', '\n')) { let pair=split(line,'='); if(length(pair)==2) gate[pair[0]]=pair[1]; }
    let fresh=match(gate.uptime_seconds || '',/^[0-9]+$/)!=null && uptime>=int(gate.uptime_seconds) && uptime-int(gate.uptime_seconds)<=5;
    let lease_raw=run('nft -j list set inet lanekeep_dns_gate healthy_data'); let leased=false;
    if(lease_raw) for(let e in json(lease_raw).nftables || []) if(e.set?.name=='healthy_data') for(let element in e.set.elem || []) {
        let v=element.elem || element; if(v.val==30241 && type(v.expires)=='int' && v.expires>0) leased=true;
    }
    return {state:service?.core?.running==true && service?.dns_gate?.running==true && fresh && leased && gate.state=='OPEN'?'OPEN':'CLOSED',fresh:fresh,lease_valid:leased};
}
function status(args) {
    safe_keys(args,['job_id'],'status');
    if(args.job_id!=null && args.job_id!='' && !valid_id(args.job_id)) reject('job_id','任务编号无效');
    let revision=fingerprint('/etc/config/lanekeep'), dhcp_revision=fingerprint('/etc/config/dhcp');
    let config=read_config('/etc/config'), hosts=bindings();
    let counts={standard:0,global:0,enhanced:0,ondemand:0,direct:0}, assigned={}, warnings=[];
    for(let h in hosts) { h.group=group_for(h.ip,config.members,config.unassigned); h.explicit=length(filter(ASSIGN,g=>has(config.members[g],h.ip)))>0; counts[h.group]++; assigned[h.ip]=true; }
    for(let g in ASSIGN) for(let address in config.members[g]) if(!assigned[address]) push(warnings,LABELS[g]+'组成员 '+address+' 已失去DHCP静态绑定，提交前请修复');
    let dynamic=[];
    for(let line in split(fs.readfile('/tmp/dhcp.leases') || '', '\n')) {
        let m=match(line,/^([0-9]+) [^ ]+ ([^ ]+) ([^ ]+) /);
        if(!m || !ip_ok(m[2]) || assigned[m[2]] || int(m[1])!=0 && int(m[1])<time()) continue;
        push(dynamic,{ip:m[2],name:clean_name(m[3]=='*'?'未命名设备':m[3])});
    }
    let raw=run("ubus -t 2 call service list '{\"name\":\"lanekeep-xray\"}'");
    let service=raw ? json(raw)?.['lanekeep-xray']?.instances : null;
    let core={running:service?.core?.running==true,uptime_seconds:null};
    let uptime=int(split(fs.readfile('/proc/uptime') || '0',' ')[0]), pid=service?.core?.pid;
    if(core.running && type(pid)=='int' && pid>0) {
        // Linux arm64 exports proc/stat clock ticks in USER_HZ=100.
        let stat=fs.readfile('/proc/'+pid+'/stat'), tail=stat ? split(stat,') ')[1] : null;
        let fields=tail ? split(tail,' ') : [];
        if(length(fields)>19) { let elapsed=uptime-int(fields[19])/100; core.uptime_seconds=elapsed>0?int(elapsed):0; }
    }
    let gate=gate_snapshot(service,uptime);
    if(!gate.fresh) push(warnings,'门控状态过期或不可读，按CLOSED显示');
    if(fingerprint(ENGINE+'/lanekeep-gen.uc')!=GENERATOR_SHA) push(warnings,'生成器版本不同，已禁用提交；请先核对广播/组播保护');
    if(enabled()&&!settings.standard_dns_active(obj(PROXY+'/config.json')))push(warnings,'常规组受保护DNS解析未完整启用；增强、全局及按需保持原解析，不代表已通过客户端泄露测试');
    let history=logs(),layout=builtins(config);
    if(!layout.verified) push(warnings,'现役规则与模板/用户配置不一致，暂不显示生效序号；请先核对配置');
    for(let r in config.rules) r.positions=layout.verified ? layout.positions[r.id] : [];
    let out={ok:true,revision:revision,core:core,gate:gate,
        current_version:'lanekeep-'+substr(revision,0,12),last_apply:public_log(history[length(history)-1]),counts:counts,
        count_basis:'DHCP静态分配数量，非在线设备数量；其它动态或未知LAN设备默认'+LABELS[config.unassigned]+'组',warnings:warnings,
        config:{revision:revision,members:config.members,rules:config.rules,group_nodes:config.group_nodes,fallbacks:config.fallbacks,real_dns:config.real_dns,unassigned:config.unassigned},devices:{static:hosts,dynamic:dynamic,dhcp_path:['admin','network','dhcp']},builtin:layout.verified ? layout.builtin : {standard:[],global:[],enhanced:[],ondemand:[]},
        rule_types:['domain','full','keyword','ip','dedicated','geosite']};
    if(fingerprint('/etc/config/lanekeep')!=revision || fingerprint('/etc/config/dhcp')!=dhcp_revision) reject('revision','读取期间配置发生变化，请刷新');
    let ns=current_nodes(),dn=filter(ns.nodes,n=>n.id==ns.default_node)[0];out.default_node=dn?{id:dn.id,name:dn.name,last_test:last_test(dn.id)}:null;out.lan={address:lan.context().address,subnet:lan.context().subnet};out.lifecycle={enabled:enabled()};out.nodes_revision=nodes_revision();
    try { out.home=home.read([...hosts,...map(dynamic,h=>({...h,group:group_for(h.ip,config.members,config.unassigned)}))],config,layout.verified);out.policy_check=out.home.policy_check; } catch(e) { out.home={rules_checked:false,rules_message:'状态核对暂不可读',devices:[],privacy_ok:null,supervisor:{available:false,retry_seconds:60}}; }
    if(args.job_id) out.job=job_state(args.job_id);
    return out;
}
function apply(args) {
    safe_keys(args,['draft_id','confirm','owner','trial_ack'],'apply');
    if(!valid_id(args.draft_id)) reject('draft_id','草稿编号无效');
    let dir=ROOT+'/'+args.draft_id;
    if(fs.lstat(dir)?.type!='directory' || !regular(dir+'/meta.json') || !regular(dir+'/state.json')) reject('draft_id','草稿不存在或已过期，请重新校验');
    let meta=obj(dir+'/meta.json'),state=obj(dir+'/state.json');
    if(meta.trial_required&&(args.trial_ack!=true||!valid_id(args.owner)||args.owner!=meta.trial_owner||caps.revision()!=meta.trial_revision))reject_import('trial_confirmation_required','trial_ack','请在当前会话勾选未验证试用并重新确认');
    if(meta.node_caps_revision&&caps.revision()!=meta.node_caps_revision)reject_import('revision_changed','capabilities','能力表已变化，请重新校验节点');
    if(meta.import_source_binding)sub_api().check(meta.import_source_binding);
    if(meta.scope=='nodes'){let proposed=nodes.read_store(dir+'/nodes.json');require_store_capacity(proposed);nodes.validate_chains(proposed,true);check_udp_receipts(meta,proposed,args.owner);}
    if(meta.trial_required){meta.trial_acknowledged=true;write(dir+'/meta.json',meta);}
    if(meta.import_owner&&(meta.import_owner!=args.owner||caps.revision()!=meta.import_caps_revision))reject_import('revision_changed','preview_id','登录会话或能力表已变化，请重新预览');
    if(state.state!='validated') return {ok:true,job_id:args.draft_id,state:state.state,message:'返回已有任务，不重复提交'};
    if(time()-meta.created_at>1200) reject('draft_id','草稿超过20分钟，请重新校验');
    let expected=meta.kind=='restore'?'restore':meta.kind=='rules'?'rules':meta.kind=='unchanged'?'unchanged':'members';
    if(args.confirm!=expected) reject('confirm','尚未确认本次实际影响');
    ensure_no_active();
    if(fingerprint('/etc/config/lanekeep')!=meta.base_uci || fingerprint('/etc/config/dhcp')!=meta.base_dhcp || nodes_revision()!=meta.base_nodes) reject('revision','校验后配置发生变化，请重新校验');
    if(fingerprint(ENGINE+'/lanekeep-gen.uc')!=GENERATOR_SHA) reject('generator','生成器版本发生变化');
    may_have_started=true;
    write(dir+'/state.json',{state:'pending',created_at:meta.created_at,started_at:time(),message:'已接收，正在等待统一应用'});
    let rc=system(CODE+'/worker '+args.draft_id+' </dev/null >/dev/null 2>&1 &');
    if(rc!=0) write(dir+'/state.json',{state:'failed',created_at:meta.created_at,finished_at:time(),result:'launch_failed',message:'任务未启动，未执行应用；请先刷新状态'});
    return {ok:true,job_id:args.draft_id,state:rc==0?'pending':'failed'};
}
function execute_restore(id,dir,meta,state) {
    let results=[],members_done=false,members_needed=false;
    for(let phase in meta.phases) if(phase.name=='members') members_needed=true;
    for(let phase in meta.phases) {
        if(!has(['members','rules'],phase.name) || !has(['rules','members','metadata'],phase.kind) || !match(phase.expected_uci || '',/^[a-f0-9]{64}$/) || !match(phase.input_sha || '',/^[a-f0-9]{64}$/)) reject('draft','恢复任务格式异常');
        let part=dir+'/'+phase.name;
        if(fingerprint(part+'/lanekeep')!=phase.input_sha || fingerprint(part+'/nodes.json')!=phase.input_nodes_sha || fingerprint('/etc/config/lanekeep')!=phase.expected_uci || fingerprint('/etc/config/dhcp')!=meta.base_dhcp || nodes_revision()!=phase.expected_nodes || fingerprint(ENGINE+'/lanekeep-gen.uc')!=GENERATOR_SHA) {
            let message=members_done?'分组已恢复；规则未执行，因为两步之间配置发生变化。请刷新核对，未覆盖新的改动。':'配置或恢复草稿发生变化，本次未恢复，请刷新。';
            write(dir+'/state.json',{state:'failed',created_at:meta.created_at,started_at:state.started_at,finished_at:time(),result:members_done?'partial_restore':'rejected',phases:results,message:message});
            return {ok:false,state:'failed'};
        }
        let command=ENGINE+'/lanekeep-apply --draft-dir '+q(part)+' --expected-uci-sha '+phase.expected_uci+' --expected-dhcp-sha '+meta.base_dhcp+' --expected-nodes-sha '+phase.expected_nodes;
        if(phase.kind!='rules') command+=' --members-only';
        system(command+' >'+q(part+'/apply-private.log')+' 2>&1; rc=$?; printf "%s\\n" "$rc" >'+q(part+'/exit-code'));
        let raw=trim(fs.readfile(part+'/exit-code') || ''),code=match(raw,/^[0-9]{1,3}$/) ? int(raw) : -1;
        push(results,{part:phase.name,result:code==0?'success':code==20?'rolled_back':'failed',restart_required:phase.kind=='rules'});
        if(code!=0) {
            let blocked=code==21 && has(split(fs.readfile(part+'/apply-private.log') || '', '\n'),'LANEKEEP_APPLY_FAILED_BLOCKED');
            let lead=members_done?'分组已恢复；':members_needed?'分组尚未恢复；':'分组与目标相同，未改动；';
            let message=lead+(phase.name=='rules'?'规则恢复未成功。':'分组恢复未成功，规则未执行。')+(blocked?'本步骤已恢复原节点配置，但门控未恢复OPEN；代理出口保持阻断，核心已停止，可在LAN选择可用节点。':code==20?'本步骤已由统一应用退回到该步骤开始前。':'请先核对当前配置与门控，不要重复提交。');
            write(dir+'/state.json',{state:members_done?'failed':code==20?'rolled_back':'failed',created_at:meta.created_at,started_at:state.started_at,finished_at:time(),result:members_done?'partial_restore':code==20?'rolled_back':'failed',phases:results,message:message});
            return {ok:false,state:'failed'};
        }
        if(phase.name=='members') members_done=true;
        // Keep the completed first step visible if the process is interrupted before step two.
        write(dir+'/state.json',{state:'running',created_at:meta.created_at,started_at:state.started_at,worker_pid:int(fs.readlink('/proc/self') || '0'),phases:results,message:members_done?'分组已恢复，正在处理有差异的规则':'正在恢复规则'});
    }
    write(dir+'/state.json',{state:'success',created_at:meta.created_at,started_at:state.started_at,finished_at:time(),result:'restored',phases:results,message:'已按顺序恢复所有有差异的部分；相同部分已跳过。请查看当前状态。'});
    return {ok:true,state:'success'};
}
function execute(id) {
    if(!valid_id(id)) reject('job_id','任务编号无效');
    let dir=ROOT+'/'+id;
    if(fs.lstat(dir)?.type!='directory' || !regular(dir+'/meta.json') || !regular(dir+'/state.json')) reject('job_id','任务不可读取');
    let meta=obj(dir+'/meta.json'),state=obj(dir+'/state.json');
    if(state.state!='pending') return {ok:true,state:state.state};
    write(dir+'/state.json',{state:'running',created_at:meta.created_at,started_at:time(),worker_pid:int(fs.readlink('/proc/self') || '0'),message:'统一应用处理中，请勿重复提交'});
    try {
        if(meta.node_caps_revision&&caps.revision()!=meta.node_caps_revision)reject_import('revision_changed','capabilities','能力表已变化，本次未应用');
        if(meta.import_source_binding)sub_api().check(meta.import_source_binding);
        if(meta.trial_required&&(meta.trial_acknowledged!=true||caps.revision()!=meta.trial_revision))reject('trial_ack','未验证试用确认已失效');
        if(meta.scope=='nodes'){let proposed=nodes.read_store(dir+'/nodes.json');require_store_capacity(proposed);nodes.validate_chains(proposed,true);check_udp_receipts(meta,proposed,meta.udp_owner);}
        if(fingerprint('/etc/config/lanekeep')!=meta.base_uci || fingerprint('/etc/config/dhcp')!=meta.base_dhcp || nodes_revision()!=meta.base_nodes || fingerprint(ENGINE+'/lanekeep-gen.uc')!=GENERATOR_SHA) reject('revision','生效配置或生成器已变化，本次未应用');
        if(!match(meta.base_uci,/^[a-f0-9]{64}$/) || !match(meta.base_dhcp,/^[a-f0-9]{64}$/)) reject('revision','基线摘要异常');
        if(meta.kind=='unchanged') {
            write(dir+'/state.json',{state:'success',created_at:meta.created_at,started_at:state.started_at,finished_at:time(),result:'unchanged',message:'与当前相同，未执行应用。'});
            return {ok:true,state:'success'};
        }
        if(meta.kind=='restore') return execute_restore(id,dir,meta,state);
        let command=ENGINE+'/lanekeep-apply --draft-dir '+q(dir)+' --expected-uci-sha '+meta.base_uci+' --expected-dhcp-sha '+meta.base_dhcp+' --expected-nodes-sha '+meta.base_nodes;
        if(meta.kind!='rules') command+=' --members-only';
        system(command+' >'+q(dir+'/apply-private.log')+' 2>&1; rc=$?; printf "%s\\n" "$rc" >'+q(dir+'/exit-code'));
        let raw=trim(fs.readfile(dir+'/exit-code') || '');
        let code=match(raw,/^[0-9]{1,3}$/) ? int(raw) : -1;
        let blocked=code==21 && has(split(fs.readfile(dir+'/apply-private.log') || '', '\n'),'LANEKEEP_APPLY_FAILED_BLOCKED');
        let done=code==0?'success':code==20?'rolled_back':'failed';
        let message=blocked?'已恢复原节点配置，但原节点未恢复可用；代理出口仍处于阻断状态，核心已停止。可在LAN选择可用节点。':code==0?'应用完成；请查看当前默认节点与门控状态':code==20?'已退回原节点；若原节点也不通，代理出口仍处于阻断状态':'应用未成功；请先核对状态，不要盲目重复提交';
        write(dir+'/state.json',{state:done,created_at:meta.created_at,started_at:state.started_at,finished_at:time(),result:code==0?(meta.kind=='members'?'members_applied':meta.kind=='metadata'?'metadata_applied':meta.kind=='unchanged'?'unchanged':'applied'):code==20?'rolled_back':blocked?'rolled_back_blocked':'failed',message:message});
        return {ok:true,state:done};
    } catch(e) {
        let completed=obj(dir+'/state.json')?.phases || [];
        write(dir+'/state.json',{state:'failed',created_at:meta.created_at,finished_at:time(),result:length(completed)?'partial_restore':'rejected',phases:completed,message:(length(completed)?'已有恢复步骤完成，后续步骤未确认完成。':'')+(failure?.message || '任务失败，请先核对现状')});
        return {ok:false,state:'failed'};
    }
}
function version_id(value) { return type(value)=='string' && match(value,/^(failed-)?[0-9]{8}T[0-9]{6}Z-[0-9]+$/)!=null; }
function restore_phase(parent,name,data,previous,previous_config,expected_uci,node_store) {
    let dir=parent+'/'+name;
    if(!fs.mkdir(dir,448)) reject('storage','不能创建恢复草稿');
    if(fs.writefile(dir+'/lanekeep',encode(data))==null || fs.writefile(dir+'/dhcp',fs.readfile('/etc/config/dhcp'))==null) reject('storage','不能保存恢复草稿');
    fs.chmod(dir+'/lanekeep',384);fs.chmod(dir+'/dhcp',384);
    write(dir+'/nodes.json',node_store || current_nodes());
    let output=run(ENGINE+'/lanekeep-gen --config-dir '+q(dir)+' --nodes-file '+q(dir+'/nodes.json')+' --output-dir '+q(dir+'/generated')+' --previous-dir '+q(previous)+' >'+q(dir+'/generator-output')+' 2>&1');
    if(output==null || !regular(dir+'/generated/validated')) reject('version_id','历史配置未通过当前生成器校验，尚未应用');
    let summary=obj(dir+'/generated/summary.json'),kind=config_kind(summary,dir+'/generated/config.json',previous_config);
    let previous_nodes=regular(previous+'/nodes.json')?nodes.read_store(previous+'/nodes.json'):current_nodes();
    if(kind!='rules' && kind!='members' && !equal(node_store || current_nodes(),previous_nodes))kind='metadata';
    if(name=='members' && kind=='rules' || name=='rules' && length(summary.member_changes || [])) reject('version_id','恢复步骤包含不允许的混合变化');
    return {name:name,kind:kind,expected_uci:expected_uci,input_sha:fingerprint(dir+'/lanekeep'),summary:summary};
}
function prepare_restore(target,version,target_nodes) {
    let cap_revision=caps.revision();
    let before=fingerprint('/etc/config/lanekeep'),dhcp=fingerprint('/etc/config/dhcp'),node_revision=nodes_revision();
    if(fingerprint(ENGINE+'/lanekeep-gen.uc')!=GENERATOR_SHA) reject('generator','现役生成器版本不同，请先核对广播/组播保护');
    nodes.validate_store(target_nodes);nodes.validate_chains(target_nodes,true);require_store_capacity(target_nodes);
    let current=read_config('/etc/config'),hosts=bindings();
    target.members=validate_members(target.members,hosts);
    target.rules=validate_rules(historical_rules(target.rules),current.rules,target_nodes);
    let target_settings=validate_settings({fallbacks:target.fallbacks,real_dns:target.real_dns,group_nodes:target.group_nodes},target_nodes);
    target.group_nodes=target_settings.group_nodes;target.fallbacks=target_settings.fallbacks;target.real_dns=target_settings.real_dns;
    target.unassigned=target.unassigned ?? 'standard';if(!settings.unassigned_ok(target.unassigned))reject('version_id','历史配置的未分组设备设置无效');
    for(let g in ASSIGN) if(!text(current.labels[g],80)) reject('config','分组名称异常');
    ensure_root();gc();ensure_no_active();
    let id=uuid(),dir=ROOT+'/'+id;
    if(fs.lstat(dir)!=null || !fs.mkdir(dir,448)) reject('storage','不能新建恢复草稿');
    write(dir+'/state.json',{state:'invalid',created_at:time(),message:'恢复草稿尚未通过校验'});
    let member_data=clone(current);member_data.members=target.members;
    let member=restore_phase(dir,'members',member_data,'/etc/config',PROXY+'/config.json',before);
    let rule_data=clone(member_data);rule_data.group_nodes=target.group_nodes;rule_data.rules=target.rules;rule_data.fallbacks=target.fallbacks;rule_data.real_dns=target.real_dns;rule_data.unassigned=target.unassigned;
    let rule=restore_phase(dir,'rules',rule_data,dir+'/members',dir+'/members/generated/config.json',member.kind=='unchanged'?before:member.input_sha,target_nodes);
    let summary=attach_notes(rule.summary,current.rules,target.rules);
    let old_nodes=current_nodes();summary.node_changes=[];for(let n in target_nodes.nodes){let old=filter(old_nodes.nodes,x=>x.id==n.id)[0];if(!old || !equal(old,n))push(summary.node_changes,{id:n.id,name:n.name,action:old?'恢复':'新增',protocol:n.protocol,server:n.server,port:n.port});}for(let n in old_nodes.nodes)if(!length(filter(target_nodes.nodes,x=>x.id==n.id)))push(summary.node_changes,{id:n.id,name:n.name,action:'移除',protocol:n.protocol,server:n.server,port:n.port});
    if(old_nodes.default_node!=target_nodes.default_node)summary.default_node_change={before_name:(filter(old_nodes.nodes,n=>n.id==old_nodes.default_node)[0]?.name || ''),after_name:(filter(target_nodes.nodes,n=>n.id==target_nodes.default_node)[0]?.name || '')};
    summary.affected_chains=nodes.chain_impact(old_nodes,target_nodes);
    summary.member_changes=member.summary.member_changes;
    member.expected_nodes=node_revision;member.input_nodes_sha=fingerprint(dir+'/members/nodes.json');
    rule.expected_nodes=member.kind=='unchanged'?node_revision:member.input_nodes_sha;rule.input_nodes_sha=fingerprint(dir+'/rules/nodes.json');
    let phases=[];
    for(let phase in [member,rule]) if(phase.kind!='unchanged') push(phases,{name:phase.name,kind:phase.kind,expected_uci:phase.expected_uci,input_sha:phase.input_sha,expected_nodes:phase.expected_nodes,input_nodes_sha:phase.input_nodes_sha});
    if(fingerprint('/etc/config/lanekeep')!=before || fingerprint('/etc/config/dhcp')!=dhcp) reject('revision','校验期间配置发生变化，请刷新');
    let kind=length(phases)?'restore':'unchanged',restart=rule.kind=='rules';
    let impact={restart_required:restart,message:restart?'先恢复有差异的分组，再恢复规则并重启核心；失败时当前步骤自动退回，已成功的前一步会明确保留并报告。':'只恢复有差异的分组或规则信息，不重启核心；相同部分跳过。',member_change:member.kind!='unchanged',rules_change:rule.kind!='unchanged'};
    impact.entry_warnings=dedicated.warnings(current.rules,target.rules);
    impact.settings_warnings=settings.warnings(summary);
    let meta={id:id,kind:kind,scope:'all',base_uci:before,base_dhcp:dhcp,base_nodes:node_revision,summary:public_summary(summary),impact:impact,origin:'restore:'+version,phases:phases,created_at:time()};
    if(caps.revision()!=cap_revision)reject_import('revision_changed','capabilities','校验期间能力表变化');
    meta.node_caps_revision=cap_revision;
    write(dir+'/meta.json',meta);write(dir+'/state.json',{state:'validated',created_at:meta.created_at,message:'恢复校验通过，尚未应用'});
    return {ok:true,draft_id:id,change_kind:kind,summary:meta.summary,impact:impact,errors:[],restore:{version_id:version,scope:'all',message:'按顺序恢复有差异的分组和规则；执行前只需本次确认，若后一步失败会明确报告已完成的部分。'}};
}
function versions(args) {
    safe_keys(args,[],'versions'); let result=[],history=logs(),by_id={},revision=fingerprint('/etc/config/lanekeep'),current=read_config('/etc/config');
    for(let log in history) by_id[log.version]=log;
    for(let id in reverse(sort(fs.lsdir(PROXY+'/versions') || []))) {
        if(!version_id(id)) continue;
        let dir=PROXY+'/versions/'+id;
        if(fs.lstat(dir)?.type!='directory' || !regular(dir+'/lanekeep')) continue;
        let failed=substr(id,0,7)=='failed-', base=failed?substr(id,7):id;
        if(!failed && fs.readfile(dir+'/owner')!='lanekeep-panel-v1\n') continue;
        if(!failed && regular(PROXY+'/versions/failed-'+base+'/lanekeep')) continue;
        let log=historical_log(by_id[base],history);
        let same=false;
        try {let saved=read_config(dir);same=same_members(saved.members,current.members) && equal(historical_rules(saved.rules),current.rules) && same_settings(saved,current) && equal(regular(dir+'/nodes.json')?nodes.read_store(dir+'/nodes.json'):nodes.migrate(obj(dir+'/config.json')),current_nodes());} catch(e) {failure=null;}
        push(result,{id:id,time_utc:split(base,'-')[0],kind:failed?'failed':'snapshot',summary:log?.summary || '历史用户配置；恢复前重新校验',result:log?.result || (failed?'failed':'snapshot'),
            same_current:same,meaning:same?'与当前相同':failed?'重试该次失败的改动；对应应用前记录已合并':'撤销到这次操作之前，自动恢复有差异的分组和规则'});
    }
    // A failed- prefix must not make an old draft sort newer than all snapshots.
    result=sort(result,(a,b)=>a.time_utc==b.time_utc ? 0 : a.time_utc>b.time_utc?-1:1);
    let selected=[],counts={snapshot:0,failed:0};
    for(let item in result) if(counts[item.kind]<10) {push(selected,item);counts[item.kind]++;}
    if(fingerprint('/etc/config/lanekeep')!=revision) reject('revision','读取期间配置发生变化，请刷新');
    return {ok:true,versions:selected};
}
function rollback(args) {
    safe_keys(args,['version_id','scope','owner'],'rollback');
    if(!version_id(args.version_id)) reject('version_id','版本编号无效');
    if(args.scope!=null && args.scope!='' && args.scope!='all') reject('scope','版本操作自动恢复全部有差异的部分，请刷新页面');
    let dir=PROXY+'/versions/'+args.version_id;
    if(fs.lstat(dir)?.type!='directory' || !regular(dir+'/lanekeep')) reject('version_id','历史用户配置不存在');
    if(substr(args.version_id,0,7)!='failed-') {
        if(fs.readfile(dir+'/owner')!='lanekeep-panel-v1\n' || !regular(dir+'/manifest.sha256') || system('cd '+q(dir)+' && sha256sum -c manifest.sha256 >/dev/null 2>&1')!=0) reject('version_id','历史快照校验失败');
    }
    let saved_nodes=regular(dir+'/nodes.json')?nodes.read_store(dir+'/nodes.json'):nodes.migrate(obj(dir+'/config.json'));
    let result=prepare_restore(read_config(dir),args.version_id,saved_nodes);
    result.restore=restore_history(args.version_id);return result;
}

function node_list(args) {
    safe_keys(args,['offset','revision'],'nodes');let revision=nodes_revision();if(args.revision&&args.revision!=revision)reject_import('revision_changed','nodes','节点已变化，请重新分页读取');let store=current_nodes(),data=read_config('/etc/config'),rules=data.rules;
    let result=[];
    for(let n in store.nodes) {
        let p=nodes.public_node(n,store);p.default=n.id==store.default_node;p.references=map(filter(rules,r=>r.action=='node' && r.node==n.id),r=>({id:r.id,group:r.group,type:r.type,enabled:r.enabled,label:LABELS[r.group]+' / '+(r.type=='dedicated'?'专用入口 ':'')+r.value+(r.enabled=='0'?'（停用）':'')}));p.last_test=last_test(n.id);push(result,p);
        for(let ref in nodes.chain_references(store,n.id))push(p.references,{id:ref.id,type:'chain',role:ref.role,enabled:'1',label:'链 '+nodes.display_name(ref.name)+' ('+ref.id+') / '+(ref.role=='front'?'前置':'后置')+'；未被规则使用时仍受删除保护'});
        for(let g in GROUPS)if(data.group_nodes[g]==n.id)push(p.references,{id:'group_proxy_'+g,group:g,type:'group_proxy',enabled:'1',label:LABELS[g]+' / 组代理节点'});
        for(let g in GROUPS)if(data.fallbacks[g].action=='node' && data.fallbacks[g].node==n.id)push(p.references,{id:'fallback_'+g,group:g,type:'fallback',enabled:'1',label:LABELS[g]+' / 兜底出口'});
    }
    // The nodes page shows the kill switch from this snapshot; a read failure stays "unknown" instead of failing the page.
    let gate;
    try { let raw=run("ubus -t 2 call service list '{\"name\":\"lanekeep-xray\"}'"); gate=gate_snapshot(raw ? json(raw)?.['lanekeep-xray']?.instances : null,int(split(fs.readfile('/proc/uptime') || '0',' ')[0])); }
    catch(e) { gate={state:'CLOSED',fresh:false,lease_valid:false}; }
    if(nodes_revision()!=revision)reject('revision','节点已改变，请刷新');
    return sizes.page(result,args.offset||0,{ok:true,revision:revision,uci_revision:fingerprint('/etc/config/lanekeep'),default_node:store.default_node,gate:gate,lifecycle:{enabled:enabled()},runtime_capacity:capacity_runtime(),
      notice:'仅LAN手动切换。健康探测跟随默认节点；门控关闭会阻断所有代理流量，包括指定节点。核心停止时国内业务也可能阻断；无直连回落。'},'nodes');
}

function fetch_subscription(url){return sub_api().once(url);}

reject_import = function(code,param,message){
    failure={ok:false,code:code,message:message,errors:[{field:param||'import',code:code,message:message}]};die('import_rejected');
};
function current_import_bindings(){return {uci_revision:fingerprint('/etc/config/lanekeep'),dhcp_revision:fingerprint('/etc/config/dhcp'),nodes_revision:nodes_revision(),caps_revision:caps.revision(),config_revision:fingerprint(PROXY+'/config.json')};}
sub_api = function(){return subscriptions.bind({reject:reject_import,uuid:uuid,fingerprint:fingerprint,run:run,current_nodes:current_nodes,bindings:current_import_bindings});};
function preview_api(){return previews.bind({root:ROOT,reject:reject_import,ensure_root:ensure_root,write:write,fingerprint:fingerprint,uuid:uuid,valid_id:valid_id,bindings:current_import_bindings,check_source:x=>sub_api().check(x)});}
capacity_runtime = function(){return metric_capacity.runtime();};
require_store_capacity = function(store){if(length(store.nodes)>metric_capacity.MAX_NODES||length(sprintf('%J\n',store))>524288)reject_import('limit_exceeded','nodes','面板试用最多21节点 / 512 KiB');let check=metric_capacity.check_store(store);if(!check.ok)reject_import(check.code,'nodes',check.message);};
function capability_view(args){safe_keys(args,[],'capabilities');return {ok:true,revision:caps.revision(),capabilities:caps.get(),runtime_capacity:capacity_runtime()};}
function subscription_call(method,args){
 if(method=='sub_list'){safe_keys(args,[],'sub_list');return sub_api().list();}
 safe_keys(args,['draft','owner'],method);if(!valid_id(args.owner)||type(args.draft)!='string'||length(args.draft)>16384)reject_import('param_invalid','draft','来源请求格式无效');let d=json(args.draft);
 let fields={sub_save:['operation','revision','source','id','confirm_direct','trial_ack'],sub_refresh:['id','source_revision','trial_ack'],sub_diff:['id','source_revision','cache_version','nodes_revision','caps_revision','offset','filter']};safe_keys(d,fields[method],method);
 if(method=='sub_save'||method=='sub_refresh'){ensure_no_active();if(caps.get().features?.subscriptions?.status=='trial'&&d.trial_ack!=true)reject_import('trial_confirmation_required','trial_ack','请勾选未验证试用');if(index(['trial','loopback','verified'],caps.get().features?.subscriptions?.status)<0)reject_import('verification_pending','subscription','订阅功能尚未完成必要验证');}
 return method=='sub_save'?sub_api().save(d):method=='sub_refresh'?sub_api().refresh(d):sub_api().diff(d);
}
function node_validate(args) {
    safe_keys(args,['draft','owner'],'node_validate');
    if(type(args.draft)!='string'||length(args.draft)>500000)reject('draft','节点草稿格式无效');
    let d=json(args.draft);safe_keys(d,['revision','nodes_revision','operation','node','id','content','subscription_url','allow_failed','preview_id','cache_version','selected_item_ids','quick_protocol','source_id','source_revision','prefix','updates','offset','filter','udp_test_id','trial_ack'],'node');
    let before=fingerprint('/etc/config/lanekeep'),dhcp=fingerprint('/etc/config/dhcp'),revision=nodes_revision();
    if(d.revision!=before || d.nodes_revision!=revision){
        if(has(['import','import_preview','source_preview','preview_page'],d.operation))reject_import('revision_changed','preview_id','配置或节点已改变，请刷新页面后重新预览');
        reject('revision','配置或节点已改变，请刷新');
    }
    let store=current_nodes(),data=read_config('/etc/config'),prev=clone(store),imported=[],import_selection=null;
    let bindings=current_import_bindings(),udp_receipts=[],udp_invalidated=[];
    if(d.operation=='preview_page'){safe_keys(d,['revision','nodes_revision','operation','preview_id','cache_version','offset','filter'],'preview_page');return preview_api().page(d.preview_id,d.cache_version,args.owner,bindings,d.offset||0,d.filter||'');}
    if(d.operation=='source_preview'){safe_keys(d,['revision','nodes_revision','operation','source_id','source_revision','cache_version','selected_item_ids','prefix','updates'],'source_preview');let chosen=sub_api().selected(d);return preview_api().create(null,args.owner,bindings,store,null,{rows:chosen.rows,source_binding:chosen.binding,prefix:d.prefix||'',updates:d.updates||{}});}
    if(d.operation=='import_preview'){
        safe_keys(d,['revision','nodes_revision','operation','content','subscription_url','quick_protocol','trial_ack'],'import');
        if(type(d.content??'')!='string'||type(d.subscription_url??'')!='string'||(length(trim(d.content||''))>0)==(length(trim(d.subscription_url||''))>0))reject_import('param_invalid','content','链接文本与订阅地址请只填一项');
        if(d.quick_protocol!=null&&(!has(['socks5','http'],d.quick_protocol)||length(d.subscription_url||'')))reject_import('param_invalid','quick_protocol','快速粘贴类型无效或与订阅地址冲突');
        ensure_root();ensure_no_active();
        let content=d.content;
        if(d.subscription_url){if(d.trial_ack!=true)reject_import('trial_confirmation_required','trial_ack','试用订阅拉取需勾选确认');try{content=fetch_subscription(d.subscription_url);}catch(e){if(failure)die('subscription_failed');reject_import('fetch_failed','subscription_url','订阅拉取失败，未改变现有节点');}}
        return preview_api().create(content,args.owner,bindings,store,d.quick_protocol,{kind:d.subscription_url?'subscription':'paste'});
    }
    if(d.operation=='save') {
        if(type(d.node)!='object')reject('node','请填写节点');
        let old=filter(store.nodes,n=>n.id==d.node.id)[0],item=nodes.update_node(d.node,old);
        if(old)store.nodes=map(store.nodes,n=>n.id==item.id?item:n);else push(store.nodes,item);
        if(item.protocol=='chain'&&item.udp){
            if(d.udp_test_id){item.udp_verification=udp_proof_api().check(d.udp_test_id,args.owner,bindings,nodes.chain_udp_identity(item,store));push(udp_receipts,{id:item.id,test_id:d.udp_test_id});}
            else if(caps.get().features?.chain_udp?.status!='trial'&&(!old||!old.udp||!nodes.chain_udp_stamp_valid(item,store)))reject_import('verification_pending','udp_test_id','请先按当前链参数测试 UDP，再明确启用');
        }
    } else if(d.operation=='delete') {
        if(!nodes.valid_node_id(d.id))reject('id','节点编号无效');
        let refs=filter(data.rules,r=>r.action=='node' && r.node==d.id);
        if(d.id==store.default_node)reject('id','默认节点不能删除');
        if(length(nodes.chain_references(store,d.id)))reject_import('role_restricted','id','节点仍被链引用，请先修改或删除相关链');
        let group_refs=filter(GROUPS,g=>data.group_nodes[g]==d.id);
        if(length(group_refs))reject('id','节点仍被规则组引用：'+join('、',map(group_refs,g=>LABELS[g]+'组')));
        let fallback_refs=filter(GROUPS,g=>data.fallbacks[g].action=='node' && data.fallbacks[g].node==d.id);
        if(length(fallback_refs))reject('id','节点仍被兜底出口引用：'+join('、',map(fallback_refs,g=>LABELS[g]+'组')));
        if(length(refs))reject('id','节点仍被规则或专用入口引用：'+join('、',map(refs,r=>LABELS[r.group]+' / '+(r.type=='dedicated'?'专用入口 ':'')+r.value+(r.enabled=='0'?'（停用）':''))));
        if(!length(filter(store.nodes,n=>n.id==d.id)))reject('id','节点不存在');
        store.nodes=filter(store.nodes,n=>n.id!=d.id);
    } else if(d.operation=='default') {
        if(!length(filter(store.nodes,n=>n.id==d.id)))reject('id','节点不存在');
        let tested=last_test(d.id);
        if(!tested || time()-tested.tested_at>120)reject('test','请先对目标节点测试一次');
        if(!tested.ok && d.allow_failed!=true)reject('test','该节点也不通；需要再次确认仍切换');
        nodes.assert_default(filter(store.nodes,n=>n.id==d.id)[0]);
        store.default_node=d.id;
    } else if(d.operation=='import') {
        safe_keys(d,['revision','nodes_revision','operation','preview_id','cache_version','selected_item_ids'],'import');
        import_selection=preview_api().select(d.preview_id,d.cache_version,d.selected_item_ids,args.owner,bindings);let incoming=import_selection.entries,ids={};for(let n in store.nodes)ids[n.id]=true;
        if(length(store.nodes)+length(filter(incoming,x=>!x.update_id))>metric_capacity.MAX_NODES)reject_import('limit_exceeded','selected_item_ids','导入后节点数将超过面板试用上限 21');
        let count=1;for(let entry in incoming){let n=entry.node;if(entry.update_id){if(!ids[entry.update_id])reject_import('revision_changed','updates','更新目标已不存在');n.id=entry.update_id;store.nodes=map(store.nodes,x=>x.id==n.id?n:x);}else{while(ids['node_'+count])count++;n.id='node_'+count;ids[n.id]=true;push(store.nodes,n);}push(imported,{id:n.id,name:nodes.display_name(n.name),protocol:n.protocol,server:nodes.mask(n.server),port:n.port,action:entry.update_id?'更新':'新增'});}
    } else reject('operation','不支持的节点操作');
    udp_invalidated=nodes.invalidate_chain_udp(prev,store);
    store.version=nodes.version_for(store);nodes.validate_store(store);nodes.validate_chains(store,true);require_store_capacity(store);
    if(d.operation=='save'&&!nodes.available(filter(store.nodes,n=>n.id==d.node.id)[0],store))reject_import('verification_pending','protocol','此组合尚未完成必要验证，不能保存');
    if(length(sprintf('%J\n',store))>524288)reject_import('limit_exceeded','nodes','节点库超过 512 KiB');
    ensure_root();gc();ensure_no_active();
    let id=uuid(),dir=ROOT+'/'+id;if(!fs.mkdir(dir,448))reject('storage','无法建立节点草稿');
    write(dir+'/state.json',{state:'invalid',created_at:time(),message:'节点草稿尚未通过校验'});
    write(dir+'/nodes.json',store);fs.writefile(dir+'/lanekeep',fs.readfile('/etc/config/lanekeep'));fs.chmod(dir+'/lanekeep',384);
    fs.writefile(dir+'/dhcp',fs.readfile('/etc/config/dhcp'));fs.chmod(dir+'/dhcp',384);
    let out=run(ENGINE+'/lanekeep-gen --config-dir '+q(dir)+' --nodes-file '+q(dir+'/nodes.json')+' --output-dir '+q(dir+'/generated')+' --previous-dir /etc/config >'+q(dir+'/generator-output')+' 2>&1');
    if(out==null || !regular(dir+'/generated/validated'))reject('node','节点未通过生成器校验，未写入生产');
    let kind=equal(obj(dir+'/generated/config.json'),obj(PROXY+'/config.json'))?(equal(store,prev)?'unchanged':'metadata'):'rules';
    let summary=public_summary(obj(dir+'/generated/summary.json'));summary.node_change=d.operation;summary.store_format_before=prev.version;summary.store_format_after=store.version;summary.requires_paired_rollback=store.version>1;summary.default_before=nodes.display_name((filter(prev.nodes,n=>n.id==prev.default_node)[0]?.name || ''));summary.default_after=nodes.display_name((filter(store.nodes,n=>n.id==store.default_node)[0]?.name || ''));
    summary.node_changes=[];for(let n in store.nodes){let old=filter(prev.nodes,x=>x.id==n.id)[0];if(!old || !equal(old,n))push(summary.node_changes,{id:n.id,name:nodes.display_name(n.name),action:old?'修改':'新增',protocol:n.protocol,server:n.server,port:n.port});}for(let n in prev.nodes)if(!length(filter(store.nodes,x=>x.id==n.id)))push(summary.node_changes,{id:n.id,name:nodes.display_name(n.name),action:'删除',protocol:n.protocol,server:n.server,port:n.port});
    summary.affected_chains=nodes.chain_impact(prev,store);summary.udp_invalidated=udp_invalidated;
    if(prev.default_node!=store.default_node)summary.default_node_change={before_name:summary.default_before,after_name:summary.default_after};
    let impact={restart_required:enabled()&&kind=='rules',message:!enabled()?'LaneKeep 尚未启用；本次仅保存设置，不接管网络。':kind=='rules'?'此次节点改动将重启核心，预计约10秒短暂中断（非实测保证）；最多等待60秒门控OPEN，失败自动退回，可能再重启一次。':'未使用节点或显示信息变更，不重启核心。',old_exit:last_test(prev.default_node)?.ip || '未知',new_exit:last_test(store.default_node)?.ip || '未知'};
    if(nodes_revision()!=revision || fingerprint('/etc/config/lanekeep')!=before || fingerprint('/etc/config/dhcp')!=dhcp)reject('revision','校验期间配置改变，请刷新');
    let meta={id:id,kind:kind,scope:'nodes',base_uci:before,base_dhcp:dhcp,base_nodes:revision,summary:summary,impact:impact,origin:'node:'+d.operation,created_at:time()};
    if(caps.revision()!=bindings.caps_revision)reject_import('revision_changed','capabilities','校验期间能力表改变，请重新校验');
    meta.node_caps_revision=bindings.caps_revision;
    if(length(udp_receipts)){meta.udp_receipts=udp_receipts;meta.udp_owner=args.owner;}
    if(d.operation=='import'){meta.import_owner=args.owner;meta.import_caps_revision=bindings.caps_revision;meta.import_source_binding=import_selection.source_binding;}
    write(dir+'/meta.json',meta);write(dir+'/state.json',{state:'validated',created_at:time(),message:'节点校验通过，尚未应用'});
    return {ok:true,draft_id:id,change_kind:kind,summary:summary,impact:impact,imported:imported,errors:[]};
}
function single_node_test(args) {
    safe_keys(args,['id'],'node_test');if(!nodes.valid_node_id(args.id))reject('id','节点编号无效');
    let revision=nodes_revision(),n=filter(current_nodes().nodes,n=>n.id==args.id)[0];if(!n)reject('id','节点不存在');
    nodes.assert_reference(n);
    ensure_root();let prior=last_test(args.id);if(prior && time()-prior.tested_at<10)reject('test','两次测试至少间隔10秒');
    let id=uuid(),dir=ROOT+'/'+id;if(!fs.mkdir(dir,448))reject('storage','无法建立测试目录');
    let ob=nodes.render(n);ob.tag='test';ob.streamSettings.sockopt={mark:30242};
    // bind-local random port, no LAN listener; all target traffic has DNS-probe mark.
    let port=20000+(int(substr(replace(id,/-/g,''),0,6),16)%30000);
    write(dir+'/test-config.json',{log:{loglevel:'none'},inbounds:[{tag:'test-in',listen:'127.0.0.1',port:port,protocol:'socks',settings:{auth:'noauth',udp:false}}],outbounds:[ob]});
    let raw=run(CODE+'/node-test '+q(dir)+' '+port),value=raw?json(raw):{ok:false,status:'failed',message:'节点测试未完成；未尝试直连'};
    if(!value.ok){delete value.elapsed_ms;delete value.connect_ms;delete value.latency_basis;}value.measurement_version=3;value.tested_at=time();value.time_utc=trim(run('date -u +%Y-%m-%dT%H:%M:%SZ') || '');if(!match(value.time_utc,/^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$/))reject('test','无法记录测试时间，结果未保存');value.revision=revision;
    if(nodes_revision()!=revision)reject('revision','测试期间节点已改变，结果作废');
    let cache=regular(ROOT+'/node-tests.json')?obj(ROOT+'/node-tests.json'):{};cache[args.id]={node:n,result:value};write(ROOT+'/node-tests.json',cache);
    if(regular(dir+'/test-config.json'))fs.unlink(dir+'/test-config.json');
    for(let name in ['test-private.log','test-response','test-start','test-result','test-result.next'])if(regular(dir+'/'+name))fs.unlink(dir+'/'+name);fs.rmdir(dir);
    return value;
}

// A chain probe uses the same pure rear renderer as the production generator.
// Its temporary health mark is not evidence that production data-gate rules work.
function probe_chain_step(outbounds,selected) {
    let id=uuid(),dir=ROOT+'/'+id;if(!fs.mkdir(dir,448))reject('storage','无法建立私有测试目录');
    let value=null;
    try {
        if(fs.writefile(dir+'/.owner','lanekeep-chain-test-v1\n')==null||!fs.chmod(dir+'/.owner',384))die('owner');
        let port=20000+(int(substr(replace(id,/-/g,''),0,6),16)%30000);
        let routing={domainStrategy:'AsIs',rules:[
            {type:'field',inboundTag:['test-in'],network:'udp',outboundTag:'block'},
            {type:'field',inboundTag:['test-in'],ip:['0.0.0.0/8','10.0.0.0/8','100.64.0.0/10','127.0.0.0/8','169.254.0.0/16','172.16.0.0/12','192.168.0.0/16','198.18.0.0/15','224.0.0.0/4','240.0.0.0/4','::/128','::1/128','fc00::/7','fe80::/10','ff00::/8'],outboundTag:'block'},
            {type:'field',inboundTag:['test-in'],network:'tcp',outboundTag:selected}
        ]};
        // Blackhole is the default. No direct outbound or fallback to the front.
        let all=[{tag:'block',protocol:'blackhole',settings:{}}];for(let out in outbounds)push(all,out);
        write(dir+'/test-config.json',{log:{access:'none',error:'none',loglevel:'none',dnsLog:false},inbounds:[{tag:'test-in',listen:'127.0.0.1',port,protocol:'socks',settings:{auth:'noauth',udp:false}}],outbounds:all,routing});
        let raw=run(CODE+'/chain-test '+q(dir)+' '+port);
        if(raw&&length(raw)<=2048){let response=json(raw);if(response.ok==true&&match(response.ip||'',/^[0-9]{1,3}(\.[0-9]{1,3}){3}$/)&&length(filter(split(response.ip,'.'),p=>int(p)>255))==0&&match(response.country||'',/^[A-Z]{2}$/)&&type(response.elapsed_ms)=='int'&&response.elapsed_ms>=0&&response.elapsed_ms<=10000){
            value={ok:true,status:'ok',ip:response.ip,country:response.country,elapsed_ms:response.elapsed_ms,measurement_version:3};
            if(has(['warm','first_request'],response.latency_basis))value.latency_basis=response.latency_basis;
            if(type(response.connect_ms)=='int'&&response.connect_ms>=0&&response.connect_ms<=10000)value.connect_ms=response.connect_ms;
        }}
    } catch(e) { /* No exception content, addresses or credentials are returned. */ }
    // Cleanup only files owned by this fresh task. The shell also cleans after signals.
    if(regular(dir+'/.owner')&&fs.readfile(dir+'/.owner')=='lanekeep-chain-test-v1\n'){
        for(let name in ['test-config.json','test-config.json.next','test-start','test-result','test-result.next'])if(regular(dir+'/'+name))fs.unlink(dir+'/'+name);
        fs.unlink(dir+'/.owner');fs.rmdir(dir);
    } else if(fs.lstat(dir+'/.owner')==null)fs.rmdir(dir);
    return value||{ok:false,status:'failed',message:'本步连接未完成；未尝试直连或其他节点'};
}
function node_test_run(args) {
    safe_keys(args,['id','front','udp','expected_ip','chain_id','owner'],'node_test');if(args.udp==true)return node_udp_test(args);if(args.udp!=null&&args.udp!=false)reject('udp','UDP 测试模式无效');if(args.expected_ip||args.chain_id)reject('test','TCP 测试不接受 UDP 参数');if(!nodes.valid_node_id(args.id))reject('id','节点编号无效');
    let revision=nodes_revision(),cap_revision=caps.revision(),store=current_nodes(),n=filter(store.nodes,x=>x.id==args.id)[0];if(!n)reject('id','节点不存在');
    if(nodes.role(n)=='single'&&!args.front)return single_node_test({id:args.id});
    let composed=n;
    if(n.protocol=='chain'){if(args.front)reject('front','链测试使用已保存前置，不能临时替换');}
    else {
        if(!nodes.valid_node_id(args.front))reject('front','测试后置必须显式选择已验证前置');
        let id='t_'+substr(replace(uuid(),/-/g,''),0,24);if(length(filter(store.nodes,x=>x.id==id)))reject('test','临时编号冲突，请手动重试');
        composed={id,name:'临时两跳',protocol:'chain',front:args.front,rear:n.id,udp:false};
    }
    nodes.assert_reference(composed,store);
    ensure_root();ensure_no_active();let prior=last_test(args.id);if(prior&&time()-prior.tested_at<10)reject('test','两次测试至少间隔10秒');
    let front=filter(store.nodes,x=>x.id==composed.front)[0],ob=nodes.render(front);ob.tag='test-front';ob.streamSettings.sockopt={mark:30242};
    // Front endpoint resolution follows the existing temporary-node test channel.
    // Production ForceIP/server resolution and data marking require isolated evidence.
    let first=probe_chain_step([ob],'test-front'),second={ok:false,status:'skipped',message:'前置未成功，未发起整链请求'};
    if(first.ok&&nodes_revision()==revision&&caps.revision()==cap_revision)second=probe_chain_step([ob,nodes.chain_outbound(composed,store,'test-front')],'chain-'+composed.id);
    if(nodes_revision()!=revision||caps.revision()!=cap_revision)reject('revision','测试期间节点或能力表改变，结果作废');
    let value={ok:first.ok&&second.ok,test_kind:'chain_tcp',status:first.ok&&second.ok?'ok':'failed',front_id:composed.front,rear_id:composed.rear,front:first,chain:second,measurement_version:3,tested_at:time(),revision,caps_revision:cap_revision,message:'节点临时连接测试；不代表生产两跳、门控或设备 DNS/WebRTC 验收'};
    if(value.ok){value.ip=second.ip;value.country=second.country;value.elapsed_ms=second.elapsed_ms;if(second.connect_ms!=null)value.connect_ms=second.connect_ms;if(second.latency_basis)value.latency_basis=second.latency_basis;}
    value.time_utc=trim(run('date -u +%Y-%m-%dT%H:%M:%SZ')||'');if(!match(value.time_utc,/^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$/))reject('test','无法记录测试时间，结果未保存');
    let cache=regular(ROOT+'/node-tests.json')?obj(ROOT+'/node-tests.json'):{};cache[args.id]={node:n,result:value};write(ROOT+'/node-tests.json',cache);return value;
}

udp_proof_api = function(){return udp_proofs.bind({root:ROOT,ensure_root,write,valid_id,uuid,reject:reject_import,canonical:nodes.canonical});};
check_udp_receipts = function(meta,store,owner){
 if(!length(meta.udp_receipts||[]))return;
 if(owner!=meta.udp_owner)reject_import('preview_expired','udp_test_id','UDP 测试与当前登录会话不一致');
 for(let item in meta.udp_receipts){let n=filter(store.nodes,x=>x.id==item.id)[0];if(!n||!n.udp)reject_import('revision_changed','udp_test_id','UDP 候选已变化');let proof=udp_proof_api().check(item.test_id,owner,current_import_bindings(),nodes.chain_udp_identity(n,store));if(!equal(proof,n.udp_verification))reject_import('revision_changed','udp_test_id','UDP 测试绑定已变化');}
};
function probe_chain_udp(outbounds,selected,targets){
 let id=uuid(),dir=ROOT+'/'+id,value=null;if(!fs.mkdir(dir,448))reject('storage','无法建立 UDP 临时测试目录');
 try{
  if(fs.writefile(dir+'/.owner','lanekeep-chain-udp-test-v1\n')==null||!fs.chmod(dir+'/.owner',384))die('owner');
  let port=20000+(int(substr(replace(id,/-/g,''),0,6),16)%30000),routes=[];
  // Only two explicitly verified UDP targets, neither is UDP 443. No direct outbound.
  for(let pair in [{kind:'dns',port:53},{kind:'stun',port:targets.stun?.port}]){
   let t=targets[pair.kind];if(type(t)!='object'||type(t.server)!='string'||length(t.server)>253||type(t.port)!='int'||t.port!=pair.port||t.port<1||t.port>65535||t.port==443||t.port==853)die('target');
   let rule={type:'field',inboundTag:['test-in'],network:'udp',port:''+t.port,outboundTag:selected};
   if(public_ip(t.server))rule.ip=[t.server+'/32'];else{if(!match(t.server,/^[A-Za-z0-9][A-Za-z0-9.-]*\.[A-Za-z]+$/)||match(t.server,/\.(local|localhost|lan|home|internal)$/))die('target');rule.domain=['full:'+t.server];}push(routes,rule);
  }
  let all=[{tag:'block',protocol:'blackhole',settings:{}}];for(let ob in outbounds)push(all,ob);
  write(dir+'/test-config.json',{log:{access:'none',error:'none',loglevel:'none',dnsLog:false},inbounds:[{tag:'test-in',listen:'127.0.0.1',port,protocol:'socks',settings:{auth:'noauth',udp:true,ip:'127.0.0.1'}}],outbounds:all,routing:{domainStrategy:'AsIs',rules:routes}});
  write(dir+'/test-targets.json',{dns:targets.dns,stun:targets.stun});let raw=run(CODE+'/chain-udp-test '+q(dir)+' '+port);
  if(raw&&length(raw)<=2048){let r=json(raw);if(r.ok==true&&r.udp_dns==true&&r.stun==true&&public_ip(r.ip)&&type(r.elapsed_ms)=='int'&&r.elapsed_ms>=0&&r.elapsed_ms<=9000)value={ok:true,status:'ok',ip:r.ip,udp_dns:true,stun:true,elapsed_ms:r.elapsed_ms};}
 }catch(e){}
 if(regular(dir+'/.owner')&&fs.readfile(dir+'/.owner')=='lanekeep-chain-udp-test-v1\n'){
  for(let name in ['test-config.json','test-config.json.next','test-targets.json','test-targets.json.next','test-start','test-result','test-result.next'])if(regular(dir+'/'+name))fs.unlink(dir+'/'+name);
  fs.unlink(dir+'/.owner');fs.rmdir(dir);
 }else if(fs.lstat(dir+'/.owner')==null)fs.rmdir(dir);
 return value||{ok:false,status:'failed',message:'UDP 请求未完成；未尝试直连、其他前置或节点'};
}
node_udp_test = function(args){
 if(!valid_id(args.owner)||!public_ip(args.expected_ip))reject_import('param_invalid','expected_ip','请在当前会话填写明确的后置公网 IPv4 出口约束');
 let store=current_nodes(),n=filter(store.nodes,x=>x.id==args.id)[0],bindings=current_import_bindings();if(!n)reject('id','节点不存在');
 let composed;
 if(n.protocol=='chain'){if(args.front||args.chain_id)reject('front','已有链使用保存的依赖');composed=clone(n);}
 else{if(n.protocol!='socks5'||!nodes.valid_node_id(args.front)||!nodes.valid_node_id(args.chain_id))reject('front','UDP 测试须选择前置、SOCKS5 后置及链编号');let existing=filter(store.nodes,x=>x.id==args.chain_id)[0];if(existing&&existing.protocol!='chain')reject('chain_id','链编号与普通节点冲突');composed={id:args.chain_id,name:'临时 UDP 链',protocol:'chain',front:args.front,rear:n.id,udp:false};}
 composed.udp=false;delete composed.udp_verification;composed.udp_expected_ip=args.expected_ip;
 let front=filter(store.nodes,x=>x.id==composed.front)[0],rear=filter(store.nodes,x=>x.id==composed.rear)[0];
 if(!nodes.chain_udp_ready(front,rear))reject_import('verification_pending','udp','链式 UDP 配对和固定版本隔离验证尚未发布');
 let targets=caps.get().features?.chain_udp?.test_targets;if(!has(['trial','verified'],targets?.status))reject_import('verification_pending','udp','UDP 测试目标未配置，不发起请求');
 nodes.assert_reference(composed,store);ensure_root();ensure_no_active();let prior=last_test(args.id);if(prior&&time()-prior.tested_at<10)reject('test','两次测试至少间隔10秒');
 let ob=nodes.render(front);ob.tag='test-front';ob.streamSettings.sockopt={mark:30242};let chained=nodes.chain_outbound(composed,store,'test-front'),first=probe_chain_step([ob],'test-front'),second={ok:false,status:'skipped'},third={ok:false,status:'skipped'};
 function unchanged(){return equal(bindings,current_import_bindings());}
 if(first.ok&&unchanged())second=probe_chain_step([ob,chained],chained.tag);
 if(second.ok&&unchanged())third=probe_chain_udp([ob,chained],chained.tag,targets);
 if(!unchanged())reject_import('revision_changed','udp','测试期间配置或能力表变化，结果作废');
 let matched=first.ok&&second.ok&&third.ok&&second.ip==third.ip&&third.ip==args.expected_ip;
 function step(v){return {ok:v.ok,status:v.status,elapsed_ms:v.ok?v.elapsed_ms:null};}
 let value={ok:matched,test_kind:'chain_udp',status:matched?'ok':third.ok?'exit_mismatch':'failed',front_id:composed.front,rear_id:composed.rear,front:step(first),chain:step(second),udp:step(third),udp_dns:third.udp_dns==true,stun:third.stun==true,exit_match:matched,tested_at:time(),revision:bindings.nodes_revision,caps_revision:bindings.caps_revision,measurement_version:3,message:matched?'临时 TCP/UDP 出口符合约束；生产规则命中和设备防泄露仍须单独验收':'未完成全部测试或 TCP/UDP 出口不符合约束；未开放 UDP，也不据此认定泄露'};
 if(matched){let proof=udp_proof_api().issue(args.owner,bindings,nodes.chain_udp_identity(composed,store));value.udp_test_id=proof.test_id;value.expires_in=1200;value.ip=nodes.mask(third.ip);value.country=second.country;value.elapsed_ms=third.elapsed_ms;}
 value.time_utc=trim(run('date -u +%Y-%m-%dT%H:%M:%SZ')||'');if(!match(value.time_utc,/^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$/))reject('test','无法记录测试时间');
 let cache=regular(ROOT+'/node-tests.json')?obj(ROOT+'/node-tests.json'):{};cache[args.id]={node:n,result:value};write(ROOT+'/node-tests.json',cache);return value;
};


function has_trial(store){return length(filter(store.nodes,n=>n.protocol=='chain'||nodes.trial(n,store)))>0;}
function node_test(args){
 safe_keys(args,['id','front','udp','expected_ip','chain_id','owner','trial_ack'],'node_test');
 let store=current_nodes(),n=filter(store.nodes,x=>x.id==args.id)[0];if(!n)reject('id','节点不存在');
 let needs=nodes.trial(n,store)||n.protocol=='chain'||args.front||args.udp;
 if(needs&&(!valid_id(args.owner)||args.trial_ack!=true))reject_import('trial_confirmation_required','trial_ack','请先勾选未验证试用，再发起测试');
 let binding=current_import_bindings(),request=clone(args);delete request.trial_ack;let value=node_test_run(request);
 if(value.ok&&needs&&valid_id(args.owner)&&equal(binding,current_import_bindings())){
  let tested=[n],records=[],composed=null;
  if(value.test_kind=='chain_tcp'||value.test_kind=='chain_udp'){
   let front=filter(store.nodes,x=>x.id==value.front_id)[0],rear=filter(store.nodes,x=>x.id==value.rear_id)[0];tested=[front,rear];
   composed=n.protocol=='chain'?clone(n):{id:args.chain_id||'trial_pair',name:'试用配对',protocol:'chain',front:front.id,rear:rear.id,udp:false};
   composed.udp=value.test_kind=='chain_udp';if(composed.udp)composed.udp_expected_ip=args.expected_ip;else delete composed.udp_expected_ip;
   push(records,{kind:value.test_kind,id:composed.udp?'chain-udp':'chain-tcp',signature:nodes.verification_key(composed,store)});
  }
  for(let item in tested){if(!item||item.protocol=='chain')continue;let signature=nodes.verification_key(item,store);push(records,{kind:'combo',id:nodes.combo_id(item),signature});if(item.import_hints)push(records,{kind:'hint',id:item.fingerprint,signature});}
  if(length(records)>5)reject('test','测试证据超过边界');ensure_root();value.verification_receipt=caps.issue(args.owner,binding,records);value.verification_expires_in=1200;value.verification_notice='连接测试成功；需由你明确确认才记录 verified，不代表设备防泄露或所有服务端通过';
 }
 return value;
}
function trial_confirm(args){
 safe_keys(args,['receipt_id','confirm_verified','owner'],'trial_confirm');ensure_no_active();
 try{return caps.confirm(args.receipt_id,args.owner,current_import_bindings(),args.confirm_verified);}catch(e){reject_import('verification_confirmation_failed','receipt_id','确认未提交：需当前登录会话、20分钟内成功测试及未变化的配置，请重新测试后确认');}
}

let method=ARGV[0];
try {
    let request=ARGV[1],result,request_owner=null;
    if(method=='execute') result=execute(request);
    else {
        if(!has(['status','validate','apply','versions','rollback','exit_check','nodes','node_validate','node_test','trial_confirm','capabilities','sub_list','sub_save','sub_refresh','sub_diff'],method)) reject('method','不支持的方法');
        if(!regular(request) || fs.stat(request).size>524288) reject('request','请求不可读取或过大');
        let args=obj(request);request_owner=args.owner;
        if(has(['sub_list','sub_save','sub_refresh','sub_diff'],method))result=subscription_call(method,args);
        else if(method=='capabilities')result=capability_view(args);
        else if(method=='nodes')result=node_list(args);
        else if(method=='node_validate')result=node_validate(args);
        else if(method=='node_test')result=node_test(args);
        else if(method=='trial_confirm')result=trial_confirm(args);
        else if(method=='status') result=status(args);
        else if(method=='validate') {
            safe_keys(args,['draft','owner'],'validate');
            if(type(args.draft)!='string' || length(args.draft)>500000) reject('draft','草稿格式无效或过大');
            let draft; try { draft=json(args.draft); } catch(e) { reject('draft','草稿JSON格式无效'); }
            result=prepare(draft,'edit');
        } else if(method=='apply') result=apply(args);
        else if(method=='versions') result=versions(args);
        else if(method=='rollback') result=rollback(args);
        else {
            safe_keys(args,[],'exit_check');
            result=node_test({id:current_nodes().default_node});
        }
    }
    if(result?.ok&&result.draft_id){
     let dir=ROOT+'/'+result.draft_id,meta=obj(dir+'/meta.json'),store=regular(dir+'/nodes.json')?nodes.read_store(dir+'/nodes.json'):current_nodes();
     let required=has_trial(store)||has_trial(current_nodes())||!!meta.import_owner||!!meta.import_source_binding;result.trial_required=required;
     if(required){if(!valid_id(request_owner))reject('trial_ack','登录会话不可用');meta.trial_required=true;meta.trial_owner=request_owner;meta.trial_revision=caps.revision();write(dir+'/meta.json',meta);}
    }
    if(has(['nodes','node_validate','capabilities','sub_list','sub_save','sub_refresh','sub_diff'],method)&&!sizes.fits(result))reject_import('limit_exceeded','response','响应超过安全容量，请减少选择');
    printf('%J\n',result);
} catch(e) {
    let model=nodes.take_error();
    if(!failure&&model)failure={ok:false,code:model.code,message:model.message,errors:[{field:model.param||'node',code:model.code,message:model.message}]};
    if(!failure&&has(['node_validate','capabilities','sub_list','sub_save','sub_refresh','sub_diff'],method)){let incident=trim(fs.readfile('/proc/sys/kernel/random/uuid')||'');failure={ok:false,code:'internal',error_id:valid_id(incident)?incident:null,message:'内部处理未完成，请重新预览；未返回敏感诊断',errors:[{field:'request',code:'internal',message:'内部处理未完成'}]};}
    let response=failure || {ok:false,message:'面板请求失败，未返回内部诊断；请先核对状态',errors:[{field:'request',message:'请求或当前状态不受支持'}]};
    if(method=='apply') {if(may_have_started) response.uncertain=true;else response.not_started=true;}
    printf('%J\n',response);
}
