# v1.0.2 发布包验收 / Release package acceptance

日期：2026-11-28。本文记录 **v1.0.2 APK 的构建、从已启用的 0.2.1-r1 升级、全局和增强模式防泄漏回归、直连模式与“未分组设备去向”、固件升级后重装、全新安装、核心故障与停止、开机、核心启停窗口，以及卸载**。验收在电脑上的独立 QEMU 虚拟机进行，未连接任何实体路由器。v0.2.1 的记录见 [../v0.2.1/acceptance.md](../v0.2.1/acceptance.md)。

This report covers building the v1.0.2 APK, upgrading an enabled 0.2.1-r1 instance, the Global/Enhanced leak regression, Direct mode and “Devices without a mode”, reinstalling after a simulated sysupgrade, a fresh installation, core failure and stop, boot, the core start/stop window and removal, on an isolated QEMU VM with **no host or internet access**. Client devices are network namespaces inside the VM; a simulated upstream records which address each test server saw. All changes went through the real ubus/rpcd methods of the installed package. LuCI pages were not opened in a logged-in browser.

环境：OpenWrt 25.12.6 x86_64、Linux 6.12.112、Xray 26.10.21。QEMU 用户网络加 `restrict=on`，客机不能访问宿主或外网，只把 SSH 转发到本机。测试网络全部在虚拟机内部：局域网上有四类客户端（`.101` 全局、`.102` 增强、`.105` 明确设为直连、`.110` 未分组），WAN 侧是模拟上游，测试 WAN 地址 `203.0.113.2`，模拟节点 `198.51.100.2`。探测时给测试 WAN 口加上真实路由器那样的 LAN→WAN 放行和地址转换，所以任何没被拦住的流量都会以 WAN 地址出现在上游记录里，记为 D；只从节点出去记为 P；什么都没到达记为 -。起点是防泄漏加固测试用的盘：v0.2.1 验收盘的副本，装有已发布的 0.2.1-r1 并已启用，另有离线测试证书和测试节点。

## 结果

