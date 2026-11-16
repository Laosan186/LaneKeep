# v0.1.0 文档技术核对 / Documentation audit

四份提供的中英文 README 与防泄漏说明已按以下结果修订。产品边界以本版本代码为准；没有为了迎合原介绍而扩大保护策略。

| 原介绍中需要收窄或补足的说法 | 交付文档的说法 | 代码依据 |
|---|---|---|
| 各模式保护规则可能被理解为完全相同 | 四模式均有 53 接管、853 阻断、已知 DoH 规则和 FakeIP 防外发；按需模式的 UDP 443 只覆盖所选服务，不是全局阻断 | `root/etc/lanekeep-proxy/template.json` routing; `lanekeep-gen.uc` nft template |
| 所有模式均阻止 Apple relay | 全局模式有额外 relay 域名阻断；不扩大成所有模式保证 | template routing / DNS outbound rules |
| 能自动处理 IPv6 | v0.1.0 是 IPv4 路径；用户必须事先停用 LAN IPv6，启用检查不通过就拒绝；包不改 IPv6 配置，卸载也不会替用户恢复手动改动 | `network.uc`, `lifecycle-preflight.uc` |
| 全部 DNS 都经同一国外位置，或跟随各组节点 | 共享保护 DNS 经默认节点；主备 Cloudflare 地址不保证地理位置；常规模式国内分类保留本地 dnsmasq → 5053 → Ali DoH 路径 | `settings.uc`, template, `domestic-dns.json` |
| 保护等同于完全禁止 WebRTC / 任意 DoH | 只覆盖规则能识别的流量；直连目的地和未知自建 DoH 不作全面保证，专用端口有单独边界 | template, `dedicated.uc`, `chain-model.uc` |
| 日志完全关闭、磁盘不存敏感数据 | Xray access/error 为 none，loglevel none，dnsLog false；配置、订阅、快照、系统服务日志仍可能含敏感信息 | template log, `domestic-dns.json`, `panel.uc`, `subscriptions.uc` |
| 固定每两秒完成检测、断线立即保护 | 每轮后等待两秒，整轮最多三秒；主 1.1.1.1、备 1.0.0.1；连续两次成功开放，八秒租约防止守护失联后长期开放 | `dns-gate-watchdog.sh`, `dns-gate-probe.sh`, `settings.uc`, `dns-gate.nft` |
| 默认节点故障会自动选别的节点 | 不自动选节点；主动切换默认节点后最多等待六十秒，失败尝试退回前一配置，恢复失败继续阻断 | `lanekeep-apply`, `panel.uc` |
| 专用端口像普通设备模式一样包含所有规则 | 10811–10860，仅全局/增强/按需模式；限制源成员，专用路径不继承全部业务和广告规则 | `dedicated.uc`, `panel.uc`, `lanekeep-gen.uc` |
| 协议列表意味着所有组合都已验证 | 按 `capabilities.json` 列模型支持和试用状态；实验组合仍需确认，实际链、UDP、传输组合不能由名字推断 | `protocol-model.uc`, `caps.uc`, capabilities JSON |
| 32 条节点或链均有统计 | 面板有效上限 21，另有 96 指标及历史 ID 占用检查；链统计未接入旧采样器 | `legacy-capacity.uc`, `telemetry-config.uc` |
| 出厂带设备、自定义规则、节点或广告开关已启用 | 出厂节点、成员、自定义规则、FakeIP 例外均为空；四模式保留固定预设，广告规则可自行添加 | `etc/config/lanekeep`, `nodes.json`, `settings.uc` |
| 安装即工作 | 安装停用；添加节点、选择默认与保存分组不接管网络；单独确认启用才接管 | `lifecycle`, `package-install`, `activation.js` |
| 卸载一概覆盖整个 DNS 配置 | 未经外部修改时按原字节还原；有外部修改时仅恢复仍被本包占用的字段 | `dns-state.uc` |
| 升级靠强制刷新浏览器 | 所有自有模块和 CSS URL 带 LaneKeep 包版本/修订号；LuCI 自身版本不变也换资源地址 | `tools/build/materialize.py` |
| 任意设备型号已经充分验证 | 记录具体 x86_64 OpenWrt 25.12.6 虚拟机证据，不延伸为全部硬件/所有协议验收 | [验收记录](acceptance.md) |

上述核心辅助程序均位于 `root/usr/libexec/lanekeep-panel/` 或 `root/usr/libexec/lanekeep-xray/`。技术核对覆盖 README 和防泄漏文档所有功能性断言；许可、安装、升级、卸载与贡献章节也已补全。

说明补充：健康探测域名仅供内部探测，客户端查询会被显式拒绝；验收普通 DNS 使用普通示例域名。演示截图中的广告规则是演示状态，不代表出厂默认启用。

新增的生命周期、网络发现、卸载和缓存版本隔离属于本次打包实现；它们并非旧版本已有能力。本目录中的测试证据区分源代码核对、受控环境实测和未验证范围。

卸载依赖说明已按 APK 实测修正：包管理器可以自动清理不再需要的依赖；不承诺所有依赖都留下。测试环境曾因构建工具和独立夹具持有已删除的 Xray 二进制耗尽小磁盘，清理测试工具后最终包重装通过。
