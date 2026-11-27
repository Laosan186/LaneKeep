#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-only
# HY2 port hopping and certificate pin runtime check on loopback, for an isolated OpenWrt test
# machine with xray-core, nftables, curl and ucode. Usage: hy2-runtime.sh REPO
# A local Xray HY2 server (self-signed certificate) listens on 127.0.0.1:28443; an nft redirect maps
# the hop ports 20000-20049 to it. The client outbound is rendered by REPO's nodes.uc from a share
# link with mport and pinSHA256 and gets LaneKeep's proxy mark 30241 (0x7621). A copy of LaneKeep's
# DNS gate (renamed table) drops marked traffic without a lease. Checks: the gate blocks before the
# lease and after it is removed; with a lease the correct pin connects and the hop sockets change
# local and remote ports; every packet to a hop port carries the mark; a wrong pin and no pin fail.
# Nothing leaves the machine. The test tables inet lanekeep_hy2_test and inet lanekeep_hy2_gate are
# removed on exit. Refuses to run while LaneKeep's own gate table exists.
set -u
REPO=$(cd "${1:?usage: hy2-runtime.sh REPO}" && pwd)
HERE=$(cd "$(dirname "$0")" && pwd)
NODES=$REPO/root/usr/libexec/lanekeep-panel/nodes.uc
SERVER_PORT=28443 SOCKS=21080 HOP=20000-20049 WAIT=${HY2_HOP_WAIT:-75}
failed=0 pids=''
pass() { echo "PASS $*"; }
fail() { echo "FAIL $*"; failed=1; }
nft list table inet lanekeep_dns_gate >/dev/null 2>&1 && { echo 'FAIL LaneKeep gate table present; run on an idle test machine'; exit 1; }
for t in lanekeep_hy2_test lanekeep_hy2_gate; do nft list table inet $t >/dev/null 2>&1 && { echo "FAIL table $t already exists"; exit 1; }; done
T=$(mktemp -d /tmp/lanekeep-hy2-runtime.XXXXXX)
cleanup() {
  for p in $pids; do kill "$p" 2>/dev/null; done; for p in $pids; do wait "$p" 2>/dev/null; done
  nft delete table inet lanekeep_hy2_test 2>/dev/null; nft delete table inet lanekeep_hy2_gate 2>/dev/null; rm -rf "$T"
}
trap cleanup EXIT INT TERM

