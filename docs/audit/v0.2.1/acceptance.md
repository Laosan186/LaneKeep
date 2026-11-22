# v0.2.1 发布包验收 / Release package acceptance

日期：2026-11-21。本文记录 **v0.2.1 APK 的构建、从 0.2.0 升级、卸载、全新安装，以及节点页断线保护状态修复在目标系统上的检查**。验收在电脑上的独立 QEMU 虚拟机进行，未连接任何实体路由器。v0.2.0 的记录见 [../v0.2.0/acceptance.md](../v0.2.0/acceptance.md)。

This report covers building the v0.2.1 APK, upgrading from 0.2.0, removal, a fresh installation and the Nodes-page kill-switch fix on an isolated QEMU VM with **no host or internet access**. The fix was checked through the real ubus/rpcd methods of the installed package. LuCI pages were not opened in a logged-in browser this time; see the limits below.

环境：OpenWrt 25.12.6 x86_64、Linux 6.12.112、Xray 26.10.21。QEMU 用户网络加 `restrict=on`，客机不能访问宿主或外网，只把 SSH 和 LuCI 转发到本机。起点是 v0.2.0 最终验收盘的副本：先用 `apk del` 卸掉盘上留下的 0.2.0-r1，删除保留的配置和运行状态目录后重启。依赖和三条静态 DHCP 主机保留；除已知的悬空 `/etc/rc.d/K9lanekeep` 外，没有 LaneKeep 文件。

## 结果

| 步骤 | 验证结果 |
|---|---|
| 构建 | 在测试机内用 apk-tools 3 构建 `luci-app-lanekeep-0.2.1-r1.apk`，297,449 字节，SHA256 `c6e126a4ea3843224ec6436d76cf84f8ea175d5bc70f28ecb836b02b2d93539f`，104 个文件。构建输入 `root/`、`packaging/`、`tools/build` 与发布提交一致。 |
| 全新安装已发布的 0.2.0-r1 | 核对发布摘要后安装；网络/DHCP 文件、nft 规则集、策略路由和路由表与安装前一致；101 个不可变文件与包内一致；停用，服务未运行。 |
| 0.2.0 上经真实 RPC 应用 | 设备分组（3 台）与 5 条域名规则经“检查→应用”事务完成；未添加节点。 |
| 0.2.0 的节点接口 | 问题复现：`nodes` 回复没有 `gate`；`status` 正常返回 gate。 |
| 升级到 0.2.1-r1（停用实例） | 三个用户配置文件 SHA256 不变；101 个不可变文件一致；停用状态保留；页面资源目录从 `v0_2_0_r1` 换成 `v0_2_1_r1`。 |
| 0.2.1 的节点接口 | 没有门控状态文件时，`nodes` 与 `status` 都返回 `{"state":"CLOSED","fresh":false,"lease_valid":false}`，节点页据此显示“未知”。写入一份合成的新鲜门控文件后，两者都返回 `{"state":"CLOSED","fresh":true,"lease_valid":false}`，节点页据此显示“已触发”（核心未运行，所以不是 OPEN）。两种情况下，`status` 的 gate 和“门控状态过期”警告都与 0.2.0 逐字一致；`nodes` 回复只多了 `gate` 一个键。 |
| 读取失败时的回退 | 把 `/usr/sbin/nft` 临时绑定为输出非法 JSON 的脚本：`nodes` 仍返回 `ok`，gate 为 `CLOSED`、`fresh:false`；`status` 此时整体返回失败。按未改动的 status 代码，0.2.0 应同样失败（未在 0.2.0 上实测）。测试后已解除绑定；之后卸载时的 nft 规则集快照与安装前逐字一致。 |
| 页面资源 | 不登录 LuCI，经本机转发逐个下载已安装的 23 个 LaneKeep 前端文件，内容与安装文件一致；升级前全部在 `v0_2_0_r1`，升级后全部在 `v0_2_1_r1`。 |
| 0.2.1 上经真实 RPC 应用 IP 规则 | 4 条 IP 规则应用成功，全部启用规则都有生效序号；状态接口返回 `rule_types`；按需组的代理 IP 在生成配置中出现两次（UDP 443 保护行和代理行；分行与保护由测试机检查的 “IP rows separate, guarded and additive” 覆盖）。 |
| 卸载 0.2.1-r1 | 网络/DHCP 文件、nft、策略路由和路由表与安装 0.2.0 之前逐字一致；自有服务均未运行；依赖保留；APK 保留的已改配置与 0.2.0 验收相同。 |
| 全新安装 0.2.1-r1 | 先把卸载保留的 `/etc/config/lanekeep`、`/etc/lanekeep-proxy`、`/etc/lanekeep-state` 移到 `/tmp`；安装后网络状态不变，101 个不可变文件一致，停用，状态接口正常；节点接口的门控检查结果与升级后相同。 |
| 测试机检查 `tests/target` | IP 解析 41/41；生成器 16/16（零 IP 规则时与 v0.1.0 输出逐字节相同，带 IP 规则通过 `xray run -test`）；延迟 8/8。在完成上述流程的同一测试盘上针对发布源码运行，输出见 [logs/target-checks.txt](logs/target-checks.txt)。 |
| 离线检查 | 10 项发布不变量测试通过，包括新增的门控共享读取检查。 |
| 前端显示 | 用发布源码的演示预览（打包同款前端文件，资源目录 `v0_2_1_r1`）打开节点页，把节点接口回复里的 gate 换成四种值：OPEN 且新鲜显示“待命”，CLOSED 且新鲜显示“已触发”，`fresh:false` 或删掉 gate 显示“未知”；中文和英文界面结果相同。这不是测试机上的 LuCI。 |

