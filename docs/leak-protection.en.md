# Leak-protection mechanisms and limits

[中文](leak-protection.md) · [README](../README.en.md)

This describes the current source mechanisms, including custom IP rules added after v0.1.0, not a guarantee across all clients, apps or networks. First installation is disabled. Traffic protection starts only after explicit activation.

## Fixed-rule matrix

| Rule | Standard | Global | Enhanced | On-demand |
|---|---|---|---|---|
| TCP/UDP 53 to shared DNS | Yes | Yes | Yes | Yes |
| Block destination port 853 | Yes | Yes | Yes | Yes |
| Block `geosite:category-doh` | Yes | Yes | Yes | Yes |
| Protect internal DNS / transparent ports | Yes | Yes | Yes | Yes |
| Block unresolved FakeIP destinations | Yes | Yes | Yes | Yes |
| UDP 443 | Broad block | Broad block | Broad block | Selected service categories and custom proxied domains and IPs |
| Dedicated iCloud Private Relay category block | No | Yes | No | No |

The matrix follows `root/etc/lanekeep-proxy/template.json` and the generator. FakeIP guards include `198.18.0.0/15` and `2001:2::/48`, but interception is IPv4-only. An IPv6 range in JSON does not establish IPv6 protection. Valid FakeDNS mappings restored to domain names continue through domain routing.

Fixed protection precedes user rules. Some private-name/address exceptions also precede custom insertion points. On-demand IP categories do not imply a blanket UDP 443 block.

## Custom IP rules

The “IP / network” rule type accepts one public IPv4 address or network, such as `1.2.3.4` or `1.2.3.0/24`. `/32` is stored as a single address, and host bits must be zero. Any overlap with these ranges is rejected: `0.0.0.0/8`, private networks, `100.64.0.0/10`, loopback, link-local, `192.0.0.0/24`, documentation ranges, the FakeIP block `198.18.0.0/15`, multicast and reserved space, and the selected LAN subnet read from OpenWrt. IP rules therefore never cover the LAN or the FakeIP pool, and fixed protection still precedes custom rules.

- Xray ANDs `domain` and `ip` within one rule, so IP rules always get their own rows; adjacent IP rules with the same exit share a row.
- Routing uses `domainStrategy: AsIs` with FakeDNS and TLS/HTTP/QUIC sniffing. Connections with an identifiable domain are matched by domain, so **IP rules only match direct-IP traffic whose domain cannot be identified**, such as some apps, games or specific servers. Opening a website in a browser does not exercise an IP rule; use a domain rule for websites. This feature leaves `domainStrategy` unchanged to keep the existing protection.
- Literal IP traffic has no FakeIP guard, so an IP rule cannot exit through a two-hop chain, neither as an explicit node nor through “this mode's node” when that node is a chain.
- In On-demand mode, IP rules that exit via proxy or a specific node first get a UDP 443 block row for the same targets, like custom proxied domains.
- Before moving the selected LAN to a subnet that overlaps saved IP rules, edit or delete those rules in the panel and apply. If the subnet was changed first, configuration generation fails, the running configuration stays as it was, and the panel cannot apply the rule deletion either; move the LAN back, delete the rules and apply, then change the subnet.
- The 0.1.0 generator does not know IP rules. Before downgrading to 0.1.0, delete all IP rules in the panel and apply.

## DNS

After activation, nft captures IPv4 TCP/UDP from the selected LAN. Port 53 is handled before management-port exceptions. Xray uses FakeDNS and protected real resolution, with no system-hosts or ordinary DNS fallback on failure.

Protected real DNS uses Cloudflare DoH through the default node: primary `1.1.1.1`, backup `1.0.0.1`. For the health-check domain `one.one.one.one`, query timeouts are 800 ms and 900 ms respectively and cache is disabled. A mode's independent data node does not change this shared DNS path.

Standard's domestic domain category retains system resolution. Activation snapshots the affected dnsmasq fields and redirects its upstream to the package's loopback DNS service on 5053, using Ali DoH. This helper is a separate Xray instance with an IPv4 encrypted upstream; no third-party DNS management service is needed. Other Standard public domains use protected resolution wrappers while their data exit still follows routing. Protected DNS does not imply that all data is proxied.

Factory FakeIP exceptions are empty. `domain:` and `full:` exceptions select real resolution without independently changing the device's data exit. Resolver country alone is not a reliable leak criterion.

## WebRTC, UDP and IPv6

Transparent TCP/UDP and routing jointly determine the exit. Proxied WebRTC destinations can use the proxy exit; direct destinations may see the direct public address. Unknown DoH, explicit direct exceptions and app behavior prevent an absolute guarantee.

The package does not disable or reconfigure IPv6. Administrators must remove LAN IPv6 addressing, RA / DHCPv6 and explicitly disable IPv6 on the selected device before activation. Disabling RA alone is insufficient. Preflight refuses an incompatible LAN. Uninstall does not undo manually applied IPv6 settings.

## Kill switch

Protected data uses mark `0x7621`; DNS probes use a separate mark. The nft `healthy_data` set carries an 8-second lease. Each bounded DNS round is followed by a 2-second sleep. Probe and lock time beyond 3 seconds fails the round. Two consecutive successes open/renew the gate; failure clears the lease. A stopped watchdog cannot keep an old lease alive indefinitely.

Detection has a window, not zero latency, and checks one DNS path rather than every destination. It follows the default node and constrains other selected proxy nodes too. It does not automatically select another node or fall back to direct. Direct services still depend on the core and DNS and are not guaranteed during a fault.

An active default-node transaction saves the previous configuration and waits up to about 60 seconds for a fresh gate, core identity and rules. Failure attempts to restore and revalidate the old state. Failed recovery stays blocked. Saving settings while disabled does not start this network transaction.

## Logs and stored data

Generated configurations set `access: none`, `error: none`, `loglevel: none`, `dnsLog: false`; the local DNS instance does too. System service-start and fault messages may still exist. This is not a claim that the entire router has no logs.

Monitoring stores aggregate numbers, categories and bounded fault/operation summaries. Per-connection destinations are transient within a collection call, not browsing history. Node, subscription and rollback files contain credentials and need restricted permissions. No browsing logs does not mean no sensitive configuration.

## Dedicated entries

LAN SOCKS5 ports 10811–10860 are available to Global, Enhanced and On-demand and restricted by source membership. They use their selected exit and own private-address, internal-port and 53/853 guards. They do not inherit all mode rules or ad blocking. TCP chains carry TCP only unless supported UDP is explicitly enabled.

## Check it yourself

1. Install in a separate test environment and verify unchanged DNS, nft and policy routes while disabled.
2. Configure nodes, modes and the IPv6 prerequisites; explicitly enable and inspect Status and rule verification.
3. Test proxy and direct destinations, DNS, WebRTC and app-specific encrypted DNS separately, recording the applicable rules.
4. In the test environment, interrupt the default node and observe the detection window and recovery. One successful check does not prove every fault case.
5. Disable or uninstall and compare DNS, policy routes and owned nft tables with the baseline.

See the [acceptance record](audit/acceptance.md) and [documentation audit](audit/document-audit.md).
