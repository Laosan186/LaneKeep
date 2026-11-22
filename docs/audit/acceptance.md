# v0.1.0 发布包验收 / Release package acceptance

> 本文为 v0.1.0 的记录。v0.2.0 见 [v0.2.0/acceptance.md](v0.2.0/acceptance.md)，v0.2.1 见 [v0.2.1/acceptance.md](v0.2.1/acceptance.md)。 This is the v0.1.0 record; see [v0.2.0/acceptance.md](v0.2.0/acceptance.md) for v0.2.0 and [v0.2.1/acceptance.md](v0.2.1/acceptance.md) for v0.2.1.

日期：2026-11-16。本文记录 **v0.1.0 通用 APK 的安装、升级和卸载验收**。本次发布包验收在电脑上的独立 QEMU 虚拟机进行，未连接或修改已有实体路由器。

LaneKeep 此前已有真实 OpenWrt 设备的部署和使用记录，六个页面也完成过实机浏览器检查。本次开源版在此前功能基础上完成去个人化，并新增通用软件包的首次启用、升级和卸载处理。因此需要分别记录：**此前版本的实机运行与页面验收**，以及**本次通用 APK 的虚拟机生命周期验收**。通用 APK 尚未在该实体设备上执行全新安装、升级和卸载流程。

Earlier deployed versions have run on real OpenWrt hardware and passed six-page browser checks. This report specifically covers lifecycle testing of the generic v0.1.0 APK in QEMU. The package lifecycle has not been exercised on that physical device.

环境：OpenWrt 25.12.6 x86_64、Linux 6.12.112、Xray 26.10.21；QEMU 用户网络，无物理桥接或 TAP。浏览器为本机无头 Edge。测试客户端位于虚拟机的独立网络命名空间，经 veth 接入模拟 LAN。测试 VLESS REALITY 节点使用临时凭据和受控响应；这些凭据未进入仓库或软件包。

## 结果

| 步骤 | 验证结果 |
|---|---|
| 空安装 | 最终 r1 APK 安装成功；节点、默认节点和分组成员为空，enabled=0。网络/DHCP 文件、nft 规则及策略路由与安装前一致。 |
| 未设默认即启用 | 被拒绝，没有创建接管规则。 |
| 添加节点、测试、设默认 | 真实 RPC 与事务完成，协议测试通过；这些保存操作均不启用接管。 |
| 分组、应用 | 对已设静态租约的模拟客户端分组并应用成功；停用状态没有运行时接管。 |
| 单独确认启用 | 核心运行、门控 OPEN 且租约有效；模拟客户端通过透明代理取得受控响应，普通 DNS 查询得到预期结果。 |
| 活动状态保存与失败回退 | 新增未使用节点成功；切换到不可达测试节点后，等待失败并回退原默认节点。总事务约 80.67 秒，包含等待、重启和恢复；最后门控 OPEN。 |
| 升级 r1 → r2 | 实际 APK 升级完成，节点与分组配置 SHA256 保持，enabled=1 保持，门控恢复 OPEN。r2 仅作为升级测试修订号，不是额外产品版本。 |
| 浏览器缓存 | 同一个浏览器上下文，缓存开启，没有强制刷新；自有 JS/CSS 从 `v0_1_0_r1` 路径切到 `v0_1_0_r2`，升级后无页面错误。 |
| 六个实际页面 | 最终 r1 的节点、状态、设备、规则、详细数据、版本页面全部加载；每页具有面板根节点和样式，最终检查控制台及请求错误均为零。 |
| 外部 DNS 配置编辑 | 启用后模拟外部修改 dnsmasq 字段，停用保留该修改，只还原 LaneKeep 接管的 DNS 字段；测试结束撤销模拟编辑。 |
| 卸载 | r2 与最终 r1 分别实际卸载。自有服务全部停止，自建 nft 表/策略路由移除，网络与 DNS 文件及规则/路由完整快照逐字恢复，客户端 DNS 与恢复后的上游一致。 |
| 包内容 | 最终 r1 解包内容通过 gitleaks；实际安装的 100 个不可变文件与 APK 中对应文件逐个 SHA256 一致。三个用户配置文件单独保留，不作为不可变文件比较。 |
| 离线检查 | 四项发布不变量测试通过；公开 geodata 子集可按锁定源文件重现；六张演示截图无真实数据。 |

机器可读结果和包摘要见 [acceptance.json](acceptance.json)。安装、升级、卸载的包管理器日志见 [logs/](logs/)。文档说法修订见 [document-audit.md](document-audit.md)，去个人化检查见 [privacy-scan.json](privacy-scan.json)。

## 过程中的问题及处理

- 包集成阶段发现启动包装脚本引用错误和缺少 `coreutils-timeout` 依赖，均已修复并重新构建。
- 实际使用不同 LAN 子网时发现两处转义形式的旧网段约束，已改为所选 LAN 校验；扫描增加转义文本检查。
- 测试 HTTP 服务最初权限与路径不正确，修复夹具后协议测试通过。健康专用域名按设计拒绝客户端查询，普通 DNS 改用普通示例域名验证。
- 测试电脑的原 DNS 上游本身使用 FakeIP。因此“卸载后不能出现 FakeIP”不是有效断言，最终比较恢复后的原上游答案以及完整网络快照。
- 首次浏览器资源加载曾出现本机连接拒绝；保留该失败记录。最终使用保留缓存的浏览器检查，六页和升级检查均通过，未将早期失败记作通过。
- 小测试磁盘曾被构建工具以及独立测试进程持有的已删除二进制占满。移除临时构建工具、停止夹具后释放空间，最终 r1 重新空安装及完整启用流程通过；没有修改包策略绕过空间问题。
- 节点页可能显示断线保护“未知”：这表示该页缺少足够状态，并不等于后端保护正常或失效。后端核心、门控和租约在测试中单独核对。此边界保留于进阶文档。

## 验证边界

这是指定版本、指定虚拟平台和受控节点的验收，不是所有硬件、所有协议组合、真实订阅、客户端 WebRTC、断电或所有故障模式的保证。OpenWrt SDK Makefile 已提供，本次交付 APK 由独立 apk-tools 3 构建路径产生；没有声称执行过 SDK 全量编译。

Installation, node setup, explicit activation, transparent client traffic, upgrade, cache replacement and removal were exercised on an isolated OpenWrt VM. The final package remains disabled on a clean install. Removal restored the recorded network state exactly. Controlled protocol fixtures are not evidence of every real-world protocol or leak-test scenario.
