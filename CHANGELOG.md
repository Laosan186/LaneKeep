# Changelog

## Unreleased

Fixed

- Global, Enhanced and On-demand devices are now dropped, never handled by Standard or Direct mode, whenever their own transparent inbound has no socket: while the core starts or stops, after it fails, or whenever else it cannot take the packet. Each of their three capture chains drops the TCP/UDP its TPROXY rule could not deliver, so the packet no longer returns to the dispatch chain and reaches the chain for devices without a mode. Until now, with “Devices without a mode” on Standard, such packets went through the Standard inbound in that window and followed Standard's rules, its domestic direct rules included; with Direct, the Direct chain already dropped them. The Standard and Direct chains and the dispatch chain are unchanged. A package upgrade loads the new rules (it stops LaneKeep and starts it again when enabled); the stop at the start of the upgrade from 1.0.2 still runs under the old rules, so that one stop can still hand these devices to Standard. `tests/target/direct-diff.uc` accepts the three added drops, and `rules-check.sh` checks them.

## 1.0.2 — 2026-11-28

Added

- Direct mode. Devices in it go out directly through the core's own direct inbound (port 12349), never through a proxy node, with no rules and no leak protection. Router DNS from these devices passes through the core and is forwarded unchanged to dnsmasq on loopback (a new `direct-router-dns` dns outbound on the existing short-idle level 53), because the core's UDP reply sockets for other modes' DNS sit on the LAN address port 53 and could otherwise take the query. Internal DNS / proxy ports on every router-local address (the WAN address included, port 53 on the LAN address excepted) are dropped in nft, and the inbound blocks them on the loopback and LAN addresses as well as unresolved FakeIP destinations. When the core stops, Direct devices lose access, router DNS included; LAN forwarding is still dropped. While the core starts or stops, a mode's inbound may not listen yet (or any more) while the direct inbound does: members of the other modes that fall through to the Direct chain are dropped there, and Direct traffic the direct inbound cannot take is dropped instead of reaching a later chain. With “Devices without a mode” on Standard, Global, Enhanced and On-demand members can still be handled by Standard mode in that window, as in earlier versions.
- “Devices without a mode” on the Devices page decides where devices outside every mode go (every device without a fixed IP, unknown new devices and fixed-IP devices set to “Follow default”): Direct or Standard. A first install (no `/etc/lanekeep-state` and all three conffiles still the shipped defaults) writes Direct; upgrades and reinstalls keep the saved choice, and a configuration without one stays on Standard. Changing it takes the rules path and restarts the core.
- Fixed-IP devices can be set to “Follow default” or to any mode, including Standard and Direct. Only a specific choice is saved as a member, so upgraded Standard devices keep following the default as before.
- A beginner's guide to per-app proxying through dedicated entries ([中文](docs/per-app-proxy.md), [English](docs/per-app-proxy.en.md)).
- HY2 share links can carry port hopping and a certificate pin. Hop ports are accepted in the address (`host:443,20000-50000`) or as `mport`; they render as Xray's `finalmask` `udphop` (new local socket and random port every 30 s, as in the official client). `pinSHA256` renders as `pinnedPeerCertSha256`; with a pin Xray trusts only that certificate. `insecure=1` is now accepted only together with a valid pin. Both fields come from the imported link, can be entered when adding an HY2 node by hand, and can be changed or cleared in the edit form of an existing HY2 node. Nodes that use them need node store format 7; LaneKeep 0.2.1 and older cannot read such a store. Deleting or clearing those nodes returns the store to format 6 when it is saved, so do that before downgrading.
- The HY2 add and edit forms can also set the hop interval (5–3600 seconds, default 30) and the upload and download bandwidth in Mbps. Upload bandwidth turns on Brutal congestion control when the server also reports its receive rate (the smaller value is used); otherwise BBR stays, unlike the official client, which then uses Brutal with its own value. Download bandwidth is sent to the server as this client's receive rate. Share links do not carry these values, so for an imported node they are entered after import. They also need node store format 7.
- The connection monitor counts sockets to any hop port of a node as node traffic. A chain is rejected when its HY2 entry hops over the exit's port on the same server.

`capabilities.json` is unchanged, so existing trial confirmations stay valid. Existing HY2 nodes keep the same generated configuration and identity.

Changed

- Global and Enhanced block UDP to private addresses (`geoip:private`, CGNAT included) ahead of the private direct rules. Xray keeps one transparent UDP session per source socket, so a socket whose first packet went to a private address used to send its later packets, including STUN, from the direct exit.
- Enhanced sends all UDP after the user rules through its proxy node instead of sending UDP to domestic destinations directly. Domestic UDP services (calls, games) now use the proxy exit. Domestic TCP is still direct, so Enhanced still exposes the direct address to domestic destinations, including TURN over TCP/TLS.
- A fail-closed guard table (`lanekeep_guard`) is kept for as long as LaneKeep is enabled and is loaded by a new `lanekeep-guard` init script before the network starts. It drops forwarded LAN IPv4, forwarded LAN IPv6 and uncaptured LAN DNS. A boot-time check that refuses, or a start that fails at boot, now leaves the enabled flag set and the LAN blocked instead of forwarding it directly; `stop` and later package upgrades keep the table, and only disable or uninstall removes it (for upgrades this follows from the new pre-upgrade script; the table was checked after a later upgrade on a test build of the hardening, and after the upgrade from 0.2.1-r1 on the 1.0.2 package; no upgrade was probed while it ran). The upgrade from 0.2.1 or earlier still runs the old pre-upgrade script, so that one upgrade has a direct window.
- The watchdog reads the LAN device's `disable_ipv6` every round and keeps the gate closed while it is not `1`. The Status page warns when LAN IPv6 is on and when LaneKeep is enabled but not running.
- The rules page labels only each mode's fallback rule as the final default.
- The internal port block range in the shared and dedicated-entry rules grows from 12345-12348 to 12345-12349. Apart from that and the added direct inbound, rules and nft dispatch lines, Direct mode leaves the generated rules for Standard, Global, Enhanced and On-demand unchanged; `tests/target/direct-diff.uc` checks this against the leak-hardened tree without Direct mode.

Downgrade note: 0.2.1 rejects the `standard` and `direct` group sections and the `unassigned` section. Remove them from `/etc/config/lanekeep` before installing 0.2.1 again.

此版本的验收见 [v1.0.2 验收记录](docs/audit/v1.0.2/acceptance.md)。

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
