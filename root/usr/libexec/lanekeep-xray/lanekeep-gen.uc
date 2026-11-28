import * as lan from '../lanekeep-panel/network.uc';
// Step 3 first creation: no old version. Local UCI -> private Xray/nft staging only.
import * as fs from 'fs';
import * as uci from 'uci';
import * as dedicated from '../lanekeep-panel/dedicated.uc';
import * as settings from '../lanekeep-panel/settings.uc';
import * as telemetry from '../lanekeep-panel/telemetry-config.uc';
import * as dns_idle from '../lanekeep-panel/dns-idle.uc';
import * as ip_rule from '../lanekeep-panel/ip-rule.uc';
import { validate_store, read_store, render, assert_reference, assert_default, role, route_tag, chain_rules, chain_closure, chain_outbound, assert_chain_outbounds, chain_impact } from '../lanekeep-panel/nodes.uc';

let config_dir = ARGV[0];
let template_path = ARGV[1];
let baseline_path = ARGV[2];
let output_dir = ARGV[3];
let previous_dir = ARGV[4];
let nodes_path = ARGV[5];
let nodes_revision = ARGV[6];
let node_store;
let node_map = {};
let current_data,active_closure;
let groups = [ 'global', 'enhanced', 'ondemand', 'standard' ];
// Explicit member sets. Standard and direct may also receive devices without a set,
// chosen by the unassigned setting; only the first three can own dedicated entries.
let member_groups = [ 'global', 'enhanced', 'ondemand', 'standard', 'direct' ];
let dedicated_groups = [ 'global', 'enhanced', 'ondemand' ];
let optional_groups = { standard: '常规模式', direct: '直连' };
let unassigned_chains = { standard: 'capture_phone', direct: 'capture_direct' };
let tags = { global: 'global-transparent', enhanced: 'enhanced-transparent', ondemand: 'ondemand-transparent', standard: 'standard-transparent' };
let actions = { proxy: 'proxy-default', direct: 'direct', block: 'block' };
// Fixed accepted nft structure; only membership sets and the unassigned jump are generated.
let nft_template = "# LaneKeep gateway policy; source IP selection includes future LAN clients.\n# Apply as one nft transaction only after nft -c. No MAC-based selection.\n# Direct group: internal ports on every router address are dropped, except DNS to the LAN address;\n# all other traffic, router DNS included, uses the core's direct inbound.\ntable inet lanekeep_phone {}\nflush table inet lanekeep_phone\ntable inet lanekeep_phone {\n__LANEKEEP_MEMBER_SETS__\n    counter selected {}\n    counter captured {}\n    counter blocked_forward {}\n    counter blocked_input {}\n    chain capture_phone {\n        meta l4proto { tcp, udp } counter name selected ct mark set 0x7611\n        meta l4proto { tcp, udp } tproxy to :12345 meta mark set 0x7610 counter name captured accept\n    }\n    chain capture_global {\n        meta l4proto { tcp, udp } counter name selected ct mark set 0x7611\n        meta l4proto { tcp, udp } tproxy to :12346 meta mark set 0x7610 counter name captured accept\n    }\n    chain capture_enhanced {\n        meta l4proto { tcp, udp } counter name selected ct mark set 0x7611\n        meta l4proto { tcp, udp } tproxy to :12347 meta mark set 0x7610 counter name captured accept\n    }\n    chain capture_ondemand {\n        meta l4proto { tcp, udp } counter name selected ct mark set 0x7611\n        meta l4proto { tcp, udp } tproxy to :12348 meta mark set 0x7610 counter name captured accept\n    }\n    chain capture_direct {\n        fib daddr type local ip daddr != __LAN_ADDRESS__ meta l4proto { tcp, udp } th dport 53 counter drop\n        fib daddr type local meta l4proto { tcp, udp } th dport { 853, 1053, 5053, 10811-10860, 12345-12349 } counter drop\n        meta l4proto { tcp, udp } counter name selected ct mark set 0x7611\n        meta l4proto { tcp, udp } tproxy to :12349 meta mark set 0x7610 counter name captured accept\n    }\n    chain dispatch_device {\n        ip saddr @lanekeep_grp_global jump capture_global\n        ip saddr @lanekeep_grp_enhanced jump capture_enhanced\n        ip saddr @lanekeep_grp_ondemand jump capture_ondemand\n        ip saddr @lanekeep_grp_standard jump capture_phone\n        ip saddr @lanekeep_grp_direct jump capture_direct\n        meta l4proto { tcp, udp } jump __LANEKEEP_UNASSIGNED_CHAIN__\n    }\n    chain select_phone {\n        type filter hook prerouting priority -151; policy accept;\n        iifname != \"__LAN_DEVICE__\" return\n        meta nfproto != ipv4 return\n        ip saddr != __LAN_SUBNET__ return\n        udp sport 68 udp dport 67 return\n        ip daddr { __LAN_BROADCAST__, 255.255.255.255, 224.0.0.0/4 } meta l4proto udp counter drop comment \"lanekeep_no_proxy_nonunicast_udp_v2\"\n        # DNS is captured before management, DHCP, or any upstream exception.\n        meta l4proto { tcp, udp } th dport 53 jump dispatch_device\n        ip daddr __LAN_ADDRESS__ tcp dport { 22, 80, 443 } return\n        meta l4proto { tcp, udp } jump dispatch_device\n    }\n    chain prevent_forward {\n        type filter hook forward priority -1; policy accept;\n        iifname != \"__LAN_DEVICE__\" return\n        meta nfproto != ipv4 return\n        ip saddr != __LAN_SUBNET__ return\n        # No established/related shortcut: old connections cannot bypass capture.\n        counter name blocked_forward drop\n    }\n    chain prevent_input_fallback {\n        type filter hook input priority -1; policy accept;\n        iifname != \"__LAN_DEVICE__\" return\n        meta nfproto != ipv4 return\n        ip saddr != __LAN_SUBNET__ return\n        udp sport 68 udp dport 67 return\n        ip daddr __LAN_ADDRESS__ tcp dport { 22, 80, 443 } return\n        meta l4proto { tcp, udp } meta mark != 0x7610 counter name blocked_input drop\n    }\n}\n";
let phase = 'initialization';