# Certificate and an independently computed pin: SHA-256 of the DER bytes decoded from the PEM.
xray tls cert -domain=hy2.test -json >"$T/cert.json" || { echo 'FAIL certificate'; exit 1; }
cat >"$T/cert.uc" <<'EOF'
import * as fs from 'fs';
let d=ARGV[0],c=json(fs.readfile(d+'/cert.json'));
fs.writefile(d+'/cert.pem',join('\n',c.certificate)+'\n');fs.writefile(d+'/key.pem',join('\n',c.key)+'\n');
fs.writefile(d+'/cert.der',b64dec(join('',filter(c.certificate,l=>!match(l,/^-----/)))));
EOF
ucode "$T/cert.uc" "$T" && chmod 600 "$T/key.pem" && rm -f "$T/cert.json" || { echo 'FAIL certificate files'; exit 1; }
PIN=$(sha256sum "$T/cert.der" | cut -d' ' -f1)
case "$PIN" in 0*) WRONG=1${PIN#?} ;; *) WRONG=0${PIN#?} ;; esac
COLONS=$(echo "$PIN" | tr a-f A-F | sed 's/../&:/g; s/:$//')

# Xray's freedom outbound blocks private targets for HY2 inbounds by default; allow only the stub.
cat >"$T/server.json" <<EOF
{"log":{"loglevel":"warning"},
 "inbounds":[{"tag":"hy2-in","listen":"127.0.0.1","port":$SERVER_PORT,"protocol":"hysteria","settings":{"version":2,"clients":[{"auth":"PASSWORD"}]},
  "streamSettings":{"network":"hysteria","security":"tls","tlsSettings":{"certificates":[{"certificateFile":"$T/cert.pem","keyFile":"$T/key.pem"}]},"hysteriaSettings":{"version":2}}}],
 "outbounds":[{"tag":"out","protocol":"freedom","settings":{"finalRules":[{"action":"allow","network":"tcp","ip":["127.0.0.1/32"],"port":"18080"}]}}]}
EOF
{ printf "import * as nodes from '%s';\n" "$NODES"; cat <<EOF
import * as fs from 'fs';
let r=nodes.parse_preview(ARGV[0])[0];
if(r.status!='ok'){print(sprintf('%J\n',r.error));exit(2);}
let o=nodes.render(r.node);o.tag='hy2-test';o.streamSettings.sockopt={mark:30241};
fs.writefile(ARGV[1],sprintf('%J\n',{log:{loglevel:'warning'},inbounds:[{tag:'in',listen:'127.0.0.1',port:$SOCKS,protocol:'socks',settings:{auth:'noauth',udp:false}}],outbounds:[o]}));
EOF
} >"$T/client.uc"

cat >"$T/test.nft" <<EOF
table inet lanekeep_hy2_test {
    set dports { type inet_service; flags dynamic; size 1024; }
    set sports { type inet_service; flags dynamic; size 1024; }
    counter marked {}
    counter unmarked {}
    chain watch {
        type filter hook output priority -200; policy accept;
        ip daddr 127.0.0.1 udp dport $HOP meta mark 0x7621 counter name marked add @dports { udp dport } add @sports { udp sport }
        ip daddr 127.0.0.1 udp dport $HOP meta mark != 0x7621 counter name unmarked
    }
    chain redirect_hops {
        type nat hook output priority -100; policy accept;
        ip daddr 127.0.0.1 udp dport $HOP redirect to :$SERVER_PORT
    }
}
EOF
sed 's/table inet lanekeep_dns_gate/table inet lanekeep_hy2_gate/' "$REPO/root/etc/lanekeep-proxy/dns-gate.nft" >"$T/gate.nft"
grep -q 'table inet lanekeep_hy2_gate' "$T/gate.nft" || { echo 'FAIL gate copy'; exit 1; }
nft -f "$T/test.nft" && nft -f "$T/gate.nft" || { echo 'FAIL nft tables'; exit 1; }

ucode "$HERE/latency-stub.uc" normal >/dev/null 2>&1 & pids="$pids $!"
xray run -c "$T/server.json" >"$T/server.log" 2>&1 & pids="$pids $!"
sleep 2
client=''
start_client() { # link
  [ -z "$client" ] || { kill "$client" 2>/dev/null; wait "$client" 2>/dev/null; }
  ucode "$T/client.uc" "$1" "$T/client.json" >"$T/client.err" || { cat "$T/client.err"; return 1; }
  xray run -c "$T/client.json" >"$T/client.log" 2>&1 & client=$!; pids="$pids $client"; sleep 2
}
request() { curl -s -o /dev/null -w '%{http_code}' --max-time "${1:-6}" --socks5-hostname 127.0.0.1:$SOCKS http://127.0.0.1:18080/generate_204; }
try() { n=0; while [ $n -lt 3 ]; do [ "$(request)" = 204 ] && return 0; n=$((n+1)); sleep 1; done; return 1; }
counter() { nft list counter inet lanekeep_hy2_test "$1" | sed -n 's/.*packets \([0-9]*\).*/\1/p'; }
gate_drops() { nft list chain inet lanekeep_hy2_gate check_data | sed -n 's/.*counter packets \([0-9]*\).*drop.*/\1/p'; }
elements() { nft -j list set inet lanekeep_hy2_test "$1" | ucode -l fs -e "let j=json(fs.stdin.read('all'));for(let o in j.nftables)if(o.set)print(length(o.set.elem||[]));"; }
lease() { nft "$1" element inet lanekeep_hy2_gate healthy_data "{ 0x7621${2:-} }"; }

LINK="hysteria2://PASSWORD@127.0.0.1:20000/?sni=hy2.test&mport=$HOP&pinSHA256=$COLONS#loopback"
start_client "$LINK" || { echo 'FAIL client config from share link'; exit 1; }
grep -q '"pinnedPeerCertSha256": *"'"$PIN"'"' "$T/client.json" && grep -q '"remotePorts": *"'"$HOP"'"' "$T/client.json" \
  && pass 'client outbound rendered from link (pin normalized, udphop set)' || fail 'rendered client outbound'
code=$(request 5)
[ "$code" != 204 ] && [ "$(gate_drops)" -gt 0 ] && [ "$(counter marked)" -gt 0 ] \
  && pass "gate closed without lease: request failed ($code), marked hop packets dropped" || fail "gate without lease: code=$code drops=$(gate_drops) marked=$(counter marked)"
lease add ' timeout 600s'
try && pass 'correct pin connects through hop ports with lease' || { fail 'correct pin with lease'; tail -5 "$T/client.log"; tail -5 "$T/server.log"; }
ok=0 bad=0 end=$(( $(date +%s) + WAIT ))
while [ "$(date +%s)" -lt "$end" ]; do [ "$(request)" = 204 ] && ok=$((ok+1)) || bad=$((bad+1)); sleep 3; done
[ "$bad" = 0 ] && [ "$ok" -gt 0 ] && pass "requests during ${WAIT}s of hopping: $ok ok, 0 failed" || fail "requests during hopping: $ok ok, $bad failed"
d=$(elements dports) s=$(elements sports)
[ "${d:-0}" -ge 2 ] && pass "remote hop ports seen: $d (within $HOP)" || fail "remote hop ports seen: ${d:-0}"
[ "${s:-0}" -ge 2 ] && pass "local sockets seen: $s (new socket per hop)" || fail "local sockets seen: ${s:-0}"
[ "$(counter unmarked)" = 0 ] && pass "all $(counter marked) packets to hop ports carried mark 0x7621" || fail "unmarked packets to hop ports: $(counter unmarked)"
lease delete; before=$(gate_drops); code=$(request 5)
[ "$code" != 204 ] && [ "$(gate_drops)" -gt "$before" ] && pass "lease removed: established tunnel blocked ($code)" || fail "after lease removal: code=$code"
lease add ' timeout 600s'
code=none; start_client "$(echo "$LINK" | sed "s/$COLONS/$WRONG/")" && code=$(request 6)
[ "$code" != 204 ] && [ "$code" != none ] && pass "wrong pin refused ($code)" || fail "wrong pin: $code"
grep -i 'pin\|certificate\|x509\|tls' "$T/client.log" | tail -1 | cut -c1-200
code=none; start_client "$(echo "$LINK" | sed "s/&pinSHA256=$COLONS//")" && code=$(request 6)
[ "$code" != 204 ] && [ "$code" != none ] && pass "no pin with self-signed certificate refused ($code)" || fail "no pin: $code"
grep -i 'pin\|certificate\|x509\|tls' "$T/client.log" | tail -1 | cut -c1-200
start_client "$(echo "$LINK" | sed 's/&pinSHA256/\&insecure=1\&pinSHA256/')" && try && pass 'insecure=1 with correct pin connects (validated by pin)' || fail 'insecure=1 with pin'
[ "$(counter unmarked)" = 0 ] || fail "unmarked packets to hop ports at end: $(counter unmarked)"
[ "$failed" = 0 ] && echo 'ALL PASS' || echo 'SOME CHECKS FAILED'
exit "$failed"
