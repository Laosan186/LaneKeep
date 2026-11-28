// SPDX-License-Identifier: GPL-3.0-only
// Fail-closed LAN guard. The lifecycle keeps this table for as long as LaneKeep is
// enabled, and the lanekeep-guard init script reloads the saved copy before the
// network comes up. It blocks what would otherwise bypass the transparent capture:
//   - IPv4 forwarded from the LAN subnet (startup window, failed start, stopped runtime);
//   - every IPv6 packet forwarded from the LAN device (the capture is IPv4-only);
//   - LAN DNS sent to the router itself unless the capture marked it.
// Captured traffic is delivered locally with mark 0x7610 and is not affected.
import * as lan from './network.uc';
let text = "table inet lanekeep_guard {}\n" +
    "delete table inet lanekeep_guard\n" +
    "table inet lanekeep_guard {\n" +
    "    comment \"lanekeep-owned-v1\"\n" +
    "    counter guard_forward4 {}\n" +
    "    counter guard_forward6 {}\n" +
    "    counter guard_dns {}\n" +
    "    chain forward {\n" +
    "        type filter hook forward priority -2; policy accept;\n" +
    "        iifname != \"__LAN_DEVICE__\" return\n" +
    "        meta nfproto ipv6 counter name guard_forward6 drop\n" +
    "        ip saddr __LAN_SUBNET__ counter name guard_forward4 drop\n" +
    "    }\n" +
    "    chain input {\n" +
    "        type filter hook input priority -2; policy accept;\n" +
    "        iifname != \"__LAN_DEVICE__\" return\n" +
    "        meta nfproto ipv6 meta l4proto { tcp, udp } th dport 53 counter name guard_dns drop\n" +
    "        ip saddr __LAN_SUBNET__ meta l4proto { tcp, udp } th dport 53 meta mark != 0x7610 counter name guard_dns drop\n" +
    "    }\n" +
    "}\n";
print(lan.expand(text));