function fail(code) {
    fs.writefile(output_dir + '/error.json', sprintf('%J\n', { ok: false, error: code }));
    exit(1);
}

function canonical(value) {
    let t = type(value);
    if (t == 'object') {
        let pieces = [];
        for (let key in sort(keys(value)))
            push(pieces, sprintf('%J', key) + ':' + canonical(value[key]));
        return '{' + join(',', pieces) + '}';
    }
    if (t == 'array') {
        let pieces = [];
        for (let item in value) push(pieces, canonical(item));
        return '[' + join(',', pieces) + ']';
    }
    return sprintf('%J', value);
}

function equal(a, b) { return canonical(a) == canonical(b); }
function clone(value) { return json(canonical(value)); }
function contains(list, item) { return index(list, item) >= 0; }
function read_json(path) {
    let text = fs.readfile(path);
    if (text == null) fail('required_json_unreadable');
    let value;
    try { value = json(text); } catch (e) { fail('invalid_json'); }
    if (type(value) != 'object') fail('json_object_required');
    return value;
}
function write_json(name, value) {
    if (fs.writefile(output_dir + '/' + name, canonical(value) + '\n') == null)
        fail('stage_write_failed');
}
function write_text(name, value) {
    if (fs.writefile(output_dir + '/' + name, value) == null)
        fail('stage_write_failed');
}

