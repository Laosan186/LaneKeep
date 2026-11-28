# Changelog

## Unreleased

Added

- Direct mode. Devices in it go out directly through the core's own direct inbound (port 12349), never through a proxy node, with no rules and no leak protection. Router DNS from these devices passes through the core and is forwarded unchanged to dnsmasq on loopback (a new `direct-router-dns` dns outbound on the existing short-idle level 53), because the core's UDP reply sockets for other modes' DNS sit on the LAN address port 53 and could otherwise take the query. Internal DNS / proxy ports on every router-local address (the WAN address included, port 53 on the LAN address excepted) are dropped in nft, and the inbound blocks them on the loopback and LAN addresses as well as unresolved FakeIP destinations. When the core stops, Direct devices lose access, router DNS included; LAN forwarding is still dropped.
- “Devices without a mode” on the Devices page decides where devices outside every mode go (every device without a fixed IP, unknown new devices and fixed-IP devices set to “Follow default”): Direct or Standard. A first install (no `/etc/lanekeep-state` and all three conffiles still the shipped defaults) writes Direct; upgrades and reinstalls keep the saved choice, and a configuration without one stays on Standard. Changing it takes the rules path and restarts the core.
- Fixed-IP devices can be set to “Follow default” or to any mode, including Standard and Direct. Only a specific choice is saved as a member, so upgraded Standard devices keep following the default as before.
- A beginner's guide to per-app proxying through dedicated entries ([中文](docs/per-app-proxy.md), [English](docs/per-app-proxy.en.md)).

Changed

- The internal port block range in the shared and dedicated-entry rules grows from 12345-12348 to 12345-12349. Apart from that and the added direct inbound, rules and nft dispatch lines, generated rules for Standard, Global, Enhanced and On-demand are unchanged; `tests/target/direct-diff.uc` checks this against the previous release.

Downgrade note: 0.2.1 rejects the `standard` and `direct` group sections and the `unassigned` section. Remove them from `/etc/config/lanekeep` before installing 0.2.1 again.

## 0.2.1 — 2026-11-21

Fixed

- The English Status page title reads “LaneKeep”, as the Chinese one does, instead of “Network”. Duplicate entries were removed from the English and Chinese string tables; no other text changes.
- The Nodes page shows the kill switch as Standby or Triggered instead of always “Unknown”. In 0.1.0 and 0.2.0 the `nodes` RPC did not return the gate snapshot; it now returns the same `gate` object (`state`, `fresh`, `lease_valid`) as the status RPC, read by one shared function. If the gate cannot be read, the page still loads and shows “Unknown”.

此版本的验收见 [v0.2.1 验收记录](docs/audit/v0.2.1/acceptance.md)。

## 0.2.0 — 2026-11-20

Added

- IP rules: one public IPv4 address or network per rule (`1.2.3.4`, `1.2.3.0/24`). Private, loopback, link-local, CGNAT, multicast, documentation and FakeIP ranges and the selected LAN subnet are rejected, and host bits must be zero. IP rules get their own Xray rows, cannot exit through a two-hop chain, and in On-demand mode proxied IPs get the same UDP 443 block row as proxied domains. They only match direct-IP connections whose domain cannot be identified. The status RPC reports `rule_types`; the Rules page offers the IP type only when the backend lists it.
- Target-machine checks in `tests/target/` for IP rule parsing, generator output, rules page sequence numbers and node latency, using synthetic data only.

Changed

- Rules, Details, Devices and History pages use cards, collapsible “!” tips, single-line notes, a sticky “Review changes” bar and step-by-step instructions for dedicated proxy ports. Chart axes show short times without a time-zone name.
- Node latency measurement v3: latency is the faster of two requests to `www.gstatic.com/generate_204` on an established tunnel, with the first request (handshake included) shown separately. Without a reused sample, a labelled first-request time is shown instead. The exit IP still comes from a separate `ipinfo.io` connection. The wait per test or chain step is now about 15 seconds; results recorded by 0.1.0 ask for a new test.

Downgrade note: the 0.1.0 generator rejects IP rules. Delete all IP rules and apply before installing 0.1.0 again.

此版本的验收见 [v0.2.0 验收记录](docs/audit/v0.2.0/acceptance.md)。

## 0.1.0 — 2026-11-16

Initial packaged release for OpenWrt 25.12, licensed under GPL-3.0-only.

- Four neutral routing modes: Standard, Global, Enhanced and On-demand; empty node, member and custom-rule stores.
- Explicit activation after selecting a default node. Installation and disabled-mode configuration do not intercept traffic or change DNS.
- Owned nftables and policy-routing lifecycle, DNS snapshot/restore, IPv4 LAN discovery and an IPv6 prerequisite check.
- Node, subscription, two-hop chain, device, rule, health and traffic views. Experimental protocol combinations remain marked as experimental.
- Panel-owned styling and versioned JavaScript/CSS module paths, including upgrades with an unchanged LuCI version.
- Chinese and English documentation, synthetic-data preview and screenshots, privacy and release evidence.

此版本的范围与限制见 [README](README.md) 和 [防泄漏说明](docs/leak-protection.md)。测试证据见 [验收记录](docs/audit/acceptance.md)。
