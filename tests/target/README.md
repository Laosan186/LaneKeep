# Target-machine checks / 测试机检查

These scripts run on an **isolated OpenWrt 25.12 test machine** (for example a QEMU VM without outside network access) that has LaneKeep's dependencies, including `xray-core` and the v2ray geodata. Never run them on a router that carries real traffic. They use synthetic nodes, rules and addresses, write only under `/tmp`, and never install, start, stop, reload or apply LaneKeep services or configuration; `latency-check.sh` only starts temporary local test processes (xray and an HTTP stub). `rules-check.sh` reads the selected LAN interface from OpenWrt to pick test member addresses.

这些脚本只在**隔离的 OpenWrt 25.12 测试机**上运行（例如不通外网的 QEMU 虚拟机），需要已装好 LaneKeep 的依赖，包括 `xray-core` 和 v2ray 分类数据。不要在承载真实流量的路由器上运行。脚本只用合成的节点、规则和地址，只写 `/tmp`，不安装、不启停或重载 LaneKeep 服务、不应用配置；`latency-check.sh` 只会启动临时的本机测试进程（xray 和 HTTP 桩服务）。

Copy a checkout of this repository to the test machine, then from its top directory:

```sh
ucode tests/target/ip-rule-cases.uc                 # IP rule parsing and reserved ranges
sh tests/target/rules-check.sh . [PREVIOUS_CHECKOUT] # generator, xray -test, sequence numbers, rejections
sh tests/target/latency-check.sh .                   # node latency v3 against a local HTTP stub
```

With `PREVIOUS_CHECKOUT` (for example the `v0.1.0` tree), `rules-check.sh` also confirms that output without IP rules is byte-identical to the previous generator and that the previous generator rejects the `ip` type. `latency-check.sh` redirects every request from a temporary local SOCKS inbound to `latency-stub.uc` on `127.0.0.1:18080`; nothing leaves the machine. It briefly uses ports 18080 and 23456.