function render_nft(data) {
    let definitions = [];
    for (let group in member_groups) {
        let lines = [ '    set lanekeep_grp_' + group + ' {', '        type ipv4_addr' ];
        let members = data.groups[group].member;
        if (length(members)) push(lines, '        elements = { ' + join(', ', members) + ' }');
        push(lines, '    }');
        push(definitions, join('\n', lines));
    }
    let chain = unassigned_chains[data.unassigned];
    if (chain == null) fail('invalid_unassigned');
    let text = replace(nft_template, '__LANEKEEP_MEMBER_SETS__', join('\n', definitions));
    if (index(text, '__LANEKEEP_UNASSIGNED_CHAIN__') < 0) fail('unassigned_anchor');
    text = replace(text, '__LANEKEEP_UNASSIGNED_CHAIN__', chain);
    return telemetry.nft(dedicated.nft(text,data.rules));
}

function render_members(data) {
    let lines = [ '# One nft transaction; existing connections are not cleared.' ];
    for (let group in member_groups) {
        let name = 'inet lanekeep_phone lanekeep_grp_' + group;
        push(lines, 'flush set ' + name);
        let members = data.groups[group].member;
        if (length(members)) push(lines, 'add element ' + name + ' { ' + join(', ', members) + ' }');
    }
    return join('\n', lines) + '\n';
}

function allowed_options(section, allowed) {
    for (let key in keys(section))
        if (substr(key, 0, 1) != '.' && !contains(allowed, key)) fail('unsupported_uci_option');
}
function string_option(section, key, fallback) {
    let value = section[key];
    if (value == null) value = fallback;
    if (type(value) != 'string') fail('string_option_required');
    return value;
}

