#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-only
# HY2 port hopping and certificate pin checks for the generator, on an isolated OpenWrt test machine
# with LaneKeep's dependencies installed. Generates into a private /tmp directory with synthetic
# nodes (TEST-NET addresses, fixed fake pins); it does not install, start or reload anything.
# Usage: hy2-check.sh REPO [PREVIOUS_REPO]
# PREVIOUS_REPO (optional) is the release to compare with: stores without the new fields must give
# byte-identical output and node identities, and the previous generator must refuse a format 7 store.
set -u
REPO=$(cd "${1:?usage: hy2-check.sh REPO [PREVIOUS_REPO]}" && pwd)
OLD=${2:-}; [ -z "$OLD" ] || OLD=$(cd "$OLD" && pwd)
HERE=$(cd "$(dirname "$0")" && pwd)
T=$(mktemp -d /tmp/lanekeep-hy2-check.XXXXXX)
trap 'rm -rf "$T"' EXIT
failed=0
pass() { echo "PASS $*"; }
fail() { echo "FAIL $*"; failed=1; }

members=$(ucode "$HERE/lan-members.uc") || { echo 'FAIL lan_context'; exit 1; }
set -- $members; [ "$#" = 3 ] || { echo 'FAIL lan_members'; exit 1; }
M1=$1 M2=$2 M3=$3

# Stores are built from share links by the new parser. The plain store is what the same links give
# without mport/pinSHA256, so it is also the "fields removed" twin of the hop store.
{ printf "import * as nodes from '%s/root/usr/libexec/lanekeep-panel/nodes.uc';\n" "$REPO"; cat <<'EOF'
import * as fs from 'fs';
let PIN='0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
let PIN2='fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';
let V='vless://00000000-0000-4000-8000-000000000001@203.0.113.30:443?security=reality&pbk=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA&sni=example.com&fp=chrome&flow=xtls-rprx-vision&sid=abcd';
function one(link,id,name){let r=nodes.parse_preview(link)[0];if(r.status!='ok')die('parse '+id+' '+sprintf('%J',r.error));let n=r.node;n.id=id;n.name=name;return n;}
let plain=[one('hysteria2://PASSWORD@203.0.113.20:443/?sni=example.com&alpn=h3','node_a','HY2 A'),
 one('hysteria2://PASSWORD@203.0.113.21:443/?sni=example.net','node_b','HY2 B'),
 one('hysteria2://PASSWORD@203.0.113.22:8443/?sni=example.org','node_c','HY2 C'),one(V,'node_v','VLESS V')];
let hop=[one('hysteria2://PASSWORD@203.0.113.20:443/?sni=example.com&alpn=h3&mport=20000-50000&pinSHA256='+PIN,'node_a','HY2 A'),
 one('hy2://PASSWORD@203.0.113.21:443,20000-30000,40000/?sni=example.net','node_b','HY2 B'),
 one('hysteria2://PASSWORD@203.0.113.22:8443/?sni=example.org&insecure=1&pinSHA256='+PIN2,'node_c','HY2 C'),one(V,'node_v','VLESS V')];
function write(name,version,list){let s={version:version,default_node:'node_a',nodes:list};fs.writefile(ARGV[0]+'/'+name,sprintf('%J\n',s));}
// Form-only tuning: node A hops every 60 s with bandwidth, node C has a download bandwidth only.
hop[0].hop_interval=60;hop[0].up_mbps=60;hop[0].down_mbps=200;hop[2].down_mbps=100;
write('plain.json',6,plain);write('hop.json',7,hop);write('hop-v6.json',6,hop);
EOF
} >"$T/stores.uc"
ucode "$T/stores.uc" "$T" || { echo 'FAIL store builder'; exit 1; }
chmod 600 "$T"/*.json

rule() { # id group type value action [node]
  printf "config rule '%s'\n\toption group '%s'\n\toption type '%s'\n\toption value '%s'\n\toption action '%s'\n" "$1" "$2" "$3" "$4" "$5"
  [ -z "${6:-}" ] || printf "\toption node '%s'\n" "$6"
  printf "\toption enabled '1'\n\toption note ''\n\n"
}
mkdir -p "$T/cfg"
{
  printf "config group 'global'\n\toption label 'Global'\n\tlist member '%s'\n\n" "$M1"
  printf "config group 'enhanced'\n\toption label 'Enhanced'\n\tlist member '%s'\n\n" "$M2"
  printf "config group 'ondemand'\n\toption label 'On-demand'\n\tlist member '%s'\n\n" "$M3"
  printf "config group_proxy 'group_proxy_global'\n\toption group 'global'\n\toption node 'node_b'\n\n"
  printf "config group_proxy 'group_proxy_enhanced'\n\toption group 'enhanced'\n\toption node 'node_c'\n\n"
  for g in standard:direct global:proxy enhanced:proxy ondemand:direct; do
    printf "config fallback 'fallback_%s'\n\toption group '%s'\n\toption action '%s'\n\n" "${g%%:*}" "${g%%:*}" "${g#*:}"
  done
  printf "config real_dns 'real_dns'\n\n"
  rule r_std_1 standard domain example.com proxy
  rule r_glb_1 global keyword abcdef direct
  rule r_enh_1 enhanced domain github.com node node_v
  rule r_ond_1 ondemand domain tv.example.com node node_b
  rule r_enh_entry enhanced dedicated 10811 proxy
} >"$T/cfg/lanekeep"
for ip in "$M1" "$M2" "$M3"; do printf "config host\n\toption name 'test-%s'\n\toption ip '%s'\n\n" "${ip##*.}" "$ip"; done >"$T/cfg/dhcp"

gen() { # tree output nodes -> sets $error
  sh "$1/root/usr/libexec/lanekeep-xray/lanekeep-gen" --config-dir "$T/cfg" --template "$1/root/etc/lanekeep-proxy/template.json" \
    --baseline "$1/root/etc/lanekeep-proxy/panel-baseline.json" --nodes-file "$3" --output-dir "$2" >/dev/null 2>"$2.err"
  rc=$?; error=$(sed -n 's/.*"error": *"\([a-z0-9_]*\)".*/\1/p' "$2.err" | head -1); return $rc
}
same_dirs() { # a b -> 0 when every output file matches (summary paths normalized)
  ok=0
  for f in config.json phone-pilot.nft members.nft normalized-rules.json invariant-template.json invariant-output.json; do
    cmp -s "$1/$f" "$2/$f" || { ok=1; echo "  differs: $f"; }
  done
  sed "s#$1#STAGE#g" "$1/summary.json" >"$T/sa"; sed "s#$2#STAGE#g" "$2/summary.json" >"$T/sb"
  cmp -s "$T/sa" "$T/sb" || { ok=1; echo '  differs: summary.json'; }
  return $ok
}
mkdir -p "$T/out"
if gen "$REPO" "$T/out/plain" "$T/plain.json"; then pass 'generator with plain HY2 nodes (xray -test included)'; else fail "generator plain: $error"; fi
if gen "$REPO" "$T/out/hop" "$T/hop.json"; then pass 'generator with HY2 hop/pin nodes as default, global and enhanced (xray -test included)'; else fail "generator hop: $error"; fi
if [ -f "$T/out/hop/config.json" ]; then
  ucode "$HERE/hy2-config-check.uc" "$T/out/hop/config.json" "$T/out/plain/config.json" "$REPO/root/etc/lanekeep-proxy/template.json" \
    && pass 'hop/pin outbounds: udphop last, pin set, no allowInsecure, marks kept, routes unchanged' || fail 'hop/pin outbound structure'
  # normalized-rules.json records the node store hash (nodes_revision), which differs by construction.
  out=$(same_dirs "$T/out/plain" "$T/out/hop" | grep -v 'differs: config.json\|differs: normalized-rules.json')
  for d in plain hop; do sed 's/"nodes_revision": *"[0-9a-f]*"/"nodes_revision": "-"/' "$T/out/$d/normalized-rules.json" >"$T/rules-$d"; done
  grep -q '"nodes_revision": "-"' "$T/rules-hop" || out="$out nodes_revision not found"
  cmp -s "$T/rules-plain" "$T/rules-hop" || out="$out normalized-rules.json"
  [ -z "$out" ] && pass 'hop/pin store changes no nft, rule or invariant output (only nodes_revision differs)' || { fail 'hop/pin changed other output'; echo "$out"; }
