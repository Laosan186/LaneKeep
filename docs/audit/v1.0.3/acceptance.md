# v1.0.3 发布包验收 / Release package acceptance

日期：2026-11-28。1.0.3 是补丁版本，只改一处：全局、增强、按需三条捕获链在 TPROXY 之后丢弃本组入口接不住的 TCP/UDP。本文记录：

- 修复前后在强制状态下的对照；
- 已启用实例升级到含修复的测试构建；
- `tests/target/rules-check.sh`、离线测试和 quick 套件；
- v1.0.3 APK 的构建和安装文件核对。

验收在电脑上的独立 QEMU 虚拟机进行，未连接任何实体路由器。

This report covers the one change in 1.0.3: the Global, Enhanced and On-demand capture chains drop the TCP/UDP their TPROXY rule could not deliver. It covers:

- the forced-state comparison before and after the fix;
- upgrading an enabled instance to a test build of the fix;
- `tests/target/rules-check.sh`, the offline tests and the quick suite;
- building the v1.0.3 APK and checking its installed files.

The tests ran on the isolated QEMU VM of the v1.0.2 acceptance, with **no host or internet access**.

## 环境

- 系统：OpenWrt 25.12.6 x86_64、Linux 6.12.112、Xray 26.10.21，与 v1.0.2 验收使用同一台测试机。
- 隔离：QEMU 用户网络加 `restrict=on`，客机不能访问宿主或外网，只把 SSH 转发到本机。
- 客户端：局域网上的客户端是虚拟机内的网络命名空间，地址如下。

  | 地址 | 本次角色 |
  |---|---|
  | `.101` | 全局 |
  | `.102` | 增强 |
  | `.105` | 按需 |
  | `.110` | 未分组 |

  测试机没有按需专用的命名空间，借用原先的直连客户端 `.105`，所以日志里这一组仍叫 “direct”。
- WAN 侧：模拟上游，测试 WAN 地址 `203.0.113.2`，模拟节点 `198.51.100.2`。
- 判定：
  - D：测试服务器看到了 WAN 地址；
  - P：只看到节点；
  - -：什么都没出去。

## 结果

| 步骤 | 验证结果 |
|---|---|
| 修前复现（1.0.2-r1） | 未分组=常规。停止核心，手工起一份去掉 12346、12347、12348 入口的配置，只有 12345、12349 在听。全局 `PDDD-D`，增强、按需 `-DDD-D`，与未分组对照组 `-DDD-D` 相同：这三组全部落进常规模式，按常规规则处理，多数探测以 WAN 地址直接出去。四个客户端向路由器查询 DNS，都从常规入口拿到 FakeIP。 |
| 已启用状态下升级到测试构建 | 测试构建 `1.0.2-r2` 取自提交 `7052c7c`，`RELEASE` 只在测试机里改为 2，以便走 `apk add --upgrade`。升级返回 0；升级后规则表已重新生成：三条链末尾有新的丢弃规则，`capture_phone` 不变；面板无警告（生成器指纹一致）；规则核对全部一致；门控 OPEN。 |
| 修后复现（同样条件） | 全局、增强、按需均为 `------`。三条链末尾的丢弃规则各拦下 14 个包；这三组向路由器查询 DNS 都超时。未分组对照组仍为 `PDDD-D`，DNS 拿到 FakeIP，说明探测环境有效。 |
| quick 套件 | 全局、增强都是 `PPP`，全部经节点出去。套件期间这两条链末尾的丢弃计数没有增加。 |
| 测试机检查 `tests/target` | `rules-check.sh` 全部通过，包括：<br>• 与加固提交 `aad799b` 的输出相比，只多出直连模式和这三处丢弃；<br>• 新增的三条链逐字核对（未分组=常规、未分组=直连两种生成结果）；<br>• 以 root 运行的 `nft -c`。 |
| 离线检查 | 11 项发布不变量测试通过，包括新增的“三条链为 selected、TPROXY、drop”检查。 |
| 构建 | 在测试机内用 apk-tools 3 构建 `luci-app-lanekeep-1.0.3-r1.apk`，308,972 字节，SHA256 `54480697beba49c7145a20d802cc60728a89187332fac4dad2771fb5043322ea`。构建输入取自提交 `938c2e9`，与测试构建 `7052c7c` 相比只多出 `VERSION` 和 `Makefile` 的版本号。 |
| 正式包与测试构建的载荷 | 用 `tools/build/materialize.py` 分别从 `7052c7c`（1.0.2-r2）和 `938c2e9`（1.0.3-r1）生成安装树，各 106 个文件。去掉模块路径中的版本命名空间和 `foundation.js` 里的版本字符串后，两者逐字一致。 |
| 正式包安装 | 在已停用的测试机上把 1.0.3-r1 覆盖安装到测试构建之上，`apk info -L` 列出 109 个文件：<br>• 103 个与从 `938c2e9` 生成的安装树 SHA256 相同；<br>• 3 个是 apk 数据库文件；<br>• 3 个配置文件（`/etc/config/lanekeep`、`lanekeep_runtime`、`/etc/lanekeep-proxy/nodes.json`）保留了测试机上的测试配置。<br>装上的生成器 SHA256 `896cbb13…a63df` 与 `GENERATOR_SHA` 一致。 |

机器可读结果见 [acceptance.json](acceptance.json)，各项输出见 [logs/](logs/)。日志只做了这些处理：删去测试工具的退出码行；加了各段标题；加了以 `# note:` 标明的说明行。

## 验证边界

**只用强制状态验证。** 窗口是手工造出来的：停止核心，再手工起一份去掉对应入口的配置。没有在真实的核心启动、停止或崩溃过程中抓到落进窗口的包。

**升级与正式包：**

- 从 1.0.2 升级时，升级前脚本在 1.0.2 的规则下停止核心，这一次停止仍可能有旧窗口；之后的启动已经是新规则。
- 已启用状态下的升级，测的是测试构建（1.0.2-r1 → 1.0.2-r2）。正式包 1.0.3-r1 只在停用状态下覆盖安装过，与测试构建的载荷差别只有版本标签。

**本次没有做：**

- 全局/增强 160 个用例的全量回归；
- 修后“未分组=直连”的复现。结构上包出不了本组的链；`capture_direct` 的链首丢弃在 1.0.2 验收中已测；
- 明确设为常规的成员；
- 节点故障、核心停止套件；
- 专用入口；
- 全新安装、开机、模拟固件升级、卸载。

除这三条链的末尾外，相关代码在 1.0.2 之后没有改动。

**不在本次范围内的有意直连**：按需默认直连、增强国内 TCP 直连、全局私有地址直连、用户自加的直连规则。这些是路由设计，没有改。