function load_config(directory, need_dhcp, available_nodes) {
    // Explicit empty delta location avoids /tmp/.uci affecting staged or committed input.
    let savedir = directory + '/.lanekeep-empty-deltas';
    if (fs.lstat(savedir) != null) fail('uci_delta_directory_must_not_exist');
    let cursor = uci.cursor(directory, savedir);
    if (!cursor.load('lanekeep')) fail('uci_load_failed');
    let data = settings.defaults(); data.groups={};data.rules=[];let setting_sections={};
    let assigned = {};
    if (need_dhcp) {
        if (!cursor.load('dhcp')) fail('dhcp_load_failed');
        cursor.foreach('dhcp', 'host', function(section) {
            if (type(section.ip) == 'string') assigned[section.ip] = true;
        });
    }
    let claimed = {};
    let seen = {};
    let ports = {};
    let value_actions = {};
    let counts = { global: 0, enhanced: 0, ondemand: 0, standard: 0 };
    cursor.foreach('lanekeep', null, function(section) {
        if(settings.section(data,section,setting_sections))return;
        if (section['.type'] == 'group') {
            allowed_options(section, [ 'label', 'member' ]);
            let group = section['.name'];
            if (!contains(member_groups, group) || data.groups[group] != null) fail('invalid_group_section');
            let label = string_option(section, 'label', group);
            if (length(label) > 80 || match(label, /[[:cntrl:]]/)) fail('invalid_label');
            let members = section.member;
            if (members == null) members = [];
            if (type(members) != 'array') fail('member_list_required');
            for (let address in members) {
                if (!lan.member(address)) fail('invalid_member_ip');
                if (claimed[address] != null) fail('member_duplicate_or_cross_group');
                claimed[address] = group;
                if (need_dhcp && !assigned[address]) fail('member_needs_static_dhcp');
            }
            data.groups[group] = { label: label, member: sort(members) };
            return;
        }
        if (section['.type'] != 'rule') fail('unsupported_uci_section');
        allowed_options(section, [ 'group', 'type', 'value', 'action', 'node', 'enabled', 'note' ]);
        let group = string_option(section, 'group', '');
        let kind = string_option(section, 'type', '');
        let value = string_option(section, 'value', '');
        let action = string_option(section, 'action', '');
        let node = string_option(section, 'node', '');
        let enabled = string_option(section, 'enabled', '1');
        let note = string_option(section, 'note', '');
        if (!contains(groups, group)) fail('invalid_rule_group');
        if (!contains([ 'domain', 'full', 'keyword', 'ip', 'regexp', 'dedicated', 'geosite' ], kind)) fail('invalid_rule_type');
        if (action == 'node') { if ((available_nodes || node_map)[node] == null) fail('rule_node_missing'); assert_reference((available_nodes || node_map)[node],{nodes:values(available_nodes || node_map),default_node:node_store.default_node}); }
        else if (actions[action] == null || node != '') fail('invalid_rule_action');
        // Literal IP rules have no FakeIP guard, so they never route to a two-hop chain.
        if (kind == 'ip' && action == 'node' && (available_nodes || node_map)[node].protocol == 'chain') fail('ip_rule_chain_forbidden');
        if (enabled != '0' && enabled != '1') fail('invalid_rule_enabled');
        if (length(note) > 256 || match(note, /[[:cntrl:]]/)) fail('invalid_note');
        if (kind == 'geosite') {
            if (value != 'category-ads-all' || action != 'block' || node != '') fail('adblock_rule_must_use_fixed_ads_category_and_block');
        }
        else if (kind == 'dedicated') {
            if (!contains(dedicated_groups,group)) fail('dedicated_standard_forbidden');
            if (!dedicated.valid_port(value)) fail('dedicated_port_range');
            if (ports[value]) fail('dedicated_port_duplicate');
            ports[value]=true;
            if (action=='block') fail('dedicated_block_forbidden');
        }
        else if (kind == 'domain' || kind == 'full') {
            value = lc(trim(value));
            value = replace(value, /\.$/, '');
            if (length(value) > 253 || !match(value, /^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$/)) fail('invalid_domain');
            for (let label in split(value, '.')) if (length(label) > 63) fail('invalid_domain');
        }
        else if (kind == 'keyword') {
            if (length(value) > 253 || !match(value, /^[a-z0-9.-]{3,}$/)) fail('invalid_keyword');
        }
        else if (kind == 'ip') {
            let parsed = ip_rule.normalize(value, lan.context().subnet);
            if (!parsed.ok) fail('invalid_ip_rule');
            value = parsed.value;
        }
        else {
            fail('new_regexp_forbidden');
        }
        let key = group + '|' + kind + '|' + value;
        let value_key = group + '|' + value;
        if (seen[key]) fail('duplicate_rule');
        if (value_actions[value_key] != null && value_actions[value_key] != action + ':' + node) fail('conflicting_rule');
        seen[key] = true;
        value_actions[value_key] = action + ':' + node;
        counts[group]++;
        if (counts[group] > 500) fail('too_many_group_rules');
        push(data.rules, { id: section['.name'], group: group, type: kind, value: value, action: action, node: node, enabled: enabled, note: note });
    });
    for (let group in member_groups) {
        // Configurations from 0.2.x have no standard/direct sections: both start empty.
        if (data.groups[group] == null && optional_groups[group] != null) data.groups[group] = { label: optional_groups[group], member: [] };
        if (data.groups[group] == null) fail('missing_group');
    }
    if (!settings.unassigned_ok(data.unassigned)) fail('invalid_unassigned');
    let validated=settings.validate({fallbacks:data.fallbacks,real_dns:data.real_dns,group_nodes:data.group_nodes},{nodes:values(available_nodes || node_map)});
    data.group_nodes=validated.group_nodes;data.fallbacks=validated.fallbacks;data.real_dns=validated.real_dns;
    cursor.unload('lanekeep');
    if (need_dhcp) cursor.unload('dhcp');
    return data;
}

function verify_baseline(base) {
    if(type(base.routing?.rules)!='array')fail('unsupported_baseline');
    for(let g in groups)if(length(filter(base.routing.rules,r=>r.__lanekeep_user_slot==g))!=1)fail('factory_slot_missing');
}
function expected_template(base) {return clone(base);}

