#!/bin/sh
# First creation; candidate only. No DNS replies are written to ordinary files.
# A replacement probe must be an absolute executable path, take no arguments,
# and exec one foreground process. It must not fork/detach or log DNS output.
set -u
PATH=/usr/sbin:/usr/bin:/sbin:/bin
export PATH
umask 077

RUNDIR=/tmp/lanekeep-dns-gate
LOCK=$RUNDIR/watchdog.lock
GATELOCK=$RUNDIR/gate.lock
FIFO=$LOCK/probe.pipe
PROBE=${1:-/usr/libexec/lanekeep-xray/dns-gate-probe.sh}
[ "$#" -le 1 ] || exit 64
case "$PROBE" in /*) ;; *) exit 64 ;; esac
[ -f "$PROBE" ] && [ -x "$PROBE" ] || exit 66
[ "$(id -u)" -eq 0 ] || exit 77
# /tmp must really be RAM storage on the target; do not silently persist state.
awk '$2 == "/tmp" && $3 == "tmpfs" { ok=1 } END { exit !ok }' /proc/mounts || exit 78
if [ -e "$RUNDIR" ] || [ -L "$RUNDIR" ]; then
    [ -d "$RUNDIR" ] && [ ! -L "$RUNDIR" ] || exit 73
    [ "$(ls -nd "$RUNDIR" 2>/dev/null | awk '{print $3}')" = 0 ] || exit 73
else
    mkdir -m 700 "$RUNDIR" || exit 73
fi
chmod 700 "$RUNDIR" || exit 73
# Never steal an existing lock. SIGKILL leaves a safe stale lock for inspection.
mkdir -m 700 "$LOCK" 2>/dev/null || exit 75

probe_pid=; probe_start=; parser_pid=; parser_start=; timer_pid=; timer_start=
probe_elapsed_ms=; probe_finished_cs=0
rounds=0; successes=0; failures=0; streak=0; state=CLOSED; generation=; gate_owned=0; last_success_cs=0; gate_token=

proc_start() {
    case "${1:-}" in ''|*[!0-9]*) return 1 ;; esac
    [ -r "/proc/$1/stat" ] || return 1
    IFS= read -r proc_line < "/proc/$1/stat" || return 1
    # Fields after the final ') ' start at field 3; starttime is field 22.
    proc_fields=${proc_line##*) }
    set -- $proc_fields
    [ "$#" -ge 20 ] || return 1
    shift 19
    printf '%s\n' "$1"
}

signal_exact() {
    signal=$1; target_pid=$2; expected_start=$3
    [ -n "$target_pid" ] && [ -n "$expected_start" ] || return 0
    current_start=$(proc_start "$target_pid") || return 0
    [ "$current_start" = "$expected_start" ] || return 0
    kill "-$signal" "$target_pid" 2>/dev/null || :
}

acquire_gate() {
    attempt=0
    until mkdir -m 700 "$GATELOCK" 2>/dev/null; do
        attempt=$((attempt + 1))
        [ "$attempt" -lt 3 ] || return 1
        sleep 1 || return 1
    done
    gate_owned=1
    printf '%s\n' "$gate_token" > "$GATELOCK/owner"
}

release_gate() {
    [ "$gate_owned" -eq 1 ] || return 0
    # Disarm before unlinking, so EXIT/signal cleanup cannot release a new lock.
    gate_owned=0
    IFS= read -r observed_owner < "$GATELOCK/owner" || return 1
    [ "$observed_owner" = "$gate_token" ] || return 1
    rm -f "$GATELOCK/owner" || return 1
    rmdir "$GATELOCK" || return 1
}

close_gate() {
    acquire_gate || return 1
    close_rc=0
    nft flush set inet lanekeep_dns_gate healthy_data >/dev/null 2>&1 || close_rc=$?
    release_gate || return 1
    return "$close_rc"
}

renew_gate() {
    [ "$gate_owned" -eq 1 ] || return 1
    nft -f - >/dev/null 2>&1 <<'NFT'
flush set inet lanekeep_dns_gate healthy_data
add element inet lanekeep_dns_gate healthy_data { 0x7621 timeout 8s }
NFT
}

read_generation() {
    [ -f "$RUNDIR/epoch" ] && [ ! -L "$RUNDIR/epoch" ] || return 1
    IFS= read -r epoch < "$RUNDIR/epoch" || return 1
    [ "${#epoch}" -eq 36 ] || return 1
    case "$epoch" in *[!0-9a-f-]*) return 1 ;; esac
    printf '%s\n' "$epoch"
}

uptime_cs() {
    read -r stamp ignored < /proc/uptime || return 1
    whole=${stamp%.*}; fraction=${stamp#*.}
    case "$whole" in ''|*[!0-9]*) return 1 ;; esac
    case "$fraction" in [0-9][0-9]) ;; *) return 1 ;; esac
    printf '%s\n' "$((whole * 100 + 1$fraction - 100))"
}

apply_result() {
    passed=$1; probed_generation=$2; started_cs=$3
    acquire_gate || return 1
    observed_generation=$(read_generation) || { release_gate; return 1; }
    now_cs=$(uptime_cs) || { release_gate; return 1; }
    elapsed_cs=$((now_cs - started_cs))
    if [ "$generation" != "$observed_generation" ]; then
        generation=$observed_generation
        streak=0
        last_success_cs=0
    fi
    # Also handle suspension between rounds, where the new probe is fresh but
    # the old lease and old consecutive-success streak have already expired.
    if [ "$last_success_cs" -gt 0 ] && [ "$((now_cs - last_success_cs))" -ge 800 ]; then
        streak=0
    fi
    # Includes time spent suspended or waiting for the gate lock.
    if [ "$probed_generation" != "$observed_generation" ] || \
       [ "$elapsed_cs" -lt 0 ] || [ "$elapsed_cs" -gt 300 ]; then
        passed=0
    fi
    if [ "$passed" -eq 1 ]; then
        successes=$((successes + 1))
        last_success_cs=$now_cs
        streak=$((streak + 1))
        if [ "$streak" -ge 2 ]; then
            # Epoch comparison and this renewal share the wrapper lock.
            renew_gate || { release_gate; return 1; }
            state=OPEN
            streak=2
        else
            nft flush set inet lanekeep_dns_gate healthy_data >/dev/null 2>&1 || { release_gate; return 1; }
            state=WARMING
        fi
    else
        failures=$((failures + 1))
        streak=0
        last_success_cs=0
        nft flush set inet lanekeep_dns_gate healthy_data >/dev/null 2>&1 || { release_gate; return 1; }
        state=CLOSED
    fi
    release_gate
}

write_state() {
    read -r uptime_seconds ignored < /proc/uptime || return 1
    uptime_seconds=${uptime_seconds%%.*}
    # No hostnames, answers, node addresses, or history in this RAM-only file.
    [ ! -L "$RUNDIR/status" ] && [ ! -L "$RUNDIR/status.next" ] || return 1
    printf 'state=%s\nuptime_seconds=%s\nrounds=%s\nsuccesses=%s\nfailures=%s\nstreak=%s\n' \
        "$state" "$uptime_seconds" "$rounds" "$successes" "$failures" "$streak" \
        > "$RUNDIR/status.next" || return 1
    printf 'probe_elapsed_ms=%s\nprobe_finished_cs=%s\n' "$probe_elapsed_ms" "$probe_finished_cs" >> "$RUNDIR/status.next" || return 1
    mv -f "$RUNDIR/status.next" "$RUNDIR/status"
}

stop_round() {
    signal_exact TERM "$timer_pid" "$timer_start"
    signal_exact KILL "$probe_pid" "$probe_start"
    signal_exact KILL "$parser_pid" "$parser_start"
    [ -z "$timer_pid" ] || wait "$timer_pid" 2>/dev/null || :
    [ -z "$probe_pid" ] || wait "$probe_pid" 2>/dev/null || :
    [ -z "$parser_pid" ] || wait "$parser_pid" 2>/dev/null || :
    probe_pid=; probe_start=; parser_pid=; parser_start=; timer_pid=; timer_start=
}

cleanup() {
    trap - 0 HUP INT TERM
    stop_round
    release_gate || :
    if close_gate; then state=CLOSED; else state=GATE_UPDATE_FAILED; fi
    streak=0
    write_state || :
    # Only this process's fixed, ephemeral FIFO and owner file are removed.
    [ ! -p "$FIFO" ] || rm -f "$FIFO"
    [ ! -f "$LOCK/owner" ] || rm -f "$LOCK/owner"
    rmdir "$LOCK" 2>/dev/null || :
}
trap cleanup 0
trap 'exit 0' HUP INT TERM
own_start=$(proc_start "$$") || exit 70
gate_token="$$:$own_start"
printf '%s %s\n' "$$" "$own_start" > "$LOCK/owner" || exit 73
mkfifo -m 600 "$FIFO" || exit 73
close_gate || exit 70
write_state || exit 73

timer_worker() {
    trap - 0 HUP INT TERM
    sleeper_pid=; sleeper_start=
    trap 'signal_exact KILL "$sleeper_pid" "$sleeper_start"; exit 0' HUP INT TERM
    sleep 3 &
    sleeper_pid=$!
    sleeper_start=$(proc_start "$sleeper_pid") || {
        signal_exact KILL "$probe_pid" "$probe_start"
        signal_exact KILL "$parser_pid" "$parser_start"
        exit 1
    }
    wait "$sleeper_pid" 2>/dev/null || {
        signal_exact KILL "$probe_pid" "$probe_start"
        signal_exact KILL "$parser_pid" "$parser_start"
        exit 1
    }
    signal_exact KILL "$probe_pid" "$probe_start"
    signal_exact KILL "$parser_pid" "$parser_start"
}

run_round() {
    # The FIFO carries bytes only in the kernel; it is not an output/history file.
    # Strictly require this fixed question plus a public A and global-unicast AAAA.
    awk '
    function valid4(ip, a, n, i) {
        n=split(ip,a,/[.]/); if(n!=4) return 0;
        for(i=1;i<=4;i++) if(a[i]!~/^[0-9]+$/ || a[i]>255) return 0;
        if(a[1]==0 || a[1]==10 || a[1]==127 || a[1]>=224) return 0;
        if(a[1]==100 && a[2]>=64 && a[2]<=127) return 0;
        if(a[1]==169 && a[2]==254) return 0;
        if(a[1]==172 && a[2]>=16 && a[2]<=31) return 0;
        if(a[1]==192 && (a[2]==168 || (a[2]==0 && (a[3]==0 || a[3]==2)))) return 0;
        if(a[1]==198 && (a[2]==18 || a[2]==19 || (a[2]==51 && a[3]==100))) return 0;
        if(a[1]==203 && a[2]==0 && a[3]==113) return 0;
        return 1;
    }
    function valid6(ip, a, n, i, t) {
        if(ip!~/^[23][0-9a-f:]*$/ || ip!~/:/ || length(ip)>39) return 0;
        if(ip~/^2001:(db8|2):/) return 0;
        t=ip; if(gsub(/::/,"X",t)>1) return 0;
        n=split(ip,a,":");
        for(i=1;i<=n;i++) if(length(a[i])>4) return 0;
        if(ip~/::/) return n<=8;
        return n==8;
    }
    /^\*|^;/ { bad=1 }
    $1=="Name:" { q=tolower($2); sub(/[.]$/,"",q); matched=(q=="one.one.one.one"); next }
    $1=="Address:" && matched {
        ip=tolower($2);
        if(valid4(ip)) seen4=1;
        else if(valid6(ip)) seen6=1;
        else bad=1;
        matched=0;
    }
    END { exit !(seen4 && !bad) }
    ' < "$FIFO" >/dev/null 2>&1 &
    parser_pid=$!
    parser_start=$(proc_start "$parser_pid") || { stop_round; return 1; }
    "$PROBE" > "$FIFO" 2>/dev/null &
    probe_pid=$!
    probe_start=$(proc_start "$probe_pid") || { stop_round; return 1; }
    timer_worker >/dev/null 2>&1 &
    timer_pid=$!
    timer_start=$(proc_start "$timer_pid") || { stop_round; return 1; }
    probe_rc=0; parser_rc=0
    wait "$probe_pid" 2>/dev/null || probe_rc=$?
    wait "$parser_pid" 2>/dev/null || parser_rc=$?
    stop_round
    [ "$probe_rc" -eq 0 ] && [ "$parser_rc" -eq 0 ]
}

while :; do
    rounds=$((rounds + 1))
    round_generation=$(read_generation) || exit 70
    round_started=$(uptime_cs) || exit 70
    if run_round; then
        round_passed=1
    else
        round_passed=0
    fi
    probe_finished_cs=$(uptime_cs) || exit 70
    probe_elapsed_ms=$(((probe_finished_cs - round_started) * 10))
    apply_result "$round_passed" "$round_generation" "$round_started" || exit 70
    # Optional numeric probe ring. Failure cannot change the gate decision.
    if [ ! -L "$RUNDIR/probe-history" ]; then
        printf '%-127s\n' "$round_started $probe_finished_cs $rounds $passed $state $generation" |
            dd of="$RUNDIR/probe-history" bs=128 seek=$((rounds % 2048)) count=1 conv=notrunc >/dev/null 2>&1 || :
    fi
    write_state || exit 73
    sleep 2 || exit 70
done
