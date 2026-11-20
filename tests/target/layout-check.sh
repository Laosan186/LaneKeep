#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-only
# Runs panel.uc builtins() (the rules page sequence numbers) against one generator output.
# Usage: layout-check.sh REPO OUTPUT_DIR NODES_JSON
set -eu
REPO=$1 OUT=$2 NODES=$3
LIB=$REPO/root/usr/libexec/lanekeep-panel
TEST=$(mktemp /tmp/lanekeep-layout.XXXXXX)
trap 'rm -f "$TEST"' EXIT
{
cat <<EOF
import * as fs from 'fs';
import * as lan from '$LIB/network.uc';
import * as nodes from '$LIB/nodes.uc';
import * as settings from '$LIB/settings.uc';
import * as dedicated from '$LIB/dedicated.uc';
import * as dns_idle from '$LIB/dns-idle.uc';
let GROUPS=['standard','global','enhanced','ondemand'];
let TAGS={standard:'standard-transparent',global:'global-transparent',enhanced:'enhanced-transparent',ondemand:'ondemand-transparent'};
let PROXY='/lanekeep-layout-check', OUT='$OUT', TEMPLATE='$REPO/root/etc/lanekeep-proxy/template.json';
let store=nodes.read_store('$NODES');
let active=json(fs.readfile(OUT+'/config.json')), template=json(fs.readfile(TEMPLATE));
function current_nodes(){return store;}
function obj(p){return p==PROXY+'/config.json'?active:p==PROXY+'/template.json'?template:null;}
function fingerprint(p){if(p!=PROXY+'/template.json')die('unexpected_path');let f=fs.popen('sha256sum '+TEMPLATE);let s=f.read('all');f.close();return split(s,' ')[0];}
function canonical(v){if(type(v)=='object')return '{'+join(',',map(sort(keys(v)),k=>sprintf('%J',k)+':'+canonical(v[k])))+'}';if(type(v)=='array')return '['+join(',',map(v,canonical))+']';return sprintf('%J',v);}
function equal(a,b){return canonical(a)==canonical(b);}
function clone(v){return json(canonical(v));}
function has(a,v){return index(a,v)>=0;}
function exit_label(f){return f.action=='direct'?'直连':f.action=='proxy'?'本组代理节点':'指定节点 '+f.node;}
EOF
# The function under test, copied verbatim from panel.uc.
awk '/^function builtins\(config\) \{/{on=1} /^function logs\(\) \{/{on=0} on' "$LIB/panel.uc"
cat <<'EOF'
let config=json(fs.readfile(OUT+'/normalized-rules.json'));
let layout=builtins(config),missing=[];
for(let r in config.rules)if(r.enabled=='1'&&!length(layout.positions[r.id]||[]))push(missing,r.id);
let slots={};for(let g in GROUPS)slots[g]=map(filter(layout.builtin[g],x=>x.kind=='user_slot'),x=>x.text);
printf('%J\n',{verified:layout.verified,missing,positions:layout.positions,slots});
exit(layout.verified&&!length(missing)?0:1);
EOF
} >"$TEST"
ucode "$TEST"