function render_group(data, group) {
    let result = [];
    let ondemand_proxy = [], ondemand_proxy_ip = [];
    let current = null;
    for (let rule in data.rules) {
        if (rule.group != group || rule.enabled != '1' || rule.type=='dedicated') continue;
        // Keep the fixed ad category separate, so removing it restores every old rule exactly.
        if (rule.type == 'geosite') {
            push(result, { type:'field', inboundTag:[tags[group]], domain:['geosite:category-ads-all'], outboundTag:'block' });
            current = null;
            continue;
        }
        // Xray ANDs domain and ip conditions, so IP entries always use their own rows.
        let field = rule.type == 'ip' ? 'ip' : 'domain';
        let entry = rule.type == 'ip' ? rule.value : rule.type + ':' + rule.value;
        let outbound = rule.action == 'node' ? route_tag(rule.node,node_store) : rule.action=='proxy'?settings.proxy_tag(data,group,node_store):actions[rule.action];
        if (field == 'ip' && substr(outbound, 0, 6) == 'chain-') fail('ip_rule_chain_forbidden');
        if (group == 'ondemand' && (rule.action == 'proxy' || rule.action == 'node')) push(field == 'ip' ? ondemand_proxy_ip : ondemand_proxy, entry);
        if (current == null || current.outboundTag != outbound || current[field] == null) {
            current = field == 'ip' ? { type: 'field', inboundTag: [ tags[group] ], ip: [], outboundTag: outbound } :
                { type: 'field', inboundTag: [ tags[group] ], domain: [], outboundTag: outbound };
            push(result, current);
        }
        push(current[field], entry);
    }
    let expanded=[];for(let rule in result)for(let row in chain_rules(rule,node_store))push(expanded,row);result=expanded;
    let protected_result = [];
    if (length(ondemand_proxy)) push(protected_result, { type: 'field', inboundTag: [tags.ondemand], network: 'udp', port: '443', domain: ondemand_proxy, outboundTag: 'block' });
    if (length(ondemand_proxy_ip)) push(protected_result, { type: 'field', inboundTag: [tags.ondemand], network: 'udp', port: '443', ip: ondemand_proxy_ip, outboundTag: 'block' });
    if (length(protected_result)) {
        for (let rule in result) push(protected_result, rule);
        return protected_result;
    }
    return result;
}

