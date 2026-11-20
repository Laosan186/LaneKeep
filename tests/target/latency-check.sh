#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-only
# Node latency v3 checks for an isolated OpenWrt test machine with xray installed.
# A temporary local xray SOCKS inbound redirects every request to latency-stub.uc on 127.0.0.1;
# nothing leaves the machine. Usage: latency-check.sh REPO
set -u
REPO=$(cd "${1:?usage: latency-check.sh REPO}" && pwd)
HERE=$(cd "$(dirname "$0")" && pwd)
CODE=$REPO/root/usr/libexec/lanekeep-panel
PORT=23456 failed=0
mkdir -p /tmp/lanekeep-panel && chmod 700 /tmp/lanekeep-panel
config() { printf '%s' '{"log":{"loglevel":"none"},"inbounds":[{"tag":"test-in","listen":"127.0.0.1","port":'"$PORT"',"protocol":"socks","settings":{"auth":"noauth","udp":false}}],"outbounds":[{"tag":"test","protocol":"freedom","settings":{"redirect":"127.0.0.1:18080"}}]}' >"$1/test-config.json"; }
check() { # mode runner
  ucode "$HERE/latency-stub.uc" "$1" >/dev/null 2>&1 &
  stub=$!; sleep 1
  work=/tmp/lanekeep-panel/$(cat /proc/sys/kernel/random/uuid); mkdir -m 700 "$work"; config "$work"
  [ "$2" = chain-test ] && printf 'lanekeep-chain-test-v1\n' >"$work/.owner"
  start=$(date +%s); sh "$CODE/$2" "$work" "$PORT" >"/tmp/lanekeep-latency-$1.json"; took=$(( $(date +%s) - start ))
  kill "$stub" 2>/dev/null; wait "$stub" 2>/dev/null
  if ucode "$HERE/latency-expect.uc" "/tmp/lanekeep-latency-$1.json" "$1" "$took"; then echo "PASS $2 $1 (${took}s)"; else echo "FAIL $2 $1 (${took}s)"; failed=1; fi
  if [ "$2" = chain-test ]; then [ -e "$work" ] && { echo "FAIL chain-test left $work"; failed=1; } || echo 'PASS chain-test removed its work directory'; fi
  rm -rf "$work" "/tmp/lanekeep-latency-$1.json"
}
for mode in normal noka bad204 stall silentclose slowwarm pingstall; do check "$mode" node-test; done
check normal chain-test
[ "$failed" = 0 ] && echo 'ALL PASS' || echo 'SOME CHECKS FAILED'
exit "$failed"
