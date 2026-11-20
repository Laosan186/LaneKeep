# Advanced notes

[中文](notes.md) · [README](../README.en.md)

## Nodes and chains

Nodes, subscription sources and chains are referenced by stable IDs. Names are display data; renaming does not change references. Device names, hostnames, node names and subscription names remain unchanged. Terminology mapping applies only to fixed fields.

Both hops must refer to imported node records. A subscription source is not a node. Chains cannot be nested or selected as the global default, but rules and modes can select them. Records still in use cannot be deleted.

Some protocol combinations are experimental. Parsing an import or generating a valid Xray configuration does not prove connectivity. Trial acknowledgements and verification records are configuration-bound; changing connection parameters invalidates previous evidence.

## Node tests

Tests run only when you click. A temporary Xray process opens a SOCKS inbound on the router's `127.0.0.1` and sends requests through the selected node. The node resolves the target names; there is no direct path, and the running configuration is not touched.

- **Latency**: requests `http://www.gstatic.com/generate_204` through the node. The first request includes the node handshake and is shown as “first connection”; two more requests on the same connection follow, and the faster one is the latency.
- **Fallback**: one reused sample is enough. If the first request succeeds but no reused sample is obtained (the server closes the connection or the reused request fails), latency uses the first request time; if the 204 probe fails on its first request, latency uses the time of the exit lookup request below. Both fallbacks are labelled “first request, handshake included”.
- **Exit**: a separate connection requests `http://ipinfo.io/json` for the exit IP and country; it is not part of the latency. Both third-party services see the node's exit address.
- Latency and exit lookup each have a 6-second deadline; a whole test takes at most about 15 seconds. Chains test the entry hop first, then the whole chain, with the same limits per step. Results recorded by 0.1.0 (measurement version 2) ask for a new test.

## Capacity and telemetry

The panel currently allows 21 node records, including chains. The legacy collector has a 96-metric limit. Deleted IDs can remain in history, so historical usage is checked before accepting a change. Internal capability-model limits are not the panel's effective limit.

Chain traffic is not collected by the legacy telemetry model. Missing counters do not mean zero traffic or a broken chain. Status, health probes and device traffic measure different things.

## Gate state and time

Health checks use the default node's DNS path. Failure closes the shared gate and can block other proxy nodes too. See [protection boundaries](leak-protection.en.md) for direct traffic, dedicated ports and unknown application DoH.

“Unknown” means sufficiently fresh gate state was unavailable. It is not evidence of working protection and should not trigger automatic rule changes. Failure closes the gate; reopening requires consecutive successes. This does not choose another node automatically.

Full timestamps use the router's timezone. Lists show relative time with full time on hover. Internal history can use UTC buckets without displaying a second timezone. Language changes translate fixed UI text, not user names.

## Import and subscriptions

Import diagnostics can show unsupported parameter names without returning credential values. Exports, browser request inspectors, subscription caches and system backups are not thereby sanitized. Review screenshots and attachments before sharing.

Refresh updates a source cache. Choosing differences, importing, selecting a default and applying are separate actions. A successful refresh does not prove node connectivity; a successful node test does not cover every device, DNS or WebRTC scenario.

## Installation and recovery

Configuration can be saved while disabled. Only explicit activation creates network rules and changes DNS. Removal stops LaneKeep and restores its owned network state. If another tool changed DNS later, restoration touches only fields still owned by LaneKeep and preserves those external edits.

An enabled upgrade briefly stops and restarts interception; existing connections may drop. Configuration upgrade is not an atomic whole-system snapshot. Back up your configuration first. APK may retain modified configuration files after removal; handle those according to your data-retention needs.
