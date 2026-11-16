# Changelog

## 0.1.0 — 2026-11-16

Initial packaged release for OpenWrt 25.12, licensed under GPL-3.0-only.

- Four neutral routing modes: Standard, Global, Enhanced and On-demand; empty node, member and custom-rule stores.
- Explicit activation after selecting a default node. Installation and disabled-mode configuration do not intercept traffic or change DNS.
- Owned nftables and policy-routing lifecycle, DNS snapshot/restore, IPv4 LAN discovery and an IPv6 prerequisite check.
- Node, subscription, two-hop chain, device, rule, health and traffic views. Experimental protocol combinations remain marked as experimental.
- Panel-owned styling and versioned JavaScript/CSS module paths, including upgrades with an unchanged LuCI version.
- Chinese and English documentation, synthetic-data preview and screenshots, privacy and release evidence.

此版本的范围与限制见 [README](README.md) 和 [防泄漏说明](docs/leak-protection.md)。测试证据见 [验收记录](docs/audit/acceptance.md)。