fi
if gen "$REPO" "$T/out/hop-v6" "$T/hop-v6.json"; then fail 'format 6 store with hop/pin accepted'; else
  [ -n "$error" ] && pass "format 6 store with hop/pin rejected ($error)" || fail 'format 6 store rejected without error code'; fi

{ printf "import * as nodes from '%s/root/usr/libexec/lanekeep-panel/nodes.uc';\n" "$REPO"; cat "$HERE/hy2-identity.uc"; } >"$T/identity-new.uc"
ucode "$T/identity-new.uc" >"$T/identity-new.json" || fail 'identity script (new)'
if [ -n "$OLD" ]; then
  if gen "$OLD" "$T/out/old-plain" "$T/plain.json"; then
    out=$(same_dirs "$T/out/old-plain" "$T/out/plain")
    [ -z "$out" ] && pass 'previous and new generator output identical for plain HY2 and VLESS nodes' || { fail 'output changed for plain nodes'; echo "$out"; }
  else fail "previous generator plain: $error"; fi
  if gen "$OLD" "$T/out/old-hop" "$T/hop.json"; then fail 'previous generator accepted a format 7 store'; else
    [ -n "$error" ] && pass "previous generator rejects the format 7 store ($error)" || fail 'previous generator rejected without error code'; fi
  { printf "import * as nodes from '%s/root/usr/libexec/lanekeep-panel/nodes.uc';\n" "$OLD"; cat "$HERE/hy2-identity.uc"; } >"$T/identity-old.uc"
  ucode "$T/identity-old.uc" >"$T/identity-old.json" || fail 'identity script (previous)'
  cmp -s "$T/identity-old.json" "$T/identity-new.json" && pass 'parse, render, identity and verification keys unchanged for links without the new parameters' \
    || fail 'node identity changed for existing links'
fi
[ "$failed" = 0 ] && echo 'ALL PASS' || echo 'SOME CHECKS FAILED'
exit "$failed"