机器可读结果见 [acceptance.json](acceptance.json)。门控检查的逐项输出见 [logs/gate-checks.txt](logs/gate-checks.txt)，包管理器日志见 [logs/](logs/)（已删去重复的离线缓存警告行）。演示预览检查的数值由验收者从浏览器工具结果记录。去个人化与 gitleaks 结果见 [../privacy-scan.json](../privacy-scan.json)。

## 过程中的问题及处理

- 原计划在内置浏览器里登录测试机 LuCI 检查六个页面，但本次验收会话的自动权限检查不允许读取测试机的登录凭据，所以改为上表中的接口、文件和演示预览检查。登录后的真实 LuCI 页面本次没有打开。
- 卸载后除 APK 保留的已改配置（`/etc/config/lanekeep`、`/etc/lanekeep-proxy`）外，还残留运行状态目录 `/etc/lanekeep-state` 和悬空的 `/etc/rc.d/K9lanekeep` 链接，与 0.2.0 相同，作为已知问题保留。
- 升级和卸载日志中的 `ubus call service delete … (Not found)` 出现在停用实例上：服务本来就没有注册，不影响结果。

## 验证边界

本次没有验证：节点页的“待命”状态（需要已启用且门控打开的实例，离线测试机无法让核心、DNS 门控和健康租约同时就绪）、登录后的真实 LuCI 页面、明确启用、断线保护门控本身、模拟客户端的透明代理和 DNS、已启用实例的升级、从 0.1.0 直接升级到 0.2.1、经面板对真实或夹具节点做测试，以及其他架构和实体设备。门控的计算代码与 0.2.0 相同，只是移到 status 和节点接口共用的函数里。

Not verified in this run: the Standby state on the Nodes page (it needs an enabled instance with an open gate, which the offline VM cannot provide), logged-in LuCI pages, explicit activation, the kill-switch gate itself, transparent client traffic and DNS, upgrading an enabled instance, a direct upgrade from 0.1.0 to 0.2.1, panel node tests against real or fixture nodes, other architectures and physical devices. The gate computation is the 0.2.0 code, moved into a function shared by the status and nodes methods.
