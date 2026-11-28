# Target-machine checks / 测试机检查

These scripts run on an **isolated OpenWrt 25.12 test machine** (for example a QEMU VM without outside network access) that has LaneKeep's dependencies, including `xray-core` and the v2ray geodata. Never run them on a router that carries real traffic. They use synthetic nodes, rules and addresses, write only under `/tmp`, and never install, start, stop, reload or apply LaneKeep services or configuration; `latency-check.sh` only starts temporary local test processes (xray and an HTTP stub). `rules-check.sh` reads the selected LAN interface from OpenWrt to pick test member addresses. The one exception to “write only under `/tmp`” is `hy2-runtime.sh`, which adds and then removes its own test nftables tables (see below).

这些脚本只在**隔离的 OpenWrt 25.12 测试机**上运行（例如不通外网的 QEMU 虚拟机），需要已装好 LaneKeep 的依赖，包括 `xray-core` 和 v2ray 分类数据。不要在承载真实流量的路由器上运行。脚本只用合成的节点、规则和地址，只写 `/tmp`，不安装、不启停或重载 LaneKeep 服务、不应用配置；`latency-check.sh` 只会启动临时的本机测试进程（xray 和 HTTP 桩服务）。唯一例外是 `hy2-runtime.sh`：它会新增并在退出时删除自己的测试 nftables 表（见下文）。

Copy a checkout of this repository to the test machine, then from its top directory:

```sh
ucode tests/target/ip-rule-cases.uc                 # IP rule parsing and reserved ranges
sh tests/target/rules-check.sh . [PREVIOUS_CHECKOUT] # generator, xray -test, sequence numbers, rejections
sh tests/target/latency-check.sh .                   # node latency v3 against a local HTTP stub
ucode tests/target/hy2-cases.uc                     # HY2 mport/pinSHA256 parsing, store format 7, form edits
sh tests/target/hy2-check.sh . [PREVIOUS_CHECKOUT]   # HY2 hop/pin generator output, xray -test, identities
sh tests/target/hy2-runtime.sh .                     # HY2 hopping, pin and gate on loopback (see below)
```

With `PREVIOUS_CHECKOUT` (for example the `v0.1.0` tree), `rules-check.sh` also confirms that output without IP rules is byte-identical to the previous generator and that the previous generator rejects the `ip` type. `latency-check.sh` redirects every request from a temporary local SOCKS inbound to `latency-stub.uc` on `127.0.0.1:18080`; nothing leaves the machine. It briefly uses ports 18080 and 23456.

With `PREVIOUS_CHECKOUT`, `hy2-check.sh` also confirms that stores without the new HY2 fields give byte-identical generator output and node identities, and that the previous generator rejects a format 7 store. `hy2-runtime.sh` is the only script that changes nftables: it adds the test tables `inet lanekeep_hy2_test` (hop redirect and counters) and `inet lanekeep_hy2_gate` (a renamed copy of LaneKeep's DNS gate, which drops marked traffic without a lease) and removes them on exit. It starts a local HY2 server and client on `127.0.0.1` (ports 28443, 21080, 18080 and 20000–20049), takes about two minutes, and refuses to run while LaneKeep's own gate table exists.

`hy2-runtime.sh` 是唯一会改 nftables 的脚本：它新增测试表 `inet lanekeep_hy2_test`（跳端口重定向和计数）与 `inet lanekeep_hy2_gate`（LaneKeep DNS 闸门的改名副本，无租约时丢弃带标记的流量），退出时删除。它在 `127.0.0.1` 上启动临时 HY2 服务端和客户端，约需两分钟；LaneKeep 自己的闸门表存在时拒绝运行。