| 步骤 | 验证结果 |
|---|---|
| 构建 | 在测试机内用 apk-tools 3 构建 `luci-app-lanekeep-1.0.2-r1.apk`，308,935 字节，SHA256 `e8135ca6e125ebc487263019e9ae1aa43f7191fd48177787757908f16ff0a529`，109 个文件。构建输入 `root/`、`packaging/`、`tools/build` 取自提交 `46b5d87`，与发布提交一致。包内生成器的 SHA256 等于面板锁定值。 |
| 从已启用的 0.2.1-r1 升级 | `apk add --upgrade` 9 秒完成；三个用户配置文件 SHA256 不变；升级后阻断表 `lanekeep_guard` 已装上并保存为开机副本，`S18lanekeep-guard` 已启用；未分组设备保持常规；模板指纹 `31e8d3cc…69ca7`；规则核对全部一致；门控 OPEN；106 个非配置文件与包内一致。 |
| 升级实例的防泄漏回归（未分组=常规） | 全局、增强两组 160 个用例与加固基线 r3 逐项对照：0 项变化，0 项退步。仍为 D 的用例与基线相同（增强模式国内 TCP、用户自加的直连规则、公网地址上的 `geosite:private` 域名等已知项）。 |
| 发布前审查发现的核心启停窗口 | 见下一节。修前在候选构建上复现两种泄漏；修后同样条件下全部为 -。 |
| 核心与规则反复重启时的连续探测 | 全新实例，未分组=直连。全局、增强客户端每秒各发 25 轮新的 UDP 流（STUN 和 DNS），期间核心重启 5 次、LaneKeep 重启 1 次、经面板应用规则 2 次，共 12,542 个包：0 个从 WAN 地址直接出去，3,714 个经节点出去。每次重启都有其他组的包落到直连链，被链首的丢弃规则拦下（5 次核心重启累计全局、增强各 382 个）。 |
| 固件升级后重装（模拟） | 删除状态目录、保留配置后重装：a 保留用户配置 → 常规；b 只有节点文件改过 → 常规；c 三个文件都是出厂内容 → 直连。三项都符合预期。 |
| 测试机检查 `tests/target` | IP 解析 41/41；生成器全部通过，且与加固提交 `aad799b` 的输出相比只多出直连模式的部分；延迟 9/9；HY2 用例 128/128；HY2 生成器检查和本机 HY2 运行检查全部通过。在 LaneKeep 停用时针对发布源码运行。 |
| 全新安装 | 安装前先移走保留的配置和状态。安装后网络、DHCP、防火墙、dnsmasq、策略路由和路由表不变，nft 规则集只有计数值不同；首次安装写入“未分组=直连”；停用状态，没有本包 nft 表，状态接口正常。 |
| 启用 | 经面板接口添加测试节点、测试并确认、启用、设置成员；门控 OPEN；规则核对全部一致；直连链已含新的丢弃规则。 |
| 全新实例的防泄漏回归（未分组=直连） | 同样 160 个用例对照 r3：0 项变化，0 项退步。 |
| 直连模式与阻断表 | 生成配置中两条加固规则只属于全局/增强入口，直连的四条规则排在最后。直连和未分组设备的 28 个用例与直连模式开发时的基线结果完全一致；路由器 DNS（UDP、TCP）有应答，阻断表计数保持 0；路由器内部端口在 nft 层被丢弃 90 个包，对 WAN 地址的探测全部没有到达上游。 |
| 节点故障、核心停止（四类客户端） | 节点不可用：全局、增强全部阻断，直连和未分组照常直连（直连模式不使用节点）。核心停止：四类全部阻断。与直连模式开发时的基线结果完全一致。 |
| 停止与停用 | 停止核心、停止 LaneKeep（只剩阻断表）时，四类客户端全部阻断，路由器 DNS 超时。对照项：明确停用后阻断表移除，同样的探测有一半以 WAN 地址直接出去，说明探测能发现直连。之后经面板重新启用。 |
| 开机 | 只保留早期脚本 `S18lanekeep-guard` 重启：只有阻断表在，四类客户端 24 个探测全部被拦。开机检查不通过（LAN IPv6 未关闭）：启用标记保持 1，阻断表在位，全部被拦。在网络配置里关闭 LAN IPv6 后正常重启：LaneKeep 自己启动，上游就绪后门控 OPEN，全局、增强经节点，直连和未分组直连。 |
| 规则页内置顺序 | 状态接口返回常规、全局、增强、按需四组内置规则，每组只有最后一行标为“本组最终默认”，没有警告。 |
| 卸载 | 网络、DHCP、防火墙、dnsmasq、策略路由和路由表与安装前一致，nft 规则集只有计数值不同；阻断表和开机脚本已移除；没有残留进程。 |
| 离线检查 | 11 项发布不变量测试通过，包括新增的直连链丢弃规则检查。 |

机器可读结果见 [acceptance.json](acceptance.json)，各项输出见 [logs/](logs/)（只删去了测试工具的退出码行和重复的离线缓存警告）。去个人化与 gitleaks 结果见 [../privacy-scan.json](../privacy-scan.json)。

## 发布前审查发现的核心启停窗口

推送前的独立审查指出：某个模式的透明入口没有在监听时，TPROXY 找不到套接字，这条规则不成立，包回到分发链继续往下走，最后进入未分组设备的链。核心启动或停止时，各入口是依次打开、依次关闭的，所以可能出现直连入口 12349 在听、其他模式入口不在听的一小段时间。

修前，在候选构建 `bd9c13d` 上强制造出这个状态：停止核心，手工起一份去掉对应入口的配置。

