'require baseclass';
'use strict';
// Fixed UI literals only. Backend messages bypass this module.
var exported = {
 "校验节点": [
  "检查改动",
  "Review changes"
 ],
 "（原有组合）": [
  "（已验证）",
  "(Verified)"
 ],
 "（未验证试用）": [
  "实验性",
  "Experimental"
 ],
 "（用户确认验证通过）": [
  "（已验证）",
  "(Verified)"
 ],
 "（未经真实服务端验收）": [
  "（开发中，暂不可用）",
  "(In development)"
 ],
 "（待验证）": [
  "（待验证）",
  "(Pending verification)"
 ],
 "安全 / 传输组合": [
  "安全 / 传输方式",
  "Security / transport"
 ],
 "未声明": [
  "不要求",
  "Not required"
 ],
 "要求 X25519MLKEM768": [
  "要求 X25519MLKEM768",
  "Require X25519MLKEM768"
 ],
 "不设置": [
  "不设置",
  "None"
 ],
 "未设置": [
  "未设置",
  "Not set"
 ],
 " 同时清除已保存的用户名和密码，改为无认证": [
  "清除已保存的用户名和密码（改为无认证）",
  "Clear saved username and password (no authentication)"
 ],
 "未验证试用：保存前须勾选确认，不能设为默认节点。": [
  "实验性组合：保存前需勾选确认，且不能设为默认节点。",
  "Experimental: tick the confirmation before saving. It can’t be the default node."
 ],
 "此组合尚未经真实服务端验收。": [
  "这个组合还没有在真实服务器上测过。",
  "This combination hasn’t been tested against a real server."
 ],
 "候选功能已编写，必要测试尚未完成；当前不能保存或应用。": [
  "这个组合还在开发中，暂时不能保存。",
  "This combination is still in development and can’t be saved yet."
 ],
 "可在未验证试用确认后用于规则、兜底、专用入口或链后置，也可单独测试；不能设为默认节点或链前置。": [
  "实验性节点可以用于规则、兜底出口、专用代理端口，或作两跳链的后置，也可以单独测试；不能设为默认节点，也不能作前置。",
  "Experimental nodes can be used in rules, as a fallback, on a dedicated proxy port or as a chain’s exit hop, and can be tested on their own. They can’t be the default node or an entry hop."
 ],
 "路径中的 ed 会由固定核心解释为早期数据参数；对应握手仍需单独验证。": [
  "路径里的 ed= 会被当作 early data 参数，这种握手还没有验证过。",
  "ed= in the path is treated as an early-data parameter. This handshake hasn’t been verified yet."
 ],
 "编辑节点": [
  "编辑节点",
  "Edit node"
 ],
 "新增节点": [
  "新增节点",
  "Add node"
 ],
 "凭据不从服务器回填。切换组合会清空本次凭据输入；已有节点的协议类型保持。": [
  "已保存的密钥不会显示，编辑时留空表示不改。切换组合会清空本次填写的密钥。",
  "Saved secrets are never shown; leave them blank when editing to keep them. Switching combination clears what you’ve typed."
 ],
 "协议": [
  "协议",
  "Protocol"
 ],
 "取消": [
  "取消",
  "Cancel"
 ],
 "链承载实际命中它的 TCP。UDP 默认关闭；未验证试用开启前须确认 SOCKS5 服务商支持并勾选试用确认；实际出口和故障阻断仍需测试。HTTP 后置不提供 UDP。": [
  "链只承载分到它的 TCP 流量。UDP 默认关闭，开启前先确认后置服务商支持；HTTP 后置不支持 UDP。",
  "A chain carries only the TCP traffic routed to it. UDP is off by default; check that your exit provider supports it first. HTTP exits cannot carry UDP."
 ],
 "前置到后置的 SOCKS5 / HTTP 握手没有额外 TLS，前置端可接触后置认证信息和目标；HTTPS 内容仍由端到端 TLS 保护。": [
  "前置到后置的握手没有额外加密，前置服务商能看到后置的账号和目标地址。HTTPS 内容本身仍是端到端加密。",
  "The entry-to-exit handshake has no extra encryption, so the entry provider can see the exit credentials and destinations. HTTPS content stays end-to-end encrypted."
 ],
 "默认节点门控关闭时，链数据也被阻断。原 UDP 443、DNS 和其他保护继续生效；未命中链的流量仍按原规则处理。": [
  "断线保护触发时，两跳链也会被阻断。UDP 443、DNS 等原有保护照常生效；没分到链的流量按原规则走。",
  "When the kill switch trips, chains are blocked too. Existing protections such as UDP 443 and DNS stay in force; traffic not routed to a chain follows its usual rules."
 ],
 "名称": [
  "名称",
  "Name"
 ],
 "参数已变化，原测试结果失效；可以重新测试或确认未验证试用。": [
  "参数改了，之前的测试结果作废。请重新测试，或按实验性保存。",
  "Settings changed, so the earlier test result no longer applies. Test again, or save as experimental."
 ],
 "校验链": [
  "检查改动",
  "Review changes"
 ],
 "UDP 测试已过期，请重新测试。": [
  "UDP 测试结果已过期，请重新测试。",
  "The UDP test result has expired. Test again."
 ],
 "请选择前置": [
  "选择前置节点",
  "Choose an entry hop"
 ],
 "（链能力待验证）": [
  "（待验证）",
  "(Pending verification)"
 ],
 "原前置（当前不可用）": [
  "原前置节点（现在不可用）",
  "Previous entry hop (unavailable)"
 ],
 "前置": [
  "前置",
  "Entry hop"
 ],
 "请选择 SOCKS5 / HTTP 后置": [
  "选择后置节点（SOCKS5 或 HTTP）",
  "Choose an exit hop (SOCKS5 or HTTP)"
 ],
 "（组合待验证）": [
  "（待验证）",
  "(Pending verification)"
 ],
 "原后置（当前组合不可用）": [
  "原后置节点（现在不可用）",
  "Previous exit hop (unavailable)"
 ],
 "后置": [
  "后置节点",
  "Exit hop"
 ],
 "预期后置公网 IPv4": [
  "后置的预期出口 IP（IPv4）",
  "Expected exit IP of the exit hop (IPv4)"
 ],
 "UDP 出口约束": [
  "UDP 出口要求",
  "UDP exit requirement"
 ],
 "链式 UDP": [
  "两跳链 UDP",
  "Chain UDP"
 ],
 "测试此链 TCP / UDP": [
  "测试 TCP 和 UDP",
  "Test TCP and UDP"
 ],
 "先测试前置和整链 TCP，再测试 UDP DNS 与 STUN；不会自动应用。": [
  "先测前置和整条链的 TCP，再用 DNS 和 STUN 测 UDP。测试不会改动配置。",
  "Tests TCP on the entry hop and the whole chain, then UDP via DNS and STUN. Testing doesn’t change any settings."
 ],
 "本次 TCP / UDP 出口符合约束。不会自动升级状态；可以另行确认验证通过，也可继续未验证试用。": [
  "TCP 和 UDP 出口都符合要求。可以标记为已验证，也可以继续按实验性使用。",
  "TCP and UDP exits both match. You can mark it as verified or keep using it as experimental."
 ],
 "确认验证通过": [
  "标记为已验证",
  "Mark as verified"
 ],
 "未完成测试，UDP 保持关闭。": [
  "测试没有完成，UDP 保持关闭。",
  "The test didn’t finish. UDP stays off."
 ],
 "未取得测试结果，请手动重试；未自动应用。": [
  "没有拿到测试结果，请重试。配置没有改动。",
  "No test result came back. Try again. Nothing was changed."
 ],
 "请先选择后置。": [
  "请先选择后置节点。",
  "Choose an exit hop first."
 ],
 "HTTP 后置不支持此 UDP 功能。": [
  "HTTP 后置节点不支持 UDP。",
  "HTTP exit hops can’t carry UDP."
 ],
 "请先编辑 SOCKS5 后置，明确服务商支持 UDP；声明仍需实际测试。": [
  "请先在这个 SOCKS5 后置节点的设置里注明服务商支持 UDP，再来测试。",
  "First mark in this SOCKS5 exit hop’s settings that the provider supports UDP, then test."
 ],
 "界面已准备；此组合尚未完成必要验证，暂不能发起或启用 UDP。": [
  "这个组合的 UDP 还在开发中，暂时不能测试或开启。",
  "UDP for this combination is still in development and can’t be tested or turned on yet."
 ],
 "未验证试用：可以勾选 UDP 后校验，最终应用时还须明确确认；测试仅核对本次连接及出口。": [
  "实验性：可以开启 UDP 并检查改动，应用前还要再确认一次。",
  "Experimental: you can turn on UDP and review changes; you’ll confirm once more before applying."
 ],
 "测试时填写预期后置公网 IPv4；试用启用可留空": [
  "测试时必填，用来核对出口；按实验性开启时可留空。",
  "Required for testing, to check the exit. Can be left blank when enabling as experimental."
 ],
 " 此链承载现有规则允许的 UDP": [
  "让这条链承载 UDP（按现有规则）",
  "Carry UDP over this chain (per existing rules)"
 ],
 "前后置参数、UDP 声明或能力表变化会使结果失效。关闭 UDP 后，匹配此链的 UDP 阻断；不会放行 UDP 443。": [
  "前置、后置或 UDP 设置改动后，测试结果会作废。关闭 UDP 后，分到这条链的 UDP 会被阻断，UDP 443 也不会放行。",
  "Changing the entry hop, exit hop or UDP settings invalidates the test result. With UDP off, UDP routed to this chain is blocked, and UDP 443 is never let through."
 ],
 "未验证试用：保存前须后端校验并勾选确认；链不能作为默认节点。": [
  "实验性：保存前需勾选确认。两跳链不能设为默认节点。",
  "Experimental: tick the confirmation before saving. A chain can’t be the default node."
 ],
 "链能力或所选组合尚未完成必要验证；可查看表单，当前不能保存。": [
  "这个组合还在开发中，暂时不能保存。",
  "This combination is still in development and can’t be saved yet."
 ],
 "编辑两跳链": [
  "编辑两跳链",
  "Edit chain"
 ],
 "新增两跳链": [
  "新增两跳链",
  "Add chain"
 ],
 "链不能设为默认，不能嵌套；前后置按内部 ID 引用。": [
  "两跳链不能设为默认节点，也不能再套一层链。",
  "A chain can’t be the default node and can’t contain another chain."
 ],
 "快速创建后置": [
  "新建后置节点",
  "New exit hop"
 ],
 "快速创建后置使用完整节点校验与确认流程；保存后重新打开链表单选择。": [
  "新的后置节点要单独保存，保存后重新打开这个窗口就能选到。",
  "A new exit hop is saved separately. Reopen this dialog afterwards to pick it."
 ],
 "已有任务进行中或结果待确认，请先处理该任务。": [
  "还有一项操作没完成，请先处理完。",
  "Another action is still in progress. Finish it first."
 ],
 "未测试": [
  "未测试",
  "Not tested"
 ],
 "TCP / UDP 出口符合约束": [
  "TCP 和 UDP 出口符合要求",
  "TCP and UDP exits match"
 ],
 "UDP 未通过或出口约束不匹配": [
  "UDP 不通，或出口不符合要求",
  "UDP failed, or the exit doesn’t match"
 ],
 "未发起": [
  "未测",
  "Not run"
 ],
 "连接失败": [
  "连接失败",
  "Connection failed"
 ],
 "整链": [
  "整条链",
  "Whole chain"
 ],
 "测试失败": [
  "测试失败",
  "Test failed"
 ],
 "节点校验未通过": [
  "检查没有通过",
  "Check failed"
 ],
 " 此候选使用新版节点格式，回退时需要配套恢复代码和数据。": [
  "这次改动用到新版节点格式。以后要撤销的话，需要连同 LaneKeep 程序一起回退。",
  "This change uses the new node format. Undoing it later also means rolling back LaneKeep itself."
 ],
 "请确认节点改动；凭据仅保存在路由器私有文件中。": [
  "确认节点改动｜密钥只保存在路由器本机。",
  "Confirm node changes | Secrets are stored only on the router."
 ],
 "未取得校验结果，未发送应用。": [
  "没有拿到检查结果，什么都没改。",
  "No check result came back. Nothing was changed."
 ],
 "spiderX": [
  "spiderX",
  "spiderX"
 ],
 "服务器地址": [
  "服务器地址",
  "Server"
 ],
 "端口": [
  "端口",
  "Port"
 ],
 "TLS / REALITY SNI": [
  "SNI",
  "SNI"
 ],
 "UUID": [
  "UUID",
  "UUID"
 ],
 "Flow（xtls-rprx-vision 或 xtls-rprx-vision-udp443）": [
  "Flow",
  "Flow"
 ],
 "指纹": [
  "TLS 指纹",
  "TLS fingerprint"
 ],
 "REALITY 公钥": [
  "REALITY 公钥",
  "REALITY public key"
 ],
 "Short ID": [
  "Short ID",
  "Short ID"
 ],
 "ML-DSA-65 验证值": [
  "ML-DSA-65 验证值",
  "ML-DSA-65 verify value"
 ],
 "REALITY 路径（spx，可留空；最多256字符）": [
  "REALITY 路径（spx，可留空）",
  "REALITY path (spx, optional)"
 ],
 "HY2 认证密码": [
  "HY2 密码",
  "HY2 password"
 ],
 "ALPN（逗号分隔；可留空）": [
  "ALPN（逗号分隔，可留空）",
  "ALPN (comma-separated, optional)"
 ],
 "此固定版本候选不接受 HY2 混淆参数；带混淆的链接将明确拒绝。": [
  "暂不支持 HY2 混淆（obfs），带混淆参数的链接会被拒绝。",
  "HY2 obfuscation (obfs) isn’t supported yet; links that use it are rejected."
 ],
 "未声明兼容要求": [
  "不要求",
  "Not required"
 ],
 "要求 X25519MLKEM768 兼容": [
  "要求 X25519MLKEM768",
  "Require X25519MLKEM768"
 ],
 "链接兼容提示": [
  "ML-KEM 兼容要求",
  "ML-KEM requirement"
 ],
 "此提示不会自动改变指纹；未完成对应验证时不能保存该要求。": [
  "这一项不会改动 TLS 指纹。相关验证完成前，不能保存为“要求”。",
  "This doesn’t change the TLS fingerprint. Until it’s verified, it can’t be saved as required."
 ],
 "现存参数要求跳过 TLS 验证，此固定版本不支持；保存会明确拒绝，不会静默忽略。": [
  "这个节点设置了跳过证书验证，LaneKeep 不支持。保存时会报错，不会悄悄忽略。",
  "This node is set to skip certificate verification, which LaneKeep doesn’t support. Saving will fail rather than silently ignore it."
 ],
 "此固定版本仅接受验证 TLS 证书；带 insecure=1 的链接将明确拒绝。": [
  "只接受验证证书的连接，带 insecure=1 的链接会被拒绝。",
  "Only connections that verify certificates are accepted; links with insecure=1 are rejected."
 ],
 "凭据不会从服务器回填。编辑时秘密字段留空表示不改；短凭据全部掩码。所有保存均先校验，再由你确认应用。": [
  "已保存的密钥不会显示，编辑时留空表示不改。切换组合会清空本次填写的密钥。",
  "Saved secrets are never shown; leave them blank when editing to keep them. Switching combination clears what you’ve typed."
 ],
 "此节点关联订阅来源；编辑连接不会自动同步订阅。": [
  "这个节点来自订阅。在这里修改不会自动同步到订阅。",
  "This node comes from a subscription. Edits here aren’t synced with the subscription."
 ],
 "请确认两跳依赖及 UDP 开关；原有保护保持。": [
  "确认两跳链的前置、后置和 UDP 设置。原有保护不变。",
  "Confirm the chain’s entry hop, exit hop and UDP settings. Existing protections stay as they are."
 ],
 "请先确认保存后置，再重新打开链表单。": [
  "请先保存后置节点，再重新打开这个窗口。",
  "Save the exit hop first, then reopen this dialog."
 ],
 "按名称筛选": [
  "按名称筛选",
  "Filter by name"
 ],
 "选择": [
  "选择",
  "Select"
 ],
 "原行号": [
  "行",
  "Line"
 ],
 "校验 / 更新字段": [
  "检查结果 / 改动",
  "Check / changes"
 ],
 "—": [
  "—",
  "—"
 ],
 "状态未知": [
  "未知",
  "Unknown"
 ],
 "预览读取失败，请重新预览。": [
  "预览加载失败，请重新预览。",
  "The preview failed to load. Preview again."
 ],
 "选择要导入或更新的节点": [
  "选择要导入或更新的节点",
  "Choose nodes to import or update"
 ],
 "尚未保存节点。": [
  "还没有保存任何节点。",
  "No nodes have been saved yet."
 ],
 "预览有效期20分钟；来源、缓存、节点、能力表或会话变化后必须重新预览。": [
  "预览 20 分钟内有效；期间有任何改动都需要重新预览。",
  "The preview is valid for 20 minutes; any change in between means previewing again."
 ],
 "筛选": [
  "筛选",
  "Filter"
 ],
 "上一页": [
  "上一页",
  "Previous"
 ],
 "下一页": [
  "下一页",
  "Next"
 ],
 "选择当前筛选结果": [
  "全选筛选结果",
  "Select all results"
 ],
 "超过21个可选条目，请缩小筛选。": [
  "超过 21 条，请缩小筛选范围。",
  "More than 21 results. Narrow the filter."
 ],
 "清空选择": [
  "清空选择",
  "Clear selection"
 ],
 "校验所选节点": [
  "检查所选节点",
  "Review selected"
 ],
 "请选择1–21条通过校验的节点。": [
  "请选择 1 到 21 个通过检查的节点。",
  "Select 1–21 nodes that passed the check."
 ],
 "所选新增或更新已形成候选，请核对摘要后再确认应用。": [
  "核对下面的改动摘要，确认后才会应用。",
  "Review the summary below. Nothing is applied until you confirm."
 ],
 "标准分享链接 / 订阅": [
  "分享链接或订阅",
  "Share link or subscription"
 ],
 "SOCKS5 快速粘贴": [
  "SOCKS5 快速粘贴",
  "SOCKS5 quick paste"
 ],
 "HTTP 快速粘贴": [
  "HTTP 快速粘贴",
  "HTTP quick paste"
 ],
 "导入节点": [
  "导入节点",
  "Import nodes"
 ],
 "支持候选格式：VLESS、VMess、Trojan、Shadowsocks、HY2、SOCKS5 和 HTTP。也可粘贴 Base64 链接列表；新增组合待验证。": [
  "支持 VLESS、VMess、Trojan、Shadowsocks、HY2、SOCKS5、HTTP 链接，也支持 Base64 编码的链接列表。",
  "Supports VLESS, VMess, Trojan, Shadowsocks, HY2, SOCKS5 and HTTP links, and Base64-encoded link lists."
 ],
 "快速粘贴需先选协议，格式为 host:port:user:pass；凭据分隔有歧义时使用 URL 百分号编码或分字段填写。": [
  "格式：host:port:user:pass。用户名或密码里有冒号时，请用百分号编码，或改用“新增节点”逐项填写。",
  "Format: host:port:user:pass. If the username or password contains a colon, percent-encode it or use Add node instead."
 ],
 "链接或订阅文本": [
  "链接或订阅内容",
  "Links or subscription content"
 ],
 "HTTPS 订阅地址（不回显、不保存到日志）": [
  "HTTPS 订阅地址",
  "HTTPS subscription URL"
 ],
 "先逐条预览，再选择导入。一次性订阅通过默认节点安全拉取；需要重复刷新时请保存订阅来源。未知参数只指出参数名。": [
  "先预览，再选择导入哪些。这里只拉取一次，经默认节点；需要定期刷新的，请在“订阅”里添加。",
  "Preview first, then pick what to import. This fetches once, via the default node; to refresh regularly, add it under Subscriptions."
 ],
 "解析并预览": [
  "预览",
  "Preview"
 ],
 "链接文本与 HTTPS 订阅地址，请只填其中一项。": [
  "链接内容和订阅地址只填一个。",
  "Fill in either links or a subscription URL, not both."
 ],
 "预览未完成": [
  "预览没有完成",
  "The preview didn’t finish"
 ],
 "未取得预览结果，请稍后重新预览；尚未保存节点。": [
  "没有拿到预览结果，请稍后重试。没有保存任何节点。",
  "No preview result came back. Try again later. No nodes were saved."
 ],
 "解除来源关联": [
  "解除订阅关联",
  "Unlink from subscription"
 ],
 "校验解除关联": [
  "检查改动",
  "Review changes"
 ],
 "请确认仅解除此节点的订阅来源关联。": [
  "确认只解除这个节点和订阅的关联？",
  "Unlink only this node from its subscription?"
 ],
 "删除节点": [
  "删除节点",
  "Delete node"
 ],
 "校验删除": [
  "检查改动",
  "Review changes"
 ],
 "节点临时连接测试：先前置、再整链，单步限时约10秒……": [
  "正在测试：先测前置，再测整条链……",
  "Testing: entry hop first, then the whole chain…"
 ],
 "正在测试一次，限时10秒……": [
  "正在测试……",
  "Testing…"
 ],
 "未取得测试结果；不自动重试。": [
  "没有拿到测试结果。",
  "No test result came back."
 ],
 "测试前置和整链": [
  "开始测试",
  "Run test"
 ],
 "通过前置测试后置": [
  "经前置节点测试",
  "Test via an entry hop"
 ],
 "不会直接连接后置。先测所选前置，再测两跳；出口 IP 只作辅助证据。": [
  "后置节点不能单独测，要经过一个前置节点：先测前置，再测整条链。",
  "An exit hop can’t be tested on its own. It goes through an entry hop: the entry hop is tested first, then the whole chain."
 ],
 "未知（原节点无成功测试）": [
  "未知（从未测通）",
  "Unknown (never reached)"
 ],
 "未知（目标测试未成功）": [
  "未知（测试没通过）",
  "Unknown (test failed)"
 ],
 "未知": [
  "未知",
  "Unknown"
 ],
 "目标节点测试完成": [
  "测试通过",
  "Test passed"
 ],
 "该节点也不通": [
  "这个节点也连不上",
  "This node is unreachable too"
 ],
 "下一步先校验切换草稿，之后再次确认重启影响。": [
  "检查通过后还要再确认一次才会生效。",
  "After the check you confirm once more before it takes effect."
 ],
 "该节点也不通或测试结果未知。仍可继续校验，随后需再次确认才会切换；应用后门控不能开放会自动退回。": [
  "这个节点没有测通。仍可以继续，但如果切换后断线保护仍是触发状态，会自动换回原节点。",
  "This node didn’t pass the test. You can still continue; if the kill switch is still triggered after switching, LaneKeep switches back automatically."
 ],
 "切换将重启核心，全家预计断网约10秒（估计）。最多等待60秒门控 OPEN；失败回退可能再重启。原节点也不通时，代理流量继续阻断。": [
  "应用时代理核心会重启，网络会中断约 10 秒。如果 60 秒内断线保护没有恢复待命，会自动换回原节点。",
  "Applying restarts the proxy core and drops connections for about 10 seconds. If the kill switch is not back to standby within 60 seconds, LaneKeep switches back to the previous node."
 ],
 "继续校验切换": [
  "检查改动",
  "Review changes"
 ],
 "测试未成功，仍继续校验": [
  "没测通，仍然继续",
  "Continue anyway"
 ],
 "未采集：统计字节容量待验证": [
  "暂无流量统计",
  "No traffic stats yet"
 ],
 "未采集：统计容量已满": [
  "统计容量已满，这个节点不显示流量",
  "Stats capacity is full; traffic not shown for this node"
 ],
 "设为默认": [
  "设为默认",
  "Set as default"
 ],
 "选择前置测试": [
  "经前置测试",
  "Test via entry"
 ],
 "测试": [
  "测试",
  "Test"
 ],
 "删除": [
  "删除",
  "Delete"
 ],
 "默认节点": [
  "经默认节点拉取",
  "fetched via default node"
 ],
 "两跳链 · TCP / UDP": [
  "TCP 和 UDP",
  "TCP and UDP"
 ],
 "两跳链 · TCP": [
  "仅 TCP",
  "TCP only"
 ],
 "默认": [
  "默认",
  "Default"
 ],
 "待验证，未启用": [
  "未启用",
  "Not enabled"
 ],
 "未验证试用": [
  "实验性",
  "Experimental"
 ],
 "用户已确认验证": [
  "已验证",
  "Verified"
 ],
 "未使用": [
  "未使用",
  "Not in use"
 ],
 "编辑": [
  "编辑",
  "Edit"
 ],
 "UDP 设置 / 测试": [
  "UDP 设置",
  "UDP settings"
 ],
 "默认节点不能删除": [
  "默认节点不能删除",
  "The default node cannot be deleted"
 ],
 "被引用，不能删除": [
  "正被使用，不能删除",
  "In use, cannot be deleted"
 ],
 "被谁使用": [
  "用于",
  "Used by"
 ],
 "最近测试（US / CN）": [
  "最近测试",
  "Last test"
 ],
 "节点": [
  "节点",
  "Nodes"
 ],
 "面板包试用最多21个节点（含链）；旧采样器上限96指标，已删除编号仍可能占用。链流量不统计，新增是否允许以当前剩余额度为准。": [
  "最多 21 个节点，两跳链也算在内。",
  "Up to 21 nodes, chains included."
 ],
 "仅在家中 LAN 手动切换，不自动测试或自动切换。备用节点实际出口以测试为准；切换可能改变网站看到的 IP。": [
  "面板不会自动切换节点，需要你在这里手动换默认节点。换了以后，网站看到的 IP 会变。",
  "LaneKeep never switches nodes by itself. Change the default node here; sites will then see a different IP."
 ],
 "健康探测跟随默认节点。默认节点不通时门控关闭，所有代理流量（含指定其他节点的规则）都会阻断。请在此手动切换默认节点；国内业务还依赖核心和 DNS 状态，不承诺故障期间一直可用。": [
  "默认节点「演示节点 01」可用。它连不上时，所有走代理的流量都会被阻断，不会改走直连。",
  "Default node “Demo node 01” is reachable. If it goes down, all proxied traffic is blocked and nothing falls back to direct."
 ],
 "测试仅在点击后发起；普通节点一次小请求，链按前置、整链顺序各一次，单步约10秒。临时回环入口不会修改主核心配置；测试成功不证明生产门控或全部设备验收通过。": [
  "只在你点击时测试。普通节点发一次小请求；两跳链先测前置、再测整条链，每步约 10 秒。测试走临时通道，不改动正在运行的配置。测试通过只说明这一次连得上。",
  "Tests run only when you click. A node gets one small request; a chain tests the entry hop first, then the whole chain, about 10 s per step. Tests use a temporary channel and leave the running config alone. A pass only means it connected this once."
 ],
 "分享链接 / 订阅导入": [
  "导入",
  "Import"
 ],
 "操作未完成": [
  "操作未完成",
  "Action not completed"
 ],
 "订阅操作未完成": [
  "操作没有完成",
  "The action didn’t finish"
 ],
 "关闭": [
  "关闭",
  "Close"
 ],
 "未取得结果；请先刷新来源状态，勿自动重试。": [
  "没有拿到结果。请先刷新订阅状态再试。",
  "No result came back. Reload the subscription status, then try again."
 ],
 "当前登录会话无权读取订阅来源，请退出 LuCI 后重新登录。": [
  "登录已失效，请重新登录。",
  "Your session has expired. Log in again."
 ],
 "当前接口未提供订阅来源方法，需要核对部署。": [
  "后台缺少订阅功能，请检查安装是否完整。",
  "The backend is missing subscription support. Check the installation."
 ],
 "面板正处理其他请求，完成后请手动读取来源状态。": [
  "正在处理其他操作，完成后再刷新订阅状态。",
  "Another action is in progress. Reload the subscription status once it finishes."
 ],
 "来源定义或缓存无法读取，现有数据已保留，请检查后台。": [
  "无法读取订阅设置或缓存，现有数据未受影响。",
  "Couldn’t read subscription settings or cache. Existing data is untouched."
 ],
 "后台未完成来源读取，现有数据已保留。": [
  "后台没有读完订阅状态，现有数据未受影响。",
  "The backend didn’t finish reading subscriptions. Existing data is untouched."
 ],
 "来源接口返回格式异常，现有数据已保留。": [
  "后台返回的数据格式不对，现有数据未受影响。",
  "The backend returned malformed data. Existing data is untouched."
 ],
 "读取来源状态超时，请稍后手动重试。": [
  "读取订阅状态超时，请稍后重试。",
  "Loading subscriptions timed out. Try again later."
 ],
 "来源接口连接失败，请检查登录和连接状态。": [
  "连不上后台，请检查登录状态和网络。",
  "Can’t reach the backend. Check your login and connection."
 ],
 "来源列表暂不可读，未显示为零条来源。": [
  "订阅列表暂时读不到（不代表没有订阅）。",
  "Can’t load subscriptions right now (this doesn’t mean there are none)."
 ],
 "v2rayN": [
  "v2rayN",
  "v2rayN"
 ],
 "我明确选择此来源直连：订阅服务器看到的来源 IP 会改变，解析使用路由器现有系统路径。": [
  "我确认这个订阅走直连：订阅服务商会看到我家的真实 IP，域名解析走路由器系统 DNS。",
  "I confirm this subscription is fetched directly: the provider will see my home IP, and DNS goes through the router’s system resolver."
 ],
 "经当前默认节点": [
  "经默认节点",
  "Via default node"
 ],
 "直连（单独确认）": [
  "直连（需确认）",
  "Direct (needs confirmation)"
 ],
 "编辑订阅来源": [
  "编辑订阅",
  "Edit subscription"
 ],
 "新增订阅来源": [
  "新增订阅",
  "Add subscription"
 ],
 "保存来源只修改来源定义；刷新由你手动触发。URL 留空表示保持已保存值。": [
  "保存只改订阅设置，不会拉取。地址留空则保持原值。",
  "Saving only changes the settings; nothing is fetched. Leave the URL blank to keep it."
 ],
 "HTTPS 订阅 URL": [
  "HTTPS 订阅地址",
  "HTTPS subscription URL"
 ],
 "User-Agent": [
  "User-Agent",
  "User-Agent"
 ],
 "拉取通道": [
  "拉取方式",
  "Fetch via"
 ],
 "代理失败不会自动直连。缓存位于内存，重启后需手动刷新；已导入节点继续保留。": [
  "经节点拉取失败时，不会改走直连。",
  "If fetching via a node fails, it never falls back to direct."
 ],
 "保存来源": [
  "保存",
  "Save"
 ],
 "删除订阅来源": [
  "删除订阅",
  "Delete subscription"
 ],
 "删除来源定义和该来源缓存；已导入节点保留。此操作不会改规则或代理配置。": [
  "删除这个订阅和它的缓存。已导入的节点、规则和代理设置都不受影响。",
  "Deletes this subscription and its cache. Imported nodes, rules and proxy settings are not affected."
 ],
 "确认删除来源": [
  "删除",
  "Delete"
 ],
 "手动刷新订阅": [
  "刷新订阅",
  "Refresh subscription"
 ],
 "直连": [
  "直连拉取",
  "fetched directly"
 ],
 "当前默认节点": [
  "默认节点",
  "the default node"
 ],
 "开始刷新": [
  "刷新",
  "Refresh"
 ],
 "可选名称前缀": [
  "名称前缀（可选）",
  "Name prefix (optional)"
 ],
 "状态": [
  "状态",
  "Status"
 ],
 "更新目标": [
  "更新到",
  "Update into"
 ],
 "作为新增节点": [
  "新增为节点",
  "Add as new node"
 ],
 "订阅差异与选择": [
  "查看并选择",
  "Review and pick"
 ],
 "新增、更新都需要下一步预览和确认；已消失的节点不会自动删除。同名条目须明确指定更新目标。": [
  "选好后还要预览、确认才会生效。订阅里已经没有的节点不会被自动删除；同名的条目需要手动指定更新哪个节点。",
  "Picks take effect only after preview and confirmation. Nodes gone from the subscription are never deleted automatically; for duplicate names, choose which node to update."
 ],
 "当前筛选超过21个可选条目，请缩小筛选或分批选择。": [
  "超过 21 条，请缩小筛选范围。",
  "More than 21 results. Narrow the filter."
 ],
 "新节点名称前缀（可选，最多32 UTF-8字节）": [
  "名称前缀（可选）",
  "Name prefix (optional)"
 ],
 "预览所选节点": [
  "预览所选",
  "Preview selected"
 ],
 "请选择1–21条。": [
  "请选择 1 到 21 条。",
  "Select 1–21 items."
 ],
 "预览未完成，尚未修改节点。": [
  "预览没有完成，节点没有改动。",
  "The preview didn’t finish. No nodes were changed."
 ],
 "刷新": [
  "刷新",
  "Refresh"
 ],
 "差异 / 选择": [
  "查看并选择",
  "Review and pick"
 ],
 "upload": [
  "已用上传",
  "Uploaded"
 ],
 "download": [
  "已用下载",
  "Downloaded"
 ],
 "total": [
  "总流量",
  "Total"
 ],
 "expire": [
  "到期",
  "Expires"
 ],
 "尚无成功缓存": [
  "还没有拉取成功过",
  "Never fetched successfully"
 ],
 "正在读取来源状态…": [
  "正在读取订阅……",
  "Loading subscriptions…"
 ],
 "读取来源状态": [
  "重新读取",
  "Reload"
 ],
 "订阅来源": [
  "订阅",
  "Subscriptions"
 ],
 "未验证试用：每次修改或刷新须勾选确认。只手动刷新；刷新不会改节点或规则。重启后缓存需重建，已导入节点保留。": [
  "只在你点击时刷新。刷新不会改动已有的节点和规则。",
  "Refreshes only when you click. Refreshing never changes existing nodes or rules."
 ],
 "订阅来源功能的固定版本验证尚未完成，当前不开放写入或拉取。": [
  "订阅功能还在开发中，暂时不能添加或刷新。",
  "Subscriptions are still in development and can’t be added or refreshed yet."
 ],
 "尚未添加订阅来源。": [
  "还没有订阅。",
  "No subscriptions yet."
 ],
 "来源状态已读取。": [
  "订阅状态已更新",
  "Subscriptions updated"
 ],
 "": [
  "高级设置",
  "Advanced"
 ],
 "本次将拉取订阅并生成导入预览。": [
  "本次将拉取订阅并生成导入预览。",
  "Fetch the subscription and prepare an import preview."
 ],
 "本次手动刷新订阅缓存。": [
  "本次手动刷新订阅缓存。",
  "Refresh this subscription’s cache."
 ],
 "本次修改订阅来源。": [
  "本次修改订阅来源。",
  "Change this subscription."
 ],
 "本次只测试所选节点或两跳链；成功不会自动升级验证状态。": [
  "本次只测试所选节点或两跳链；成功不会自动升级验证状态。",
  "Test the selected node or chain. Success does not automatically mark it as verified."
 ],
 "超时": [
  "超时",
  "Timed out"
 ],
 "旧测量结果，请重新测试": [
  "旧测量结果，请重新测试",
  "Older measurement; test again"
 ],
 "请求耗时 ": [
  "请求耗时 ",
  "Request time: "
 ],
 " 毫秒": [
  " 毫秒",
  " ms"
 ],
 "耗时未取得": [
  "耗时未取得",
  "Duration unavailable"
 ],
 "校验未通过，尚未应用：": [
  "校验未通过，尚未应用：",
  "Review failed; nothing was applied:"
 ],
 "配置版本": [
  "配置版本",
  "Configuration revision"
 ],
 "改动类型": [
  "改动类型",
  "Change type"
 ],
 "版本编号": [
  "版本编号",
  "History ID"
 ],
 "任务编号": [
  "任务编号",
  "Task ID"
 ],
 "输入无效": [
  "输入无效",
  "Invalid input"
 ],
 "确认未验证试用": [
  "确认按实验性使用",
  "Continue as experimental"
 ],
 " 我确认进行未验证试用": [
  " 我确认使用这项实验性功能",
  " I agree to use this experimental feature"
 ],
 "已取消未验证试用操作": [
  "已取消未验证试用操作",
  "Experimental action cancelled"
 ],
 "确认未提交，请重新测试": [
  "确认未提交，请重新测试",
  "Confirmation was not submitted. Test again."
 ],
 "确认结果未知，请刷新读取状态；未自动重试。": [
  "确认结果未知，请刷新读取状态；未自动重试。",
  "Confirmation result unknown. Refresh to check; it was not retried."
 ],
 "由你确认验证结果": [
  "由你确认验证结果",
  "Confirm verification"
 ],
 " 我已核对真实节点的测试结果，确认验证通过": [
  " 我已核对真实节点的测试结果，确认验证通过",
  " I checked the real node’s test result and confirm it is verified"
 ],
 "暂不确认": [
  "暂不确认",
  "Not now"
 ],
 "新增：": [
  "新增：",
  "Added: "
 ],
 "删除：": [
  "删除：",
  "Deleted: "
 ],
 "修改：": [
  "修改：",
  "Changed: "
 ],
 "；改为 ": [
  "；改为 ",
  "; after: "
 ],
 "备注：": [
  "备注：",
  "Notes: "
 ],
 "节点：": [
  "节点：",
  "Node: "
 ],
 "受影响链：": [
  "受影响链：",
  "Affected chain: "
 ],
 "；变更字段：": [
  "；变更字段：",
  "; changed fields: "
 ],
 "UDP 失效：": [
  "UDP 失效：",
  "UDP invalidated: "
 ],
 "默认节点：": [
  "默认节点：",
  "Default node: "
 ],
 "应用已结束": [
  "应用已结束",
  "Apply completed"
 ],
 "应用结果": [
  "应用结果",
  "Apply result"
 ],
 "请根据状态页核对结果。": [
  "请根据状态页核对结果。",
  "Check the Status page to verify the result."
 ],
 "关闭并刷新": [
  "关闭并刷新",
  "Close and refresh"
 ],
 "任务仍待确认": [
  "任务仍待确认",
  "Task result pending"
 ],
 "查询任务状态": [
  "查询任务状态",
  "Check task status"
 ],
 "暂时无法取得结果": [
  "暂时无法取得结果",
  "Result unavailable"
 ],
 "已有任务未确认。请先查询该任务状态。": [
  "已有任务未确认。请先查询该任务状态。",
  "A task is still pending. Check its status first."
 ],
 "正在应用": [
  "正在应用",
  "Applying"
 ],
 "应用未开始，请重新校验草稿。": [
  "应用未开始，请重新校验草稿。",
  "Apply did not start. Review the changes again."
 ],
 "校验失败，未生成可应用草稿。": [
  "校验失败，未生成可应用草稿。",
  "Review failed; no applicable draft was created."
 ],
 "改动类型与影响说明不一致，未发送应用。": [
  "改动类型与影响说明不一致，未发送应用。",
  "The change type and impact do not match. Nothing was applied."
 ],
 "草稿与当前配置相同，无需应用。": [
  "草稿与当前配置相同，无需应用。",
  "The draft matches the current settings. Nothing to apply."
 ],
 "确认以下实际改动：": [
  "确认以下实际改动：",
  "Confirm these changes:"
 ],
 "确认重启核心并应用": [
  "确认重启核心并应用",
  "Apply and restart"
 ],
 "确认应用": [
  "确认应用",
  "Apply changes"
 ],
 " 我确认使用未验证试用功能": [
  " 我确认使用实验性功能",
  " I agree to use experimental features"
 ],
 "校验通过，请确认影响": [
  "校验通过，请确认影响",
  "Review passed — confirm changes"
 ],
 "草稿校验失败": [
  "草稿校验失败",
  "Review failed"
 ],
 "查询原任务状态": [
  "查询原任务状态",
  "Check original task"
 ],
 "规则已应用": [
  "规则已应用",
  "Rules applied"
 ],
 "分组已应用": [
  "分组已应用",
  "Modes applied"
 ],
 "配置已保存（无需重启）": [
  "配置已保存（无需重启）",
  "Settings saved (no restart)"
 ],
 "无变化": [
  "无变化",
  "No changes"
 ],
 "失败后已回退": [
  "失败后已回退",
  "Failed and rolled back"
 ],
 "分组失败后已回退": [
  "分组失败后已回退",
  "Mode changes failed and rolled back"
 ],
 "分组回退失败，需检查": [
  "分组回退失败，需检查",
  "Mode rollback failed; check the result"
 ],
 "应用失败，保持阻断": [
  "应用失败，保持阻断",
  "Apply failed; traffic remains blocked"
 ],
 "失败": [
  "失败",
  "Failed"
 ],
 "已拒绝": [
  "已拒绝",
  "Rejected"
 ],
 "进行中": [
  "进行中",
  "In progress"
 ],
 "等待执行": [
  "等待执行",
  "Queued"
 ],
 "成功": [
  "成功",
  "Succeeded"
 ],
 "已结束": [
  "已结束",
  "Finished"
 ],
 "应用前快照": [
  "应用前快照",
  "Snapshot before applying"
 ],
 "未记录": [
  "未记录",
  "Not recorded"
 ],
 "结果待核对": [
  "结果待核对",
  "Check the result"
 ],
 "真实节点、链式行为和客户端效果尚需验收；本次确认不会自动标为已验证。": [
  "真实节点、链式行为和客户端效果尚需验收；本次确认不会自动标为已验证。",
  "Real servers, chains and device behavior still need verification. This confirmation does not mark them as verified."
 ],
 "本次成功连接测试已完成。只把本次测试涉及的协议组合或具体链记录为 verified；这不代表全部服务端、防泄露或故障场景通过。": [
  "本次成功连接测试已完成。只把本次测试涉及的协议组合或具体链记录为 verified；这不代表全部服务端、防泄露或故障场景通过。",
  "This connection test succeeded. Only the tested combination or chain will be marked as verified. Other servers, leak protection and failure scenarios are not covered."
 ],
 "确认有效期为20分钟；节点、配置、能力版本或登录会话变化后须重新测试。": [
  "确认有效期为20分钟；节点、配置、能力版本或登录会话变化后须重新测试。",
  "Confirmation expires after 20 minutes. Test again if the node, settings, capabilities or login session change."
 ],
 "没有规则、分组或节点内容变化；备注等信息变化以校验结果为准。": [
  "没有规则、分组或节点内容变化；备注等信息变化以校验结果为准。",
  "No rule, mode or node changes. See the review result for notes or other metadata changes."
 ],
 "以上是本次应用任务结果。新节点实际握手、出口和终端业务需另行核对；第一轮第5步已按用户现场验收通过记录。": [
  "以上是本次应用结果。节点连接、出口和设备使用情况需要另行核对。",
  "This is the apply task result. Verify the node connection, exit and device behavior separately."
 ],
 "任务尚未给出最终结果。请查询状态，不要再次提交。": [
  "任务尚未给出最终结果。请查询状态，不要再次提交。",
  "No final result yet. Check its status instead of submitting again."
 ],
 "提交结果尚未确认。页面保留了原任务编号，请只查询状态，不要重复应用。": [
  "提交结果尚未确认。页面保留了原任务编号，请只查询状态，不要重复应用。",
  "The result is not confirmed. The original task ID is kept; check its status instead of applying again."
 ],
 "正在执行已确认的应用。网络可能暂时不可用；结果未知时只查询原任务。": [
  "正在执行已确认的应用。网络可能暂时不可用；结果未知时只查询原任务。",
  "Applying the confirmed changes. The network may be temporarily unavailable; if the result is unknown, check the original task."
 ],
 "本次将重启核心，全家网络预计中断约10秒（估计值，实际待测）。应用最多等待60秒门控 OPEN；失败自动退回可能再重启一次并等待最多60秒。若原节点也不通，代理流量仍会保持阻断。": [
  "本次将重启核心，全家网络预计中断约10秒（估计值，实际待测）。应用最多等待60秒门控 OPEN；失败自动退回可能再重启一次并等待最多60秒。若原节点也不通，代理流量仍会保持阻断。",
  "Applying will restart the proxy core, interrupting the network for about 10 seconds. It waits up to 60 seconds for the kill switch to return to standby. Rollback may restart it again; if the original node is also unreachable, proxied traffic stays blocked."
 ],
 "本次不重启核心。未使用节点或备注变动只更新保存的信息；分组变动只影响新连接。": [
  "本次不重启核心。未使用节点或备注变动只更新保存的信息；分组变动只影响新连接。",
  "The proxy core will not restart. Changes to unused nodes or notes only update saved settings; mode changes affect new connections."
 ],
 "未验证试用：节点和链的真实连通、出口及故障阻断需由你验收。": [
  "未验证试用：节点和链的真实连通、出口及故障阻断需由你验收。",
  "Experimental: verify real node and chain connections, exits and blocking on failure."
 ],
 "未取得校验结果，未发送应用。请稍后重试校验。": [
  "未取得校验结果，未发送应用。请稍后重试校验。",
  "No review result came back. Nothing was applied; try reviewing again."
 ],
 "有一项提交尚未确认结果。请先查询状态，避免重复应用。": [
  "有一项提交尚未确认结果。请先查询状态，避免重复应用。",
  "A submitted task has no confirmed result. Check its status before applying again."
 ],
 "无法读取分流管理状态。请确认管理员已登录且管理接口可用；未发送任何配置改动。": [
  "无法读取分流管理状态。请确认管理员已登录且管理接口可用；未发送任何配置改动。",
  "LaneKeep could not load. Check the administrator login and interface availability. No changes were sent."
 ]
};
// LuCI instantiates modules; keep dictionary keys as own enumerable properties.
return baseclass.extend({ __init__: function() { Object.assign(this, exported); } });
