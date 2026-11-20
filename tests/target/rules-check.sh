#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-only
# IP rule checks for an isolated OpenWrt test machine with LaneKeep's dependencies installed.
# Generates into a private /tmp directory with synthetic nodes and rules; it does not install,
# start or reload anything. Usage: rules-check.sh REPO [PREVIOUS_REPO]
# REPO is a checkout of this repository; PREVIOUS_REPO (optional) is the release to compare with.
set -u
REPO=$(cd "${1:?usage: rules-check.sh REPO [PREVIOUS_REPO]}" && pwd)
OLD=${2:-}; [ -z "$OLD" ] || OLD=$(cd "$OLD" && pwd)
HERE=$(cd "$(dirname "$0")" && pwd)
T=$(mktemp -d /tmp/lanekeep-rules-check.XXXXXX)
trap 'rm -rf "$T"' EXIT
failed=0
pass() { echo "PASS $*"; }
fail() { echo "FAIL $*"; failed=1; }

members=$(ucode "$HERE/lan-members.uc") || { echo 'FAIL lan_context'; exit 1; }
set -- $members; [ "$#" = 3 ] || { echo 'FAIL lan_members'; exit 1; }
M1=$1 M2=$2 M3=$3

node() { # id name server
  printf '{"id":"%s","name":"%s","protocol":"vless","server":"%s","port":443,"sni":"www.example.com","uuid":"00000000-0000-4000-8000-%012d","flow":"xtls-rprx-vision","fingerprint":"chrome","public_key":"%s","short_id":"abcd"}' \
    "$1" "$2" "$3" "$4" "$(printf 'A%.0s' $(seq 1 43))"
}
printf '{"version":6,"default_node":"node_a","nodes":[%s,%s]}\n' "$(node node_a 'Test A' 203.0.113.10 1)" "$(node node_b 'Test B' 203.0.113.11 2)" >"$T/nodes.json"
printf '{"version":6,"default_node":"node_a","nodes":[%s,%s,{"id":"node_s","name":"Test S","protocol":"socks5","server":"203.0.113.30","port":1080,"security":"none","transport":"raw","username":"","password":"","provider_udp":false},{"id":"chain_x","name":"Test chain","protocol":"chain","front":"node_b","rear":"node_s","udp":false}]}\n' \
  "$(node node_a 'Test A' 203.0.113.10 1)" "$(node node_b 'Test B' 203.0.113.11 2)" >"$T/nodes-chain.json"
chmod 600 "$T"/nodes*.json

rule() { # id group type value action [node] [enabled]
  printf "config rule '%s'\n\toption group '%s'\n\toption type '%s'\n\toption value '%s'\n\toption action '%s'\n" "$1" "$2" "$3" "$4" "$5"
  [ -z "${6:-}" ] || printf "\toption node '%s'\n" "$6"
  printf "\toption enabled '%s'\n\toption note ''\n\n" "${7:-1}"
}
base() {
  printf "config group 'global'\n\toption label 'Global'\n\tlist member '%s'\n\n" "$M1"
  printf "config group 'enhanced'\n\toption label 'Enhanced'\n\tlist member '%s'\n\n" "$M2"
  printf "config group 'ondemand'\n\toption label 'On-demand'\n\tlist member '%s'\n\n" "$M3"
  for g in standard:direct global:proxy enhanced:proxy ondemand:direct; do
    printf "config fallback 'fallback_%s'\n\toption group '%s'\n\toption action '%s'\n\n" "${g%%:*}" "${g%%:*}" "${g#*:}"
  done
  printf "config real_dns 'real_dns'\n\n"
}
s0_rules() {
  rule r_std_1 standard domain example.com proxy
  rule r_std_2 standard full www.example.org direct
  rule r_glb_1 global keyword abcdef direct
  rule r_enh_ad enhanced geosite category-ads-all block
  rule r_enh_1 enhanced domain github.com node node_b
  rule r_ond_1 ondemand domain tv.example.com proxy
  rule r_enh_entry enhanced dedicated 10811 proxy
}
s1_rules() {
  rule r_std_1 standard domain example.com proxy
  rule r_std_ip1 standard ip 1.2.3.0/24 direct
  rule r_std_ip2 standard ip 1.2.4.7/32 direct
  rule r_std_2 standard full www.example.org direct
  rule r_glb_1 global keyword abcdef direct
  rule r_glb_ip global ip 8.8.8.8 block
  rule r_enh_ad enhanced geosite category-ads-all block
  rule r_enh_1 enhanced domain github.com node node_b
  rule r_enh_ip enhanced ip 9.9.9.0/24 node node_b
  rule r_ond_1 ondemand domain tv.example.com proxy
  rule r_ond_ip1 ondemand ip 4.4.4.4 proxy
  rule r_ond_off ondemand ip 5.5.5.5 direct '' 0
  rule r_ond_ip2 ondemand ip 6.6.6.0/24 node node_b
  rule r_enh_entry enhanced dedicated 10811 proxy
}
scenario() { # name, then UCI text on stdin
  mkdir -p "$T/cfg/$1"; cat >"$T/cfg/$1/lanekeep"
  for ip in "$M1" "$M2" "$M3"; do printf "config host\n\toption name 'test-%s'\n\toption ip '%s'\n\n" "${ip##*.}" "$ip"; done >"$T/cfg/$1/dhcp"
}
{ base; s0_rules; } | scenario s0
{ base; s1_rules; } | scenario s1
for bad in 'r_x standard ip 10.0.0.5 direct' 'r_x standard ip 1.2.3.4/24 direct' 'r_x standard ip 198.18.0.1 proxy' \
           'r_x standard ip 1.2.3 direct' "r_x standard ip $M1 direct"; do
  name=bad_$(echo "$bad" | cut -d' ' -f4 | tr './' '__'); { base; s0_rules; rule $bad; } | scenario "$name"
