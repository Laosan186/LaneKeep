# v0.2.0 发布包验收 / Release package acceptance

日期：2026-11-20。本文记录 **v0.2.0 APK 的安装、从 0.1.0 升级、卸载和新功能检查**。验收在电脑上的独立 QEMU 虚拟机进行，未连接任何实体路由器。v0.1.0 的完整记录见 [../acceptance.md](../acceptance.md)。

This report covers installation, upgrade from 0.1.0, removal and the new features of the v0.2.0 APK on an isolated QEMU VM. Unlike the v0.1.0 run, the VM had **no host or internet access**, so explicit activation, the kill-switch gate and transparent client traffic were not exercised again; packaging, lifecycle, nftables, DNS and gate code are unchanged since 0.1.0.

环境：OpenWrt 25.12.6 x86_64、Linux 6.12.112、Xray 26.10.21。QEMU 用户网络加 `restrict=on`，客机不能访问宿主或外网，只把 SSH 和 LuCI 转发到本机。起点是一份已装好 LaneKeep 全部依赖（均列在 `/etc/apk/world`）的测试盘副本，测试前删除了其中旧的 LaneKeep 文件，因此安装和升级都用 `apk --no-network` 完成。

## 结果

| 步骤 | 验证结果 |
|---|---|
| 构建 | 在测试机内用 apk-tools 3 构建 `luci-app-lanekeep-0.2.0-r1.apk`，297,320 字节，SHA256 `16f3c957919dcd4a414908fec2f980b2117be5486c1b17bb102282e215aa6e37`，104 个文件。 |
| 全新安装已发布的 0.1.0-r1 | 核对发布摘要后安装；网络/DHCP 文件、nft 规则集、策略路由和路由表与安装前一致；100 个不可变文件与包内一致；停用，服务未运行。 |
| 0.1.0 上经真实 RPC 应用 | 设备分组（3 台）与 5 条域名规则经“检查→应用”事务完成。 |
| 升级到 0.2.0-r1 | 三个用户配置文件 SHA256 不变；101 个不可变文件一致；停用状态保留；旧的 `v0_1_0_r1` 资源目录已移除。 |
| 浏览器缓存 | 同一浏览器上下文、缓存开启、不强制刷新：升级前页面加载 `v0_1_0_r1` 资源，升级后改为 `v0_2_0_r1`（`panel.css?v=0.2.0-r1`），新版规则页正常显示。 |
| 真实 LuCI 六页（0.2.0） | 节点、状态、设备分组、规则、详细数据、版本均加载，每页一个面板根节点，控制台无错误。停用实例的状态页和详细数据页显示“读取失败”提示，原因是采样未启动（相关代码与 0.1.0 相同）。 |
| 0.2.0 上经真实 RPC 应用 IP 规则 | 4 条 IP 规则应用成功，`/32` 规范为单个地址；全部启用规则都有生效序号；状态接口返回 `rule_types`；生成配置中按需组代理 IP 同时出现在 UDP 443 保护行和代理行。 |
| 卸载 0.2.0-r1 | 网络/DHCP 文件、nft、策略路由和路由表与安装 0.1.0 之前逐字一致；自有服务均未运行；依赖保留；用户改过的配置文件按 APK 规则保留。 |
| 全新安装 0.2.0-r1 | 先把保留的配置移出；安装后网络状态不变，101 个不可变文件一致，停用，状态接口正常。 |
| 测试机检查 `tests/target` | IP 解析 41/41；生成器 16/16（零 IP 规则时与 v0.1.0 输出逐字节相同，带 IP 规则通过 `xray run -test`，生效序号核对，非法输入和两跳链出口被拒）；延迟 8/8。输出见 [logs/target-checks.txt](logs/target-checks.txt)。 |
| 离线检查 | 9 项发布不变量测试通过。 |

机器可读结果见 [acceptance.json](acceptance.json)，包管理器日志见 [logs/](logs/)。去个人化与 gitleaks 结果见 [../privacy-scan.json](../privacy-scan.json)。

## 过程中的问题及处理

- 内置浏览器窗格处于隐藏状态时，页面不绘制，`requestAnimationFrame` 不触发；LuCI 用它冲刷排队的 RPC 请求，页面因此停在“Loading view…”。直接发出的 ubus 请求正常。检查时在页面里把 `requestAnimationFrame` 换成短定时器后，各页正常加载。这是测试环境问题，未修改产品代码。
- 卸载后残留一个悬空的 `/etc/rc.d/K9lanekeep` 链接。v0.1.0 验收盘卸载后同样存在；打包脚本本次未改，作为已知问题另行处理。
- 升级和卸载日志中的 `ubus call service delete … (Not found)` 出现在停用实例上：服务本来就没有注册，不影响结果。

## 验证边界

本次没有重新验证：明确启用、断线保护门控、模拟客户端的透明代理和 DNS、已启用实例的升级、经面板对真实或夹具节点做测试，以及其他架构和实体设备。这些路径的打包、生命周期、nft、DNS 与门控代码自 0.1.0 起未改，0.1.0 的结果见上级目录。同一组改动此前已在实体 OpenWrt 设备上部署使用；本开源包没有在实体设备上验证，IP 规则对真实应用流量的命中和真实节点上的延迟数值也不属于本次验收。

Not re-verified in this run: explicit activation, the kill-switch gate, transparent client traffic and DNS, upgrading an enabled instance, panel node tests against real or fixture nodes, other architectures and physical devices.