// Normalize only the explicitly variable node surface after enforcing tags and marks.
function invariant_surface(config, fixed_rules, template) {
    let originals = {}, allowed = {}, seen = {};
    for (let outbound in template.outbounds) { originals[outbound.tag] = outbound; allowed[outbound.tag] = true; }
    for (let id in keys(node_map)) if(role(node_map[id])=='single') allowed['node-' + id] = true;
    for(let id in active_closure?.chains||[])allowed['chain-'+id]=true;
    if(config!=template)assert_chain_outbounds(config,node_store,active_closure);
    for (let rule in config.routing.rules) {
        if (rule.__lanekeep_user_slot == null && (!allowed[rule.outboundTag] || rule.balancerTag != null)) fail('invalid_outbound_reference');
    }
    let normalized = [];
    for (let outbound in config.outbounds) {
        let tag = outbound.tag;
        if (seen[tag] || !allowed[tag]) fail('invalid_outbound_tag');
        seen[tag] = true;
        if (outbound.protocol == 'freedom' && tag != 'direct') fail('unexpected_freedom_outbound');
        if(substr(tag,0,6)=='chain-')continue;
        if (substr(tag,0,5) == 'node-') {
            if (outbound.streamSettings?.sockopt?.mark != 30241 || outbound.streamSettings?.sockopt?.dialerProxy != null || outbound.proxySettings != null) fail('node_mark_or_fallback_changed');
            continue;
        }
        if (tag == 'proxy-default' || tag == 'dns-protected') {
            if (!equal(outbound.streamSettings.sockopt, originals[tag].streamSettings.sockopt)) fail('default_sockopt_changed');
            let outer = clone(outbound), anchor = clone(originals[tag]);
            delete outer.protocol; delete outer.settings; delete outer.streamSettings;
            delete anchor.protocol; delete anchor.settings; delete anchor.streamSettings;
            if (!equal(outer,anchor)) fail('default_outer_surface_changed');
            push(normalized, clone(originals[tag]));
        } else {
            if (!equal(outbound,originals[tag])) fail('fixed_outbound_changed');
            push(normalized,clone(outbound));
        }
    }
    for (let tag in keys(originals)) if (!seen[tag]) fail('missing_fixed_outbound');
    for (let rule in config.routing.rules) if (rule.__lanekeep_user_slot == null && !seen[rule.outboundTag]) fail('referenced_outbound_not_rendered');
    let surface = clone(config);
    let entries=dedicated.active(current_data.rules);
    if(config!=template) {
        let expected_inbounds=clone(template.inbounds);
        for(let entry in entries)push(expected_inbounds,dedicated.inbound(entry));
        if(!equal(config.inbounds,expected_inbounds))fail('dedicated_inbound_invariant');
        let expected_routes=[];
        for(let entry in entries)for(let r in dedicated.routes(entry,node_store))push(expected_routes,r);
        let actual_routes=filter(config.routing.rules,r=>length(filter(r.inboundTag || [],t=>substr(t,0,10)=='dedicated-'))>0);
        if(!equal(expected_routes,actual_routes))fail('dedicated_route_invariant');
        let expected_fixed=[];for(let r in template.routing.rules)if(r.__lanekeep_user_slot==null)for(let generated in settings.routes(dedicated.protected_rule(r,length(entries)>0),current_data,node_store))push(expected_fixed,generated);
        if(!equal(fixed_rules,expected_fixed))fail('fixed_route_invariant');
        if(!equal(config.dns,settings.dns(template.dns,current_data)))fail('real_dns_invariant');
    }
    surface.dns=clone(template.dns);
    surface.inbounds=clone(template.inbounds);
    surface.routing.rules = filter(template.routing.rules,r=>r.__lanekeep_user_slot==null);
    surface.outbounds = normalized;
    return surface;
}

function public_rule(rule) {
    return { id: rule.id, group: rule.group, type: rule.type, value: rule.value, action: rule.action, node: rule.node, enabled: rule.enabled };
}

function summarize(current, previous) {
    let old = {};
    let now = {};
    let added = [], removed = [], changed = [];
    for (let rule in previous.rules) old[rule.id] = rule;
    for (let rule in current.rules) now[rule.id] = rule;
    for (let rule in current.rules) {
        if (old[rule.id] == null) push(added, public_rule(rule));
        else if (!equal(old[rule.id], rule)) push(changed, { before: public_rule(old[rule.id]), after: public_rule(rule) });
    }
    for (let rule in previous.rules) if (now[rule.id] == null) push(removed, public_rule(rule));
    let old_order = map(previous.rules, (r) => r.id);
    let new_order = map(current.rules, (r) => r.id);
    let member_changes = [], label_changes = [];
    for (let group in member_groups) {
        if (!equal(current.groups[group].member, previous.groups[group].member))
            push(member_changes, { group: group, before: previous.groups[group].member, after: current.groups[group].member });
        if (current.groups[group].label != previous.groups[group].label)
            push(label_changes, { group: group, before: previous.groups[group].label, after: current.groups[group].label });
    }
    // Rules include disabled entries, notes and order; these must not enter the members branch.
    let settings_diff=settings.diff(previous,current);
    // The unassigned choice changes the nft dispatch chain, so it takes the full rules path.
    let apply_kind = !equal(current.rules, previous.rules) || length(settings_diff.group_node_changes) || length(settings_diff.fallback_changes) || settings_diff.real_dns_change!=null || settings_diff.unassigned_change!=null ? 'rules' :
        length(member_changes) ? 'members' : length(label_changes) ? 'metadata' : 'unchanged';
    return { ok: true, generated_only: true, restart_performed: false, added: added, removed: removed, changed: changed,
        order_changed: !equal(old_order, new_order), rule_count: length(current.rules),
        member_changes: member_changes, label_changes: label_changes, apply_kind: apply_kind,
        group_node_changes:settings_diff.group_node_changes,fallback_changes:settings_diff.fallback_changes,real_dns_change:settings_diff.real_dns_change,
        unassigned_change:settings_diff.unassigned_change,unassigned:current.unassigned,
        stage: output_dir, config: output_dir + '/config.json', nft: output_dir + '/phone-pilot.nft', members: output_dir + '/members.nft' };
}

