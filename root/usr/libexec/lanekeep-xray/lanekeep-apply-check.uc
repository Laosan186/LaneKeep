import * as lan from '../lanekeep-panel/network.uc';
// Step 3 candidate: first creation, no previous version. No network mutations.
// The prune operation only unlinks verified files in this feature's snapshots.
import * as fs from 'fs';
import * as dedicated from '../lanekeep-panel/dedicated.uc';

function load(path) { return json(fs.readfile(path)); }
function canonical(value) {
    if (type(value) == 'object') {
        let out = {};
        for (let key in sort(keys(value))) out[key] = canonical(value[key]);
        return out;
    }
    if (type(value) == 'array') return map(value, canonical);
    return value;
}
function equal(a, b) { return sprintf('%J', canonical(a)) == sprintf('%J', canonical(b)); }
function health_state(dir) {
    let service = load(dir + '/service.json');
    let instances = service?.['lanekeep-xray']?.instances;
    if (instances?.core?.running != true || instances?.dns_gate?.running != true) return null;
    let core = instances.core.pid, gate = instances.dns_gate.pid;
    if (type(core) != 'int' || core <= 0 || type(gate) != 'int' || gate <= 0) return null;
    let epoch = trim(fs.readfile(dir + '/epoch') || '');
    if (length(epoch) != 36 || !match(epoch, /^[0-9a-f-]+$/)) return null;
    let status = {};
    for (let line in split(fs.readfile(dir + '/gate-status') || '', '\n')) {
        let parts = split(line, '=');
        if (length(parts) == 2) status[parts[0]] = parts[1];
    }
    let now = int(split(fs.readfile(dir + '/uptime') || '', ' ')[0]);
    if (!match(status.uptime_seconds || '', /^[0-9]+$/)) return null;
    let written = int(status.uptime_seconds);
    if (status.state != 'OPEN' || now < written || now - written > 5) return null;
    let leased = false;
    for (let entry in load(dir + '/lease.json').nftables || []) {
        let set = entry.set;
        if (set?.family != 'inet' || set?.table != 'lanekeep_dns_gate' || set?.name != 'healthy_data') continue;
        for (let item in set.elem || []) {
            let elem = item.elem || item;
            if (elem.val == 30241 && type(elem.expires) == 'int' && elem.expires > 0) leased = true;
        }
    }
    if (!leased) return null;
    return { core: core, dns_gate: gate, epoch: epoch, written: written };
}
function health(dir, previous, minimum) {
    let current = health_state(dir);
    return current != null && current.epoch != previous && current.written >= minimum;
}
function stable_health(dir, expected) {
    let current = health_state(dir);
    if (current == null) return false;
    let identity = { core: current.core, dns_gate: current.dns_gate, epoch: current.epoch };
    if (expected == '-') { printf('%J\n', identity); return true; }
    return equal(identity, load(expected));
}
function stable_identity(dir, expected) {
    let instances = load(dir + '/service.json')?.['lanekeep-xray']?.instances;
    if (instances?.core?.running != true || instances?.dns_gate?.running != true) return false;
    let identity = {core:instances.core.pid,dns_gate:instances.dns_gate.pid,epoch:trim(fs.readfile(dir + '/epoch') || '')};
    if (type(identity.core) != 'int' || type(identity.dns_gate) != 'int' || !match(identity.epoch,/^[0-9a-f-]{36}$/)) return false;
    if (expected == '-') { printf('%J\n',identity); return true; }
    return equal(identity,load(expected));
}
let MEMBER_GROUPS = ['global', 'enhanced', 'ondemand', 'standard', 'direct'];
let UNASSIGNED_CHAINS = { standard: 'capture_phone', direct: 'capture_direct' };
function unassigned(data) { return data?.unassigned ?? 'standard'; }
function group_members(data) {
    let result = {};
    for (let group in MEMBER_GROUPS) {
        if (type(data?.groups?.[group]?.member) != 'array') return null;
        result[group] = sort(data.groups[group].member);
    }
    return result;
}
function kind(old, current, old_config, new_config) {
    let before = group_members(old), after = group_members(current);
    if (before == null || after == null || type(old.rules) != 'array' || type(current.rules) != 'array') return null;
    let members_changed = !equal(before, after);
    // When supplied by apply, classify the rendered runtime config. Notes and
    // disabled-rule edits must not restart the core. Legacy callers stay strict.
    let rules_changed = old_config != null && new_config != null ? !equal(old_config, new_config) : !equal(old.rules, current.rules);
    // The unassigned choice only changes the nft dispatch jump; it still needs the rules path.
    if (unassigned(old) != unassigned(current)) rules_changed = true;
    if (rules_changed && members_changed) return 'mixed';
    if (rules_changed) return 'rules';
    if (members_changed) return 'members';
    return equal(old, current) ? 'unchanged' : 'metadata';
}
// Kernel JSON semantic readback: no established shortcut or extra accept is allowed.
function dedicated_acl(data,nft) {
    let entries=dedicated.active(data.rules),chains={};
    for(let item in nft.nftables || []) {
        let r=item.rule;
        if(r?.table=='lanekeep_phone' && r.family=='inet') {
            if(chains[r.chain]==null)chains[r.chain]=[];
            push(chains[r.chain],r.expr);
        }
    }
    let allows=chains.dedicated_access || [];
    if(!length(entries))return length(allows)==0;
    function match(left,right){return {match:{op:'==',left,right}};}
    function meta(key){return {meta:{key}};}
    function payload(protocol,field){return {payload:{protocol,field}};}
    let expected=[];
    for(let r in entries)push(expected,[
        match(meta('iifname'),lan.context().device),match(payload('ip','saddr'),'@lanekeep_grp_'+r.group),
        match(payload('ip','daddr'),lan.context().address),match(payload('tcp','dport'),int(r.value)),
        {mangle:{key:meta('mark'),value:30224}},{accept:null}
    ]);
    push(expected,[{drop:null}]);
    // Some nft versions print an explicit TCP dependency for tcp dport.
    function normalize(expr){return filter(expr,e=>!equal(e,match(meta('l4proto'),'tcp')));}
    if(!equal(map(allows,normalize),expected))return false;
    let jump=[match(payload('ip','daddr'),lan.context().address),match(meta('l4proto'),{set:['tcp','udp']}),
        match(payload('th','dport'),{range:[10811,10860]}),{jump:{target:'dedicated_access'}}];
    for(let name in ['select_phone','prevent_input_fallback'])if(!equal(chains[name]?.[0],jump))return false;
    return true;
}
function live_members(data, nft) {
    let expected = group_members(data);
    if (expected == null) return false;
    let seen = {};
    for (let entry in nft.nftables || []) {
        let set = entry.set;
        if (set?.family != 'inet' || set?.table != 'lanekeep_phone') continue;
        for (let group in MEMBER_GROUPS) {
            if (set.name != 'lanekeep_grp_' + group) continue;
            if (seen[group] || set.type != 'ipv4_addr') return false;
            let members = [];
            for (let item in set.elem || []) {
                let address = type(item) == 'string' ? item : item?.elem?.val;
                if (type(address) != 'string' || !lan.member(address)) return false;
                push(members, address);
            }
            if (!equal(sort(members), expected[group])) return false;
            seen[group] = true;
        }
    }
    for (let group in MEMBER_GROUPS) if (seen[group] != true) return false;
    let fallback = UNASSIGNED_CHAINS[unassigned(data)];
    if (fallback == null) return false;
    // Rule metadata (for example handle) is intentionally ignored; every expr is exact.
    let dispatch = [];
    for (let entry in nft.nftables || []) {
        let rule = entry.rule;
        if (rule?.family == 'inet' && rule?.table == 'lanekeep_phone' && rule?.chain == 'dispatch_device')
            push(dispatch, rule.expr);
    }
    let expected_dispatch = [];
    for (let group in MEMBER_GROUPS) {
        push(expected_dispatch, [
            { match: { op: '==', left: { payload: { protocol: 'ip', field: 'saddr' } }, right: '@lanekeep_grp_' + group } },
            { jump: { target: group == 'standard' ? 'capture_phone' : 'capture_' + group } }
        ]);
    }
    push(expected_dispatch, [
        { match: { op: '==', left: { meta: { key: 'l4proto' } }, right: { set: ['tcp', 'udp'] } } },
        { jump: { target: fallback } }
    ]);
    return length(dispatch) == 6 && equal(dispatch, expected_dispatch) && dedicated_acl(data,nft);
}
function prune(root) {
    if (root != '/etc/lanekeep-proxy/versions' || fs.lstat(root)?.type != 'directory') return false;
    let snapshots = [];
    for (let name in fs.lsdir(root) || []) {
        if (!match(name, /^[0-9]{8}T[0-9]{6}Z-[0-9]+$/)) continue;
        let path = root + '/' + name;
        if (fs.lstat(path)?.type != 'directory') continue;
        if (fs.readfile(path + '/owner') != 'lanekeep-panel-v1\n') continue;
        let expected = ['config.json', 'manifest.sha256', 'owner', 'phone-pilot.nft', 'lanekeep'];
        if (fs.lstat(path + '/nodes.json')?.type == 'file') { push(expected,'nodes.json'); expected = sort(expected); }
        if (!equal(sort(fs.lsdir(path) || []), expected)) continue;
        let regular = true;
        for (let file in expected) if (fs.lstat(path + '/' + file)?.type != 'file') regular = false;
        if (!regular) continue;
        // Names are fixed by the regex, not shell input. Verify before deletion.
        if (system('cd ' + path + ' && sha256sum -c manifest.sha256 >/dev/null 2>&1') != 0) continue;
        push(snapshots, name);
    }
    snapshots = reverse(sort(snapshots));
    for (let i = 10; i < length(snapshots); i++) {
        let path = root + '/' + snapshots[i];
        let files = ['config.json', 'phone-pilot.nft', 'lanekeep', 'manifest.sha256', 'owner'];
        if (fs.lstat(path + '/nodes.json')?.type == 'file') push(files,'nodes.json');
        for (let file in files) {
            if (!fs.unlink(path + '/' + file)) return false;
        }
        if (!fs.rmdir(path)) return false;
    }
    return true;
}
try {
    let mode = ARGV[0];
    if (mode == 'dedicated-acl') exit(dedicated_acl(load(ARGV[1]),load(ARGV[2])) ? 0 : 1);
    if (mode == 'equal') exit(equal(load(ARGV[1]), load(ARGV[2])) ? 0 : 1);
    if (mode == 'health') exit(health(ARGV[1], ARGV[2], int(ARGV[3])) ? 0 : 1);
    if (mode == 'stable-identity') exit(stable_identity(ARGV[1], ARGV[2]) ? 0 : 1);
    if (mode == 'stable-health') exit(stable_health(ARGV[1], ARGV[2]) ? 0 : 1);
    if (mode == 'members') exit(live_members(load(ARGV[1]), load(ARGV[2])) ? 0 : 1);
    if (mode == 'kind') {
        if ((ARGV[3] == null) != (ARGV[4] == null)) exit(1);
        let result = kind(load(ARGV[1]), load(ARGV[2]), ARGV[3] != null ? load(ARGV[3]) : null, ARGV[4] != null ? load(ARGV[4]) : null);
        if (result == null) exit(1);
        printf('%s\n', result);
        exit(0);
    }
    if (mode == 'prune') exit(prune(ARGV[1]) ? 0 : 1);
    if (mode == 'record') {
        let summary = load(ARGV[4]);
        let changes = { added: summary.added, removed: summary.removed, changed: summary.changed,
            order_changed: summary.order_changed, rule_count: summary.rule_count,
            group_node_changes:summary.group_node_changes || [],fallback_changes:summary.fallback_changes || [],real_dns_change:summary.real_dns_change,
            apply_kind: summary.apply_kind, member_changes: summary.member_changes, default_node: summary.default_node, node_count: summary.node_count, node_summary_version: summary.node_summary_version, node_changes: map(summary.node_changes || [], n => ({id:n.id,name:n.name,action:n.action})), default_node_change: summary.default_node_change ? {before_name:summary.default_node_change.before_name,after_name:summary.default_node_change.after_name} : null };
        printf('%J\n', { time_utc: split(ARGV[1], '-')[0], version: ARGV[1], result: ARGV[2],
            elapsed_seconds: int(ARGV[3]), changes: changes });
        exit(0);
    }
    exit(64);
} catch (e) {
    // Never echo parser errors or configuration values.
    exit(1);
}