- A：未分组=直连，只有 12345、12348、12349 在听。全局、增强的 12 个探测全部为 D，向路由器查询拿到真实地址。
- B：未分组=常规，12349 不在听，`.105` 明确设为直连。它落进常规模式，按常规规则处理：一个 STUN 探测经节点出去，DNS 拿到 FakeIP 地址。这与“直连模式不经过代理节点”不符。

修法（提交 `46b5d87`）只改直连模式自己的链 `capture_direct`，其他模式的捕获链和分发链不变：

- 链首丢弃全局、增强、按需、常规四组成员；
- TPROXY 之后丢弃其余 TCP/UDP，不再交给后面的链。

修后同样条件下，A、B 全部为 -，链首和链尾的丢弃计数各拦到 14 个包。上面的连续探测也显示，真实的核心重启中确实有包落到直连链，并被这些规则丢弃。

未分组=常规时，全局、增强、按需成员在同样的窗口里会落进常规模式的链，按常规规则处理。以前的版本就是这样，本版未改，见[防泄漏说明](../../leak-protection.md)。

## 过程中的问题及处理

- 候选构建 `bd9c13d` 因上述审查发现作废，它的构建和测试结果不计入本验收。修复后的 `46b5d87` 重新构建，并从同一块 0.2.1 起点盘的新副本重做全部测试。
- B 的第一次修前探测无效：那时 `.105` 不是明确的直连成员，只是未分组设备。把它设为直连成员后重做，上表用的是重做结果。
- `hy2-check.sh` 第一次失败在 `lan_members`：直连模式把测试地址生成改成 5 个，HY2 分支的脚本仍要求正好 3 个。提交 `68a0cd0` 改为取前 3 个，重跑全部通过。这只改测试脚本，包不变。
- 第二次开机测试时，测试工具在建好测试拓扑之前读取状态，LAN IPv6 尚未关闭，结果成了“开机检查不通过”。这正是该情形的预期结果，按此记录。随后把 LAN IPv6 关闭写进网络配置，再做正常开机。卸载检查前已把这项仅用于测试的网络配置改动还原。
- 安装前后、卸载前后 nft 规则集的差异只在计数值，去掉计数后逐字一致。

已知问题：

- 卸载后与 0.2.x 相同，保留已改的配置（`/etc/config/lanekeep*`、`/etc/lanekeep-proxy`）、一个空的 `/etc/lanekeep-state` 和悬空的 `/etc/rc.d/K9lanekeep`。
- 另有 `/tmp` 下的运行目录，重启后消失；没有和 0.2.1 对照。
- 连接监控没有 12349 的接收队列指标。
- 设备换组后，已有连接会留在原来的入口上，直到自然结束（以前的版本相同）。

## 验证边界

本次没有验证：

- 真实核心重启时各入口打开和关闭的先后顺序及窗口长短（只做了强制状态和连续探测）；
- 从 1.0.2 升级到以后版本时阻断表是否保留（需要更新的包），以及任何一次升级进行中的断网情况；
- 从 0.2.1 升级那一次由旧版脚本造成的直连窗口（未探测）；
- 从 0.1.0、0.2.0 直接升级；
- 真正的 sysupgrade（只做了模拟）和编进固件镜像的安装；
- 登录后的 LuCI 页面、真实节点和订阅、真实 HY2 服务器（只用本机测试服务器）；
- IPv6 客户端、Wi-Fi/AP 接入、其他架构和实体设备。

Not verified in this run: the actual order and length of the inbound open/close window in a real core restart (only a forced state and continuous probing were tested); whether a later upgrade from 1.0.2 keeps the guard table, and connectivity during any upgrade; the direct window of the one upgrade from 0.2.1 that runs the old script (not probed); direct upgrades from 0.1.0 or 0.2.0; a real sysupgrade (only simulated) and firmware-image builds; logged-in LuCI pages, real nodes and subscriptions, a real HY2 server (only a local test server); IPv6 clients, Wi-Fi/AP access, other architectures and physical devices.