done
{ base; s0_rules; rule r_x standard domain 1.2.3.4 proxy; rule r_y standard ip 1.2.3.4 direct; } | scenario bad_conflict
{ base; s0_rules; rule r_x standard ip 1.2.3.4 node chain_x; } | scenario chain_node
{ base; printf "config group_proxy 'group_proxy_standard'\n\toption group 'standard'\n\toption node 'chain_x'\n\n"; s0_rules; rule r_x standard ip 1.2.3.4 proxy; } | scenario chain_group
{ base; printf "config group_proxy 'group_proxy_standard'\n\toption group 'standard'\n\toption node 'chain_x'\n\n"; s0_rules; rule r_x standard domain example.net node chain_x; } | scenario chain_control

gen() { # tree scenario output nodes -> sets $error
  sh "$1/root/usr/libexec/lanekeep-xray/lanekeep-gen" --config-dir "$T/cfg/$2" --template "$1/root/etc/lanekeep-proxy/template.json" \
    --baseline "$1/root/etc/lanekeep-proxy/panel-baseline.json" --nodes-file "${4:-$T/nodes.json}" --output-dir "$3" >/dev/null 2>"$3.err"
  rc=$?; error=$(sed -n 's/.*"error": *"\([a-z0-9_]*\)".*/\1/p' "$3.err" | head -1); return $rc
}
mkdir -p "$T/out"
if gen "$REPO" s0 "$T/out/new-s0"; then pass 'generator without IP rules (xray -test included)'; else fail "generator s0: $error"; fi
if gen "$REPO" s1 "$T/out/new-s1"; then pass 'generator with IP rules (xray -test included)'; else fail "generator s1: $error"; fi
if [ -n "$OLD" ]; then
  if gen "$OLD" s0 "$T/out/old-s0"; then
    same=1
    for f in config.json phone-pilot.nft members.nft normalized-rules.json invariant-template.json invariant-output.json; do
      cmp -s "$T/out/old-s0/$f" "$T/out/new-s0/$f" || { same=0; echo "  differs: $f"; }
    done
    sed "s#$T/out/old-s0#STAGE#g" "$T/out/old-s0/summary.json" >"$T/a"; sed "s#$T/out/new-s0#STAGE#g" "$T/out/new-s0/summary.json" >"$T/b"
    cmp -s "$T/a" "$T/b" || { same=0; echo '  differs: summary.json'; }
    [ "$same" = 1 ] && pass 'previous and new generator output identical without IP rules' || fail 'output changed without IP rules'
  else fail "previous generator s0: $error"; fi
  if gen "$OLD" s1 "$T/out/old-s1"; then fail 'previous generator accepted ip type'; else
    [ "$error" = invalid_rule_type ] && pass 'previous generator rejects ip type (invalid_rule_type)' || fail "previous generator s1: $error"; fi
fi
[ -d "$T/out/new-s1" ] && ucode "$HERE/ip-rows-check.uc" "$T/out/new-s0" "$T/out/new-s1" >"$T/rows.json" && pass 'IP rows separate, guarded and additive' || { fail 'IP row structure'; cat "$T/rows.json" 2>/dev/null; }
for s in s0 s1; do
  sh "$HERE/layout-check.sh" "$REPO" "$T/out/new-$s" "$T/nodes.json" >"$T/layout-$s.json" 2>&1 && pass "rules page sequence numbers verified ($s)" || { fail "sequence numbers $s"; head -c 600 "$T/layout-$s.json"; echo; }
done
for s in bad_10_0_0_5:invalid_ip_rule bad_1_2_3_4_24:invalid_ip_rule bad_198_18_0_1:invalid_ip_rule bad_1_2_3:invalid_ip_rule \
         bad_$(echo "$M1" | tr '.' '_'):invalid_ip_rule bad_conflict:conflicting_rule chain_node:ip_rule_chain_forbidden chain_group:ip_rule_chain_forbidden; do
  name=${s%%:*} want=${s#*:} store=$T/nodes.json
  case "$name" in chain_*) store=$T/nodes-chain.json ;; esac
  if gen "$REPO" "$name" "$T/out/$name" "$store"; then fail "$name accepted"; else [ "$error" = "$want" ] && pass "$name rejected ($want)" || fail "$name: got '$error', want $want"; fi
done
if gen "$REPO" chain_control "$T/out/chain_control" "$T/nodes-chain.json"; then pass 'chain control without IP rules accepted'; else fail "chain control: $error"; fi
[ "$failed" = 0 ] && echo 'ALL PASS' || echo 'SOME CHECKS FAILED'
exit "$failed"
