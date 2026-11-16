#!/bin/sh
# First creation. Use as the actual procd command, including every respawn.
set -eu
PATH=/usr/sbin:/usr/bin:/sbin:/bin
export PATH XRAY_LOCATION_ASSET=/usr/share/v2ray
[ "$#" -eq 0 ] || exit 64
[ "$(id -u)" -eq 0 ] || exit 77
RUNDIR=/tmp/lanekeep-dns-gate
GATELOCK=$RUNDIR/gate.lock
awk '$2 == "/tmp" && $3 == "tmpfs" { ok=1 } END { exit !ok }' /proc/mounts || exit 78
if [ -e "$RUNDIR" ] || [ -L "$RUNDIR" ]; then
    [ -d "$RUNDIR" ] && [ ! -L "$RUNDIR" ] || exit 73
    [ "$(ls -nd "$RUNDIR" 2>/dev/null | awk '{print $3}')" = 0 ] || exit 73
else
    mkdir -m 700 "$RUNDIR" || exit 73
fi
chmod 700 "$RUNDIR" || exit 73
umask 077
IFS= read -r proc_line < "/proc/$$/stat"
proc_fields=${proc_line##*) }
set -- $proc_fields
[ "$#" -ge 20 ] || exit 70
shift 19
gate_token="$$:$1"
gate_owned=0
attempt=0
until mkdir -m 700 "$GATELOCK" 2>/dev/null; do
    attempt=$((attempt + 1))
    [ "$attempt" -lt 3 ] || exit 75
    sleep 1
done
gate_owned=1
release_gate() {
    [ "$gate_owned" -eq 1 ] || return 0
    # Disarm before unlinking, so a signal cannot release a later owner's lock.
    gate_owned=0
    IFS= read -r observed_owner < "$GATELOCK/owner" || return 1
    [ "$observed_owner" = "$gate_token" ] || return 1
    rm -f "$GATELOCK/owner"
    rmdir "$GATELOCK"
}
trap release_gate 0
trap 'exit 0' HUP INT TERM
printf '%s\n' "$gate_token" > "$GATELOCK/owner"
[ ! -L "$RUNDIR/epoch" ] && [ ! -L "$RUNDIR/epoch.next" ] || exit 73
# One lock serializes epoch change + close against watchdog compare + renewal.
IFS= read -r epoch < /proc/sys/kernel/random/uuid
printf '%s\n' "$epoch" > "$RUNDIR/epoch.next"
mv -f "$RUNDIR/epoch.next" "$RUNDIR/epoch"
if ! nft flush set inet lanekeep_dns_gate healthy_data >/dev/null 2>&1; then
    printf '%s\n' 'DNS_GATE_START_REFUSED' >&2
    exit 70
fi
release_gate
trap - 0 HUP INT TERM
# RAM-only startup attempts, including procd respawns; no sensitive fields.
# Observability errors must not prevent the already approved core from starting.
telemetry_start() {
    for name in telemetry-launches telemetry-launches.next telemetry-launch-ring; do
        [ ! -L "$RUNDIR/$name" ] || return 1
    done
    read -r observed_uptime ignored < /proc/uptime || return 1
    count=0; partial=1
    if [ -f "$RUNDIR/telemetry-launches" ]; then
        read -r count old_time partial < "$RUNDIR/telemetry-launches" || return 1
    elif [ "${observed_uptime%%.*}" -lt 120 ]; then partial=0; fi
    case "$count:$partial" in *[!0-9:]*|:*) return 1 ;; esac
    [ "$count" -lt 100000000 ] || return 1
    count=$((count + 1))
    printf '%-63s\n' "$count $observed_uptime $partial" | dd of="$RUNDIR/telemetry-launch-ring" bs=64 seek=$((count % 128)) count=1 conv=notrunc >/dev/null 2>&1 || return 1
    printf '%s %s %s\n' "$count" "$observed_uptime" "$partial" > "$RUNDIR/telemetry-launches.next" || return 1
    mv -f "$RUNDIR/telemetry-launches.next" "$RUNDIR/telemetry-launches"
}
telemetry_start >/dev/null 2>&1 || :
# Use only the generated zero-log forwarding configuration.
exec /usr/bin/xray run -config /etc/lanekeep-proxy/config.json
