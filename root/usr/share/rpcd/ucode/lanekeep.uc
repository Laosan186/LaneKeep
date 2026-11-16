// First creation: private JSON bridge; rpcd supplies authenticated request.args.
import * as fs from 'fs';
import * as uci from 'uci';
// Raw rpcd session IDs stay in this process only, never in files, drafts or logs.
// uhttpd rejects caller-provided ubus_rpc_session and injects its checked session.
let owners={};
function session_owner(args){
    let sid=args?.ubus_rpc_session,now=time();
    if(type(sid)!='string'||!match(sid,/^[a-f0-9]{32}$/)||sid=='00000000000000000000000000000000')return null;
    for(let key in keys(owners))if(now<owners[key].at||now-owners[key].at>=1200)delete owners[key];
    if(!owners[sid]){
        if(length(keys(owners))>=64)return null;
        let id=trim(fs.readfile('/proc/sys/kernel/random/uuid')||'');
        if(!match(id,/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/))return null;
        owners[sid]={id:id,at:now};
    }
    owners[sid].at=now;return owners[sid].id;
}
function invoke(method, args) {
    let p = fs.popen('umask 077; mktemp -d /tmp/lanekeep-panel-rpc.XXXXXX', 'r');
    if (!p) return { ok: false, message: '无法创建私有请求目录' };
    let dir = trim(p.read('all') || ''); p.close();
    if (!match(dir, /^\/tmp\/lanekeep-panel-rpc\.[A-Za-z0-9]{6}$/)) return { ok: false, message: '私有目录异常' };
    let response;
    try {
        let selected = {};
        let fields = {status:['job_id'],validate:['draft'],apply:['draft_id','confirm','trial_ack'],versions:[],rollback:['version_id','scope'],exit_check:[],nodes:['offset','revision'],sub_list:[],sub_save:['draft'],sub_refresh:['draft'],sub_diff:['draft'],capabilities:[],node_validate:['draft'],node_test:['id','front','udp','expected_ip','chain_id','trial_ack'],trial_confirm:['receipt_id','confirm_verified']};
        // rpcd authentication context is never serialized into a draft or log.
        for (let name in fields[method]) if (args?.[name] != null) selected[name] = args[name];
        if(method=='validate'||method=='rollback'||method=='trial_confirm'||method=='node_validate'||method=='node_test'||method=='apply'||index(['sub_save','sub_refresh','sub_diff'],method)>=0)selected.owner=session_owner(args);
        let body = sprintf('%J', selected);
        if (length(body) > 524288) die('large');
        if (fs.writefile(dir + '/request.json', body) == null || !fs.chmod(dir + '/request.json', 384)) die('write');
        let stream = fs.popen('/usr/libexec/lanekeep-panel/dispatch ' + method + ' ' + dir + ' 2>/dev/null', 'r');
        if (!stream) die('spawn');
        let text = stream.read('all'); stream.close();
        if (length(text || '') > 1048576) die('large');
        response = json(text);
        if (type(response) != 'object') die('response');
    } catch (e) {
        response = { ok: false, message: '面板请求未完成；提交超时请先查询任务状态，勿重复应用' };
        if (method == 'apply') {
            response.uncertain = true;
            if (type(args?.draft_id) == 'string' && match(args.draft_id, /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/)) response.job_id = args.draft_id;
        }
    }
    fs.unlink(dir + '/request.json'); fs.rmdir(dir);
    return response;
}
function lifecycle(request) {
 let a=request.args;
 if(!session_owner(a)||index(['enable','disable'],a.action)<0||a.confirm!=(a.action=='enable'?'ENABLE':'DISABLE'))return {ok:false,message:'explicit_confirmation_required'};
 let p=fs.popen('/usr/libexec/lanekeep-panel/lifecycle '+a.action+' 2>/dev/null','r');
 if(!p)return {ok:false,message:'lifecycle_start_failed'};
 let output=p.read('all'),rc=p.close();
 if(rc!=0)return {ok:false,message:'启用未完成：请确认已选择默认节点、LAN IPv6 已关闭且保留的端口和策略路由没有冲突。 / Activation failed: check default node, disabled LAN IPv6 and reserved ports/routes.'};
 return {ok:true,enabled:uci.cursor().get('lanekeep_runtime','main','enabled')=='1'};
}
return { lanekeep: {
    lifecycle: {args:{action:'',confirm:''},call:lifecycle},
    status: { args: { job_id: '' }, call: (request) => invoke('status', request.args) },
    validate: { args: { draft: '' }, call: (request) => invoke('validate', request.args) },
    apply: { args: { draft_id: '', confirm: '', trial_ack:false }, call: (request) => invoke('apply', request.args) },
    versions: { args: {}, call: (request) => invoke('versions', request.args) },
    rollback: { args: { version_id: '', scope: '' }, call: (request) => invoke('rollback', request.args) },
    capabilities: { args: {}, call: (request) => invoke('capabilities', request.args) },
    nodes: { args: {offset:0,revision:''}, call: (request) => invoke('nodes', request.args) },
    sub_list: {args:{},call:r=>invoke('sub_list',r.args)},
    sub_save: {args:{draft:''},call:r=>invoke('sub_save',r.args)},
    sub_refresh: {args:{draft:''},call:r=>invoke('sub_refresh',r.args)},
    sub_diff: {args:{draft:''},call:r=>invoke('sub_diff',r.args)},
    node_validate: { args: {draft:''}, call: (request) => invoke('node_validate', request.args) },
    node_test: { args: {id:'',front:'',udp:false,expected_ip:'',chain_id:'',trial_ack:false}, call: (request) => invoke('node_test', request.args) },
    trial_confirm: {args:{receipt_id:'',confirm_verified:false},call:r=>invoke('trial_confirm',r.args)},
    exit_check: { args: {}, call: (request) => invoke('exit_check', request.args) }
} };
