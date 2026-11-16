#!/bin/sh
# First creation. One process, fixed public sample, local DNS listener only.
# The watchdog owns the three-second outer deadline and validates both families.
set -eu
PATH=/usr/sbin:/usr/bin:/sbin:/bin
export PATH
[ "$#" -eq 0 ] || exit 64
exec /bin/busybox nslookup -port=1053 -timeout=2 -retry=1 \
    -type=A one.one.one.one 127.0.0.1