function validate_regexp_transition(current, previous) {
    let old_regexp = false;
    for (let rule in previous.rules) if (rule.type == 'regexp') old_regexp = true;
    for (let rule in current.rules) if (rule.type == 'regexp' && !old_regexp) fail('deleted_regexp_cannot_be_recreated');
}

try {
    phase = 'read_baseline';
    let baseline = read_json(baseline_path);
    phase = 'verify_baseline';
    verify_baseline(baseline);
    phase = 'read_template';
    let template = read_json(template_path);
    phase = 'verify_template';
    if (!equal(template, expected_template(baseline))) fail('template_drift_from_fixed_baseline');
    phase = 'read_nodes';
    node_store = read_store(nodes_path);
    validate_store(node_store);
    for (let node in node_store.nodes) node_map[node.id] = node;
    if(node_store.default_node!='')assert_default(node_map[node_store.default_node]);
    phase = 'read_current_uci';
    let data = load_config(config_dir, true);
    current_data=data;
    phase = 'read_previous_uci';
    let previous_store = node_store;
    if (previous_dir != '') {
        let previous_nodes_path = fs.lstat(previous_dir + '/nodes.json') != null ? previous_dir + '/nodes.json' : '/etc/lanekeep-proxy/nodes.json';
        previous_store = read_store(previous_nodes_path);
    }
    let previous_map = {};
    for (let node in previous_store.nodes) previous_map[node.id] = node;
    let previous = previous_dir != '' ? load_config(previous_dir, false, previous_map) : data;
    validate_regexp_transition(data, previous);
    data.nodes_revision = nodes_revision;
    data.default_node = node_store.default_node;
    if (previous_dir == '') { previous.nodes_revision = nodes_revision; previous.default_node = node_store.default_node; }
    phase = 'render';
    let output = clone(template);
    output.dns=settings.dns(template.dns,data);
    let final_counts={};
    for(let rule in template.routing.rules){let g=settings.fallback_group(rule);if(g!=null)final_counts[g]=(final_counts[g] || 0)+1;}
    for(let g in groups)if(final_counts[g]!=1)fail('fallback_anchor_count');
    let output_rules = [], fixed_template = [], fixed_output = [];
    let entries=dedicated.active(data.rules), anchor_count=0, internal_count=0;
    for(let entry in entries) push(output.inbounds,dedicated.inbound(entry));
    for (let rule in template.routing.rules) {
        if(dedicated.dns_anchor(rule)) {
            anchor_count++;
            for(let entry in entries)for(let generated in dedicated.routes(entry,node_store))push(output_rules,generated);
        }
        if(dedicated.internal_rule(rule))internal_count++;
        if (rule.__lanekeep_user_slot != null) {
            for (let generated in render_group(data, rule.__lanekeep_user_slot)) push(output_rules, generated);
        }
        else {
            push(fixed_template, rule);
            for(let generated in settings.routes(dedicated.protected_rule(rule,length(entries)>0),data,node_store)){push(output_rules,generated);push(fixed_output,generated);}
        }
    }
    if(anchor_count!=1 || internal_count!=1)fail('dedicated_anchor_drift');
    output.routing.rules = output_rules;
    let roots=node_store.default_node!=''?[node_store.default_node]:[],anchor=null;
    for(let rule in data.rules)if(rule.enabled=='1'&&rule.action=='node')push(roots,rule.node);
    for(let g in groups){if(data.group_nodes[g])push(roots,data.group_nodes[g]);let f=data.fallbacks[g];if(f.action=='node')push(roots,f.node);}
    active_closure=chain_closure(node_store,roots);
    for (let outbound in output.outbounds) if (outbound.tag == 'proxy-default') anchor = clone(outbound);
    if (anchor == null) fail('default_anchor_missing');
    function node_outbound(node, original, tag) {
        assert_reference(node);
        let rendered = render(node);
        let result = clone(original);
        result.protocol = rendered.protocol;
        result.settings = clone(rendered.settings);
        result.streamSettings = clone(rendered.streamSettings);
        result.streamSettings.sockopt = clone(original.streamSettings.sockopt);
        result.tag = tag;
        if (tag != 'dns-protected') result.streamSettings.sockopt.mark = 30241;
        return result;
    }
    for (let i = 0; i < length(output.outbounds); i++) {
        let tag = output.outbounds[i].tag;
        if (node_store.default_node!='' && (tag == 'proxy-default' || tag == 'dns-protected')) output.outbounds[i] = node_outbound(node_map[node_store.default_node], output.outbounds[i], tag);
    }
    for(let id in active_closure.regular)push(output.outbounds,node_outbound(node_map[id],anchor,'node-'+id));
    for(let id in active_closure.chains)push(output.outbounds,chain_outbound(node_map[id],node_store,route_tag(node_map[id].front,node_store)));
    phase = 'invariant';
    let before = invariant_surface(template, fixed_template, template);
    let after = invariant_surface(output, fixed_output, template);
    if (!equal(before, after)) fail('invariant_mismatch');
    phase = 'write_output';
    write_json('invariant-template.json', before);
    write_json('invariant-output.json', after);
    // Invariants above cover the unchanged forwarding configuration.
    telemetry.enable(output);
    dns_idle.enable(output);
    if(node_store.default_node!='')settings.standard_dns_enable(output);
    write_json('config.json', json(lan.expand(canonical(output))));
    write_text('phone-pilot.nft', lan.expand(render_nft(data)));
    write_text('members.nft', render_members(data));
    write_json('normalized-rules.json', data);
    let summary = summarize(data, previous);
    summary.default_node = node_store.default_node;
    summary.node_count = length(node_store.nodes);
    summary.active_chain_count=length(active_closure.chains);summary.active_referenced_records=length(active_closure.records);summary.active_regular_outbounds=length(active_closure.regular)+1;summary.affected_chains=chain_impact(previous_store,node_store);
    summary.nodes_changed = !equal(node_store,previous_store);
    summary.previous_default_node = previous_store.default_node;
    // Persist a strictly public diff, including edits of secret values without the values.
    summary.node_summary_version = 1;
    summary.node_changes = [];
    for(let n in node_store.nodes) {
        let old=previous_map[n.id];
        if(!old || !equal(old,n))push(summary.node_changes,{id:n.id,name:n.name,action:old?'修改':'新增'});
    }
    for(let n in previous_store.nodes)if(!node_map[n.id])push(summary.node_changes,{id:n.id,name:n.name,action:'删除'});
    if(node_store.default_node!=previous_store.default_node)
        summary.default_node_change={before_name:previous_map[previous_store.default_node]?.name || '',after_name:node_map[node_store.default_node]?.name || ''};
    write_json('summary.json', summary);
} catch (e) {
    // This diagnostic is redirected into the private stage log, never shown to users.
    print(sprintf('%J\n', { phase: phase, type: e.type, message: e.message, stacktrace: e.stacktrace }));
    fail('generator_internal_error_at_' + phase);
}
