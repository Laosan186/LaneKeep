'require baseclass';
'use strict';
'require lanekeep.i18n as i18n';
var entries={
 "F-70537f7aae": [
  "检查改动",
  "Review changes"
 ],
 "F-1846189b36": [
  "（已验证）",
  "(Verified)"
 ],
 "F-5a654739d9": [
  "· 实验性",
  "· Experimental"
 ],
 "F-1f2cd95728": [
  "（已验证）",
  "(Verified)"
 ],
 "F-1eba822fbb": [
  "（开发中，暂不可用）",
  "(In development)"
 ],
 "F-82c36b5059": [
  "（待验证）",
  "(Pending verification)"
 ],
 "F-1fa7f1eae6": [
  "安全 / 传输方式",
  "Security / transport"
 ],
 "F-ef524b3456": [
  "不要求",
  "Not required"
 ],
 "F-0095156c72": [
  "要求 X25519MLKEM768",
  "Require X25519MLKEM768"
 ],
 "F-8e5787ecc4": [
  "不设置",
  "None"
 ],
 "F-ad7d56cbbd": [
  "已保存：{value}。留空则不改",
  "Saved: {value}. Leave blank to keep"
 ],
 "F-182455c533": [
  "未设置",
  "Not set"
 ],
 "F-a0b276d485": [
  "清除已保存的用户名和密码（改为无认证）",
  "Clear saved username and password (no authentication)"
 ],
 "F-304403090b": [
  "实验性组合：保存前需勾选确认，且不能设为默认节点。",
  "Experimental: tick the confirmation before saving. It can’t be the default node."
 ],
 "F-bf024c30e7": [
  "这个组合还没有在真实服务器上测过。",
  "This combination hasn’t been tested against a real server."
 ],
 "F-490940a6bd": [
  "",
  ""
 ],
 "F-9cb02046db": [
  "这个组合还在开发中，暂时不能保存。",
  "This combination is still in development and can’t be saved yet."
 ],
 "F-def2f08011": [
  "实验性节点可以用于规则、兜底出口、专用代理端口，或作两跳链的后置，也可以单独测试；不能设为默认节点，也不能作前置。",
  "Experimental nodes can be used in rules, as a fallback, on a dedicated proxy port or as a chain’s exit hop, and can be tested on their own. They can’t be the default node or an entry hop."
 ],
 "F-751f41abe9": [
  "路径里的 ed= 会被当作 early data 参数，这种握手还没有验证过。",
  "ed= in the path is treated as an early-data parameter. This handshake hasn’t been verified yet."
 ],
 "F-baef1797f5": [
  "编辑节点",
  "Edit node"
 ],
 "F-8d11489f54": [
  "新增节点",
  "Add node"
 ],
 "F-28a1fff32a": [
  "已保存的密钥不会显示，编辑时留空表示不改。切换组合会清空本次填写的密钥。",
  "Saved secrets are never shown; leave them blank when editing to keep them. Switching combination clears what you’ve typed."
 ],
 "F-49dc937d49": [
  "协议",
  "Protocol"
 ],
 "F-fa8a73f9ad": [
  "取消",
  "Cancel"
 ],
 "F-6329d6fd7f": [
  "链只承载分到它的 TCP 流量。UDP 默认关闭，开启前先确认后置服务商支持；HTTP 后置不支持 UDP。",
  "A chain carries only the TCP traffic routed to it. UDP is off by default; check that your exit provider supports it first. HTTP exits cannot carry UDP."
 ],
 "F-6ae745f359": [
  "前置到后置的握手没有额外加密，前置服务商能看到后置的账号和目标地址。HTTPS 内容本身仍是端到端加密。",
  "The entry-to-exit handshake has no extra encryption, so the entry provider can see the exit credentials and destinations. HTTPS content stays end-to-end encrypted."
 ],
 "F-0454c8ab2f": [
  "断线保护触发时，两跳链也会被阻断。UDP 443、DNS 等原有保护照常生效；没分到链的流量按原规则走。",
  "When the kill switch trips, chains are blocked too. Existing protections such as UDP 443 and DNS stay in force; traffic not routed to a chain follows its usual rules."
 ],
 "F-386f75ab72": [
  "名称",
  "Name"
 ],
 "F-58ee533acf": [
  "参数改了，之前的测试结果作废。请重新测试，或按实验性保存。",
  "Settings changed, so the earlier test result no longer applies. Test again, or save as experimental."
 ],
 "F-aed4fe3140": [
  "检查改动",
  "Review changes"
 ],
 "F-43d6155ae4": [
  "UDP 测试结果已过期，请重新测试。",
  "The UDP test result has expired. Test again."
 ],
 "F-f575b9caed": [
  "选择前置节点",
  "Choose an entry hop"
 ],
 "F-79542b7fa4": [
  "（待验证）",
  "(Pending verification)"
 ],
 "F-b269ba0416": [
  "原前置节点（现在不可用）",
  "Previous entry hop (unavailable)"
 ],
 "F-e18a6f52ec": [
  "前置节点",
  "Entry hop"
 ],
 "F-dd90bb8469": [
  "选择后置节点（SOCKS5 或 HTTP）",
  "Choose an exit hop (SOCKS5 or HTTP)"
 ],
 "F-92b8f9ce4e": [
  "（待验证）",
  "(Pending verification)"
 ],
 "F-8d6d234640": [
  "原后置节点（现在不可用）",
  "Previous exit hop (unavailable)"
 ],
 "F-675b4c8a53": [
  "后置节点",
  "Exit hop"
 ],
 "F-9b3e61606b": [
  "后置的预期出口 IP（IPv4）",
  "Expected exit IP of the exit hop (IPv4)"
 ],
 "F-5508b81a93": [
  "UDP 出口要求",
  "UDP exit requirement"
 ],
 "F-40dccbd266": [
  "两跳链 UDP",
  "Chain UDP"
 ],
 "F-bd148db4f3": [
  "测试 TCP 和 UDP",
  "Test TCP and UDP"
 ],
 "F-f64cc4a8e1": [
  "先测前置和整条链的 TCP，再用 DNS 和 STUN 测 UDP。测试不会改动配置。",
  "Tests TCP on the entry hop and the whole chain, then UDP via DNS and STUN. Testing doesn’t change any settings."
 ],
 "F-1de7e88c6b": [
  "TCP 和 UDP 出口都符合要求。可以标记为已验证，也可以继续按实验性使用。",
  "TCP and UDP exits both match. You can mark it as verified or keep using it as experimental."
 ],
 "F-81d898db88": [
  "标记为已验证",
  "Mark as verified"
 ],
 "F-5c617d8788": [
  "测试没有完成，UDP 保持关闭。",
  "The test didn’t finish. UDP stays off."
 ],
 "F-00471725dc": [
  "没有拿到测试结果，请重试。配置没有改动。",
  "No test result came back. Try again. Nothing was changed."
 ],
 "F-56a151194b": [
  "请先选择后置节点。",
  "Choose an exit hop first."
 ],
 "F-d25ad7ae7c": [
  "HTTP 后置节点不支持 UDP。",
  "HTTP exit hops can’t carry UDP."
 ],
 "F-a0018dcce2": [
  "请先在这个 SOCKS5 后置节点的设置里注明服务商支持 UDP，再来测试。",
  "First mark in this SOCKS5 exit hop’s settings that the provider supports UDP, then test."
 ],
 "F-c60f94b081": [
  "这个组合的 UDP 还在开发中，暂时不能测试或开启。",
  "UDP for this combination is still in development and can’t be tested or turned on yet."
 ],
 "F-a1fcf1549b": [
  "实验性：可以开启 UDP 并检查改动，应用前还要再确认一次。",
  "Experimental: you can turn on UDP and review changes; you’ll confirm once more before applying."
 ],
 "F-963da89e39": [
  "两跳链 UDP",
  "Chain UDP"
 ],
 "F-5d47793ae8": [
  "测试时必填，用来核对出口；按实验性开启时可留空。",
  "Required for testing, to check the exit. Can be left blank when enabling as experimental."
 ],
 "F-d86969bb2a": [
  "让这条链承载 UDP（按现有规则）",
  "Carry UDP over this chain (per existing rules)"
 ],
 "F-54feb4a2f8": [
  "前置、后置或 UDP 设置改动后，测试结果会作废。关闭 UDP 后，分到这条链的 UDP 会被阻断，UDP 443 也不会放行。",
  "Changing the entry hop, exit hop or UDP settings invalidates the test result. With UDP off, UDP routed to this chain is blocked, and UDP 443 is never let through."
 ],
 "F-4a13695ff2": [
  "实验性：保存前需勾选确认。两跳链不能设为默认节点。",
  "Experimental: tick the confirmation before saving. A chain can’t be the default node."
 ],
 "F-1c1e6192ca": [
  "这个组合还在开发中，暂时不能保存。",
  "This combination is still in development and can’t be saved yet."
 ],
 "F-140d1a1d0e": [
  "编辑两跳链",
  "Edit chain"
 ],
 "F-e116c7ae4a": [
  "新增两跳链",
  "Add chain"
 ],
 "F-e4cf0b26e1": [
  "两跳链不能设为默认节点，也不能再套一层链。",
  "A chain can’t be the default node and can’t contain another chain."
 ],
 "F-cf8ee7387d": [
  "名称",
  "Name"
 ],
 "F-9c98901df3": [
  "新建后置节点",
  "New exit hop"
 ],
 "F-d16406b216": [
  "新的后置节点要单独保存，保存后重新打开这个窗口就能选到。",
  "A new exit hop is saved separately. Reopen this dialog afterwards to pick it."
 ],
 "F-6d289311c2": [
  "取消",
  "Cancel"
 ],
 "F-aa70bc49e8": [
  "还有一项操作没完成，请先处理完。",
  "Another action is still in progress. Finish it first."
 ],
 "F-c3693d5d41": [
  "未测试",
  "Not tested"
 ],
 "F-58b6fa5b22": [
  "TCP 和 UDP 出口符合要求",
  "TCP and UDP exits match"
 ],
 "F-2c777763bf": [
  "UDP 不通，或出口不符合要求",
  "UDP failed, or the exit doesn’t match"
 ],
 "F-13c87cd50e": [
  "未测",
  "Not run"
 ],
 "F-c6e2289ca0": [
  "可用 · {latency}",
  "Reachable · {latency}"
 ],
 "F-97d3377214": [
  "连接失败",
  "Connection failed"
 ],
 "F-0d7242a838": [
  "前置",
  "Entry hop"
 ],
 "F-d586881da0": [
  "整条链",
  "Whole chain"
 ],
 "F-b396e6c7d3": [
  "；出口 {ip} · {country}",
  "; exit {ip} · {country}"
 ],
 "F-a99709fe1d": [
  "前置：{front}；整条链：{chain}；出口 {ip} · {country} · {time}",
  "Entry hop: {front}; whole chain: {chain}; exit {ip} · {country} · {time}"
 ],
 "F-ea92a6e0c5": [
  "出口 {ip} · {country}",
  "Exit {ip} · {country}"
 ],
 "F-736a9d0b3b": [
  "测试失败",
  "Test failed"
 ],
 "F-4f46f550d4": [
  "检查没有通过",
  "Check failed"
 ],
 "F-d3b625a35d": [
  "这次改动用到新版节点格式。以后要撤销的话，需要连同 LaneKeep 程序一起回退。",
  "This change uses the new node format. Undoing it later also means rolling back LaneKeep itself."
 ],
 "F-29745cf2c2": [
  "确认节点改动｜密钥只保存在路由器本机。",
  "Confirm node changes | Secrets are stored only on the router."
 ],
 "F-ed25b91918": [
  "已识别：{details}",
  "Parsed: {details}"
 ],
 "F-ffdd761d0a": [
  "没有拿到检查结果，什么都没改。",
  "No check result came back. Nothing was changed."
 ],
 "F-3a35f7e3d7": [
  "spiderX",
  "spiderX"
 ],
 "F-bf9af98b82": [
  "已保存：{value}。留空则不改",
  "Saved: {value}. Leave blank to keep"
 ],
 "F-a4349c2430": [
  "未设置",
  "Not set"
 ],
 "F-ed7729b91d": [
  "名称",
  "Name"
 ],
 "F-3388f2b740": [
  "服务器地址",
  "Server"
 ],
 "F-06a2b5f71d": [
  "端口",
  "Port"
 ],
 "F-33231324e8": [
  "SNI",
  "SNI"
 ],
 "F-edddcf2c9c": [
  "UUID",
  "UUID"
 ],
 "F-f09bb0d0b7": [
  "Flow",
  "Flow"
 ],
 "F-8950c8c4cd": [
  "TLS 指纹",
  "TLS fingerprint"
 ],
 "F-0db490eb57": [
  "REALITY 公钥",
  "REALITY public key"
 ],
 "F-bdedea9cf6": [
  "Short ID",
  "Short ID"
 ],
 "F-1fe4fc6ded": [
  "ML-DSA-65 验证值",
  "ML-DSA-65 verify value"
 ],
 "F-b066c1d493": [
  "spiderX",
  "spiderX"
 ],
 "F-30845b2da9": [
  "REALITY 路径（spx，可留空）",
  "REALITY path (spx, optional)"
 ],
 "F-0f9ced841b": [
  "HY2 密码",
  "HY2 password"
 ],
 "F-28a12db198": [
  "ALPN（逗号分隔，可留空）",
  "ALPN (comma-separated, optional)"
 ],
 "F-8932cdae75": [
  "暂不支持 HY2 混淆（obfs），带混淆参数的链接会被拒绝。",
  "HY2 obfuscation (obfs) isn’t supported yet; links that use it are rejected."
 ],
 "F-b2941e07c4": [
  "不要求",
  "Not required"
 ],
 "F-84ad1d3ea2": [
  "要求 X25519MLKEM768",
  "Require X25519MLKEM768"
 ],
 "F-bc8d27eb4a": [
  "ML-KEM 兼容要求",
  "ML-KEM requirement"
 ],
 "F-98a1690ab1": [
  "这一项不会改动 TLS 指纹。相关验证完成前，不能保存为“要求”。",
  "This doesn’t change the TLS fingerprint. Until it’s verified, it can’t be saved as required."
 ],
 "F-73e29dced7": [
  "这个节点设置了跳过证书验证，LaneKeep 不支持。保存时会报错，不会悄悄忽略。",
  "This node is set to skip certificate verification, which LaneKeep doesn’t support. Saving will fail rather than silently ignore it."
 ],
 "F-faa266219d": [
  "只接受验证证书的连接，带 insecure=1 的链接会被拒绝。",
  "Only connections that verify certificates are accepted; links with insecure=1 are rejected."
 ],
 "F-6f4c8c00df": [
  "编辑节点",
  "Edit node"
 ],
 "F-ae11504ce2": [
  "新增节点",
  "Add node"
 ],
 "F-54e2bdd909": [
  "已保存的密钥不会显示，编辑时留空表示不改。切换组合会清空本次填写的密钥。",
  "Saved secrets are never shown; leave them blank when editing to keep them. Switching combination clears what you’ve typed."
 ],
 "F-648f73eeae": [
  "协议",
  "Protocol"
 ],
 "F-8e22d717fe": [
  "这个节点来自订阅。在这里修改不会自动同步到订阅。",
  "This node comes from a subscription. Edits here aren’t synced with the subscription."
 ],
 "F-e46b03dbdd": [
  "取消",
  "Cancel"
 ],
 "F-876103d055": [
  "检查改动",
  "Review changes"
 ],
 "F-5092606e22": [
  "确认两跳链的前置、后置和 UDP 设置。原有保护不变。",
  "Confirm the chain’s entry hop, exit hop and UDP settings. Existing protections stay as they are."
 ],
 "F-6a1f8d54f0": [
  "请先保存后置节点，再重新打开这个窗口。",
  "Save the exit hop first, then reopen this dialog."
 ],
 "F-b71074445e": [
  "按名称筛选",
  "Filter by name"
 ],
 "F-de0344212c": [
  "找到 {total} 条，已选 {selected} 条",
  "{total} found, {selected} selected"
 ],
 "F-d742f255fe": [
  "选择",
  "Select"
 ],
 "F-610d2dd1f6": [
  "行",
  "Line"
 ],
 "F-ff5c92c569": [
  "名称",
  "Name"
 ],
 "F-48a4926279": [
  "协议",
  "Protocol"
 ],
 "F-9c88318abd": [
  "检查结果 / 改动",
  "Check / changes"
 ],
 "F-8ea9d0b5a1": [
  "—",
  "—"
 ],
 "F-7b51820344": [
  "未知",
  "Unknown"
 ],
 "F-9c628f0546": [
  "；改动：{fields}",
  "; changed: {fields}"
 ],
 "F-90aa612588": [
  "预览加载失败，请重新预览。",
  "The preview failed to load. Preview again."
 ],
 "F-6b7de718ab": [
  "选择要导入或更新的节点",
  "Choose nodes to import or update"
 ],
 "F-e00f7c5ea1": [
  "还没有保存任何节点。",
  "No nodes have been saved yet."
 ],
 "F-56cf23032f": [
  "预览 20 分钟内有效；期间有任何改动都需要重新预览。",
  "The preview is valid for 20 minutes; any change in between means previewing again."
 ],
 "F-3622dbe2ec": [
  "筛选",
  "Filter"
 ],
 "F-f0a717473d": [
  "上一页",
  "Previous"
 ],
 "F-981b2d7fce": [
  "下一页",
  "Next"
 ],
 "F-071466accc": [
  "全选筛选结果",
  "Select all results"
 ],
 "F-a49ecb7b30": [
  "超过 21 条，请缩小筛选范围。",
  "More than 21 results. Narrow the filter."
 ],
 "F-4d7efb1689": [
  "清空选择",
  "Clear selection"
 ],
 "F-eb90883f14": [
  "取消",
  "Cancel"
 ],
 "F-639692a1ac": [
  "检查所选节点",
  "Review selected"
 ],
 "F-65c6b07560": [
  "请选择 1 到 21 个通过检查的节点。",
  "Select 1–21 nodes that passed the check."
 ],
 "F-1698feff75": [
  "核对下面的改动摘要，确认后才会应用。",
  "Review the summary below. Nothing is applied until you confirm."
 ],
 "F-fcbe5c34b1": [
  "分享链接或订阅",
  "Share link or subscription"
 ],
 "F-537c20bb3f": [
  "SOCKS5 快速粘贴",
  "SOCKS5 quick paste"
 ],
 "F-33284d8c6e": [
  "HTTP 快速粘贴",
  "HTTP quick paste"
 ],
 "F-a57d23c666": [
  "导入节点",
  "Import nodes"
 ],
 "F-64f37d0a21": [
  "支持 VLESS、VMess、Trojan、Shadowsocks、HY2、SOCKS5、HTTP 链接，也支持 Base64 编码的链接列表。",
  "Supports VLESS, VMess, Trojan, Shadowsocks, HY2, SOCKS5 and HTTP links, and Base64-encoded link lists."
 ],
 "F-386e954190": [
  "格式：host:port:user:pass。用户名或密码里有冒号时，请用百分号编码，或改用“新增节点”逐项填写。",
  "Format: host:port:user:pass. If the username or password contains a colon, percent-encode it or use Add node instead."
 ],
 "F-547235e15f": [
  "链接或订阅内容",
  "Links or subscription content"
 ],
 "F-8f763575e5": [
  "HTTPS 订阅地址",
  "HTTPS subscription URL"
 ],
 "F-82decaa8dd": [
  "先预览，再选择导入哪些。这里只拉取一次，经默认节点；需要定期刷新的，请在“订阅”里添加。",
  "Preview first, then pick what to import. This fetches once, via the default node; to refresh regularly, add it under Subscriptions."
 ],
 "F-5379b3aa33": [
  "取消",
  "Cancel"
 ],
 "F-1a4b5cd369": [
  "预览",
  "Preview"
 ],
 "F-2a00ed3c30": [
  "链接内容和订阅地址只填一个。",
  "Fill in either links or a subscription URL, not both."
 ],
 "F-0feb4d19c7": [
  "预览没有完成",
  "The preview didn’t finish"
 ],
 "F-a7c9d045cf": [
  "没有拿到预览结果，请稍后重试。没有保存任何节点。",
  "No preview result came back. Try again later. No nodes were saved."
 ],
 "F-805f9b77ab": [
  "解除订阅关联",
  "Unlink from subscription"
 ],
 "F-cd821f66c4": [
  "只解除「{name}」和订阅的关联。节点设置、规则和历史都保留，之后仍可重新导入。",
  "Only “{name}” is unlinked from its subscription. Its settings, rules and history are kept, and you can import it again later."
 ],
 "F-5333b72999": [
  "取消",
  "Cancel"
 ],
 "F-23e03cc5a1": [
  "检查改动",
  "Review changes"
 ],
 "F-b9e16c88fe": [
  "确认只解除这个节点和订阅的关联？",
  "Unlink only this node from its subscription?"
 ],
 "F-d61425ef72": [
  "删除节点",
  "Delete node"
 ],
 "F-3848e25f56": [
  "删除「{name}」？",
  "Delete “{name}”?"
 ],
 "F-797168ff4e": [
  "取消",
  "Cancel"
 ],
 "F-68fa644fc8": [
  "检查改动",
  "Review changes"
 ],
 "F-88a4ccc2eb": [
  "确认删除「{name}」？之后可以在“版本”页撤销。",
  "Delete “{name}”? You can undo this on the History page."
 ],
 "F-f3bfe05f78": [
  "正在测试：先测前置，再测整条链……",
  "Testing: entry hop first, then the whole chain…"
 ],
 "F-c4fcab8351": [
  "正在测试……",
  "Testing…"
 ],
 "F-3af4faddb3": [
  "标记为已验证",
  "Mark as verified"
 ],
 "F-23ac7287c0": [
  "没有拿到测试结果。",
  "No test result came back."
 ],
 "F-881022271c": [
  "选择前置节点",
  "Choose an entry hop"
 ],
 "F-dd2a532102": [
  "开始测试",
  "Run test"
 ],
 "F-3a1fc15291": [
  "经前置节点测试",
  "Test via an entry hop"
 ],
 "F-6129ba7673": [
  "后置节点不能单独测，要经过一个前置节点：先测前置，再测整条链。",
  "An exit hop can’t be tested on its own. It goes through an entry hop: the entry hop is tested first, then the whole chain."
 ],
 "F-e1b1867e61": [
  "取消",
  "Cancel"
 ],
 "F-d02ea95c9a": [
  "未知（从未测通）",
  "Unknown (never reached)"
 ],
 "F-438056e470": [
  "未知（测试没通过）",
  "Unknown (test failed)"
 ],
 "F-e91cac346b": [
  "默认节点 {old} → {new}｜出口 IP {from} → {to}",
  "Default node {old} → {new} | Exit IP {from} → {to}"
 ],
 "F-4d59a244f8": [
  "未知",
  "Unknown"
 ],
 "F-a669d0806b": [
  "测试通过",
  "Test passed"
 ],
 "F-79633af289": [
  "这个节点也连不上",
  "This node is unreachable too"
 ],
 "F-19c37af0f0": [
  "检查通过后还要再确认一次才会生效。",
  "After the check you confirm once more before it takes effect."
 ],
 "F-ffc1896e92": [
  "这个节点没有测通。仍可以继续，但如果切换后断线保护仍是触发状态，会自动换回原节点。",
  "This node didn’t pass the test. You can still continue; if the kill switch is still triggered after switching, LaneKeep switches back automatically."
 ],
 "F-e05b787c8f": [
  "应用时代理核心会重启，网络会中断约 10 秒。如果 60 秒内断线保护没有恢复待命，会自动换回原节点。",
  "Applying restarts the proxy core and drops connections for about 10 seconds. If the kill switch is not back to standby within 60 seconds, LaneKeep switches back to the previous node."
 ],
 "F-4e4e01650a": [
  "取消",
  "Cancel"
 ],
 "F-7eb5b42d27": [
  "检查改动",
  "Review changes"
 ],
 "F-ef02154a43": [
  "没测通，仍然继续",
  "Continue anyway"
 ],
 "F-c5b1c6f4ea": [
  "暂无流量统计",
  "No traffic stats yet"
 ],
 "F-062ade4c0c": [
  "统计容量已满，这个节点不显示流量",
  "Stats capacity is full; traffic not shown for this node"
 ],
 "F-abd8e10a5e": [
  "设为默认",
  "Set as default"
 ],
 "F-1f1ecbdcfd": [
  "经前置测试",
  "Test via entry"
 ],
 "F-d71773f39d": [
  "测试",
  "Test"
 ],
 "F-b37a70203b": [
  "删除",
  "Delete"
 ],
 "F-1df842546b": [
  "默认节点",
  "Default node"
 ],
 "F-7cfa80524c": [
  "实验性",
  "Experimental"
 ],
 "F-b836eeed28": [
  "TCP 和 UDP",
  "TCP and UDP"
 ],
 "F-b5e339b738": [
  "仅 TCP",
  "TCP only"
 ],
 "F-73e692ead2": [
  "默认",
  "Default"
 ],
 "F-2246ea8732": [
  "—",
  "—"
 ],
 "F-c1611a38cb": [
  "仅作后置",
  "Exit hop only"
 ],
 "F-a731565a26": [
  "未启用",
  "Not enabled"
 ],
 "F-7a517d049f": [
  "实验性",
  "Experimental"
 ],
 "F-96defab393": [
  "已验证",
  "Verified"
 ],
 "F-17369dabab": [
  "未使用",
  "Not in use"
 ],
 "F-138fc374a1": [
  "编辑",
  "Edit"
 ],
 "F-ffddf4d88b": [
  "UDP 设置",
  "UDP settings"
 ],
 "F-8c2a3cdc87": [
  "解除订阅关联",
  "Unlink from subscription"
 ],
 "F-3c6b5ba751": [
  "默认节点不能删除",
  "The default node cannot be deleted"
 ],
 "F-c3ada69ead": [
  "正被使用，不能删除",
  "In use, cannot be deleted"
 ],
 "F-a594ea7eac": [
  "",
  ""
 ],
 "F-0b34af654b": [
  "",
  ""
 ],
 "F-9bf1f6a0c9": [
  "",
  ""
 ],
 "F-87d7a53edd": [
  "",
  ""
 ],
 "F-47c9a89eb8": [
  "用于",
  "Used by"
 ],
 "F-8c23d1a11c": [
  "最近测试",
  "Last test"
 ],
 "F-e840104455": [
  "",
  ""
 ],
 "F-f50b62f795": [
  "",
  ""
 ],
 "F-07935c1762": [
  "节点",
  "Nodes"
 ],
 "F-8a3ce01e36": [
  "最多 21 个节点，两跳链也算在内。",
  "Up to 21 nodes, chains included."
 ],
 "F-6fd27af62b": [
  "面板不会自动切换节点，需要你在这里手动换默认节点。换了以后，网站看到的 IP 会变。",
  "LaneKeep never switches nodes by itself. Change the default node here; sites will then see a different IP."
 ],
 "F-b6bd4a0237": [
  "默认节点「演示节点 01」可用。它连不上时，所有走代理的流量都会被阻断，不会改走直连。",
  "Default node “Demo node 01” is reachable. If it goes down, all proxied traffic is blocked and nothing falls back to direct."
 ],
 "F-88e42ddebe": [
  "只在你点击时测试。普通节点发一次小请求；两跳链先测前置、再测整条链，每步约 10 秒。测试走临时通道，不改动正在运行的配置。测试通过只说明这一次连得上。",
  "Tests run only when you click. A node gets one small request; a chain tests the entry hop first, then the whole chain, about 10 s per step. Tests use a temporary channel and leave the running config alone. A pass only means it connected this once."
 ],
 "F-3071028429": [
  "",
  ""
 ],
 "F-aaf0789aed": [
  "",
  ""
 ],
 "F-705bc9b2d1": [
  "",
  ""
 ],
 "F-4176fe2965": [
  "两跳链和超出统计容量的节点不显示流量曲线，这不代表节点连不上。",
  "Chains and nodes beyond the stats capacity have no traffic chart. That doesn’t mean they’re unreachable."
 ],
 "F-3b4e4d0859": [
  "未知",
  "Unknown"
 ],
 "F-bcd10e8a95": [
  "新增节点",
  "Add node"
 ],
 "F-5a4a98bcbc": [
  "新增两跳链",
  "Add chain"
 ],
 "F-9fd26900ba": [
  "导入",
  "Import"
 ],
 "F-f8146fd7f8": [
  "操作没有完成",
  "The action didn’t finish"
 ],
 "F-836956b9ae": [
  "操作没有完成",
  "The action didn’t finish"
 ],
 "F-146fa84ed2": [
  "关闭",
  "Close"
 ],
 "F-a228efc90c": [
  "没有拿到结果。请先刷新订阅状态再试。",
  "No result came back. Reload the subscription status, then try again."
 ],
 "F-df06680377": [
  "登录已失效，请重新登录。",
  "Your session has expired. Log in again."
 ],
 "F-0228e1a3dc": [
  "后台缺少订阅功能，请检查安装是否完整。",
  "The backend is missing subscription support. Check the installation."
 ],
 "F-8368f4c08d": [
  "正在处理其他操作，完成后再刷新订阅状态。",
  "Another action is in progress. Reload the subscription status once it finishes."
 ],
 "F-26a2553597": [
  "无法读取订阅设置或缓存，现有数据未受影响。",
  "Couldn’t read subscription settings or cache. Existing data is untouched."
 ],
 "F-0bb91a39ff": [
  "后台没有读完订阅状态，现有数据未受影响。",
  "The backend didn’t finish reading subscriptions. Existing data is untouched."
 ],
 "F-4977790426": [
  "后台返回的数据格式不对，现有数据未受影响。",
  "The backend returned malformed data. Existing data is untouched."
 ],
 "F-0cc1436f07": [
  "读取订阅状态超时，请稍后重试。",
  "Loading subscriptions timed out. Try again later."
 ],
 "F-fe0ed1c8be": [
  "连不上后台，请检查登录状态和网络。",
  "Can’t reach the backend. Check your login and connection."
 ],
 "F-60baa7e73a": [
  "订阅列表暂时读不到（不代表没有订阅）。",
  "Can’t load subscriptions right now (this doesn’t mean there are none)."
 ],
 "F-e4681e5a47": [
  "v2rayN",
  "v2rayN"
 ],
 "F-536c99dea4": [
  "我确认这个订阅走直连：订阅服务商会看到我家的真实 IP，域名解析走路由器系统 DNS。",
  "I confirm this subscription is fetched directly: the provider will see my home IP, and DNS goes through the router’s system resolver."
 ],
 "F-2e7f8c225d": [
  "经默认节点",
  "Via default node"
 ],
 "F-597f318a2e": [
  "直连（需确认）",
  "Direct (needs confirmation)"
 ],
 "F-318dfd864e": [
  "编辑订阅",
  "Edit subscription"
 ],
 "F-c01e36700d": [
  "新增订阅",
  "Add subscription"
 ],
 "F-f5fe85c580": [
  "保存只改订阅设置，不会拉取。地址留空则保持原值。",
  "Saving only changes the settings; nothing is fetched. Leave the URL blank to keep it."
 ],
 "F-0f47e87246": [
  "名称",
  "Name"
 ],
 "F-159a1a9d56": [
  "HTTPS 订阅地址",
  "HTTPS subscription URL"
 ],
 "F-71de8ac4b8": [
  "User-Agent",
  "User-Agent"
 ],
 "F-fddd99ee87": [
  "拉取方式",
  "Fetch via"
 ],
 "F-4c010479cf": [
  "经节点拉取失败时，不会改走直连。",
  "If fetching via a node fails, it never falls back to direct."
 ],
 "F-07003644f2": [
  "取消",
  "Cancel"
 ],
 "F-61bc1d3436": [
  "保存",
  "Save"
 ],
 "F-9d3ea5cabf": [
  "删除订阅",
  "Delete subscription"
 ],
 "F-fcf11e8ded": [
  "删除这个订阅和它的缓存。已导入的节点、规则和代理设置都不受影响。",
  "Deletes this subscription and its cache. Imported nodes, rules and proxy settings are not affected."
 ],
 "F-baaef7f369": [
  "取消",
  "Cancel"
 ],
 "F-c6a6c96f02": [
  "删除",
  "Delete"
 ],
 "F-11e1078193": [
  "刷新订阅",
  "Refresh subscription"
 ],
 "F-e99a909652": [
  "经{channel}拉取，最长等 60 秒。成功后只更新缓存；失败则保留上次的缓存。",
  "Fetching via {channel}, up to 60 seconds. Success only updates the cache; on failure the last good cache is kept."
 ],
 "F-b4ee7511ed": [
  "直连",
  "direct connection"
 ],
 "F-a198b6c6c1": [
  "默认节点",
  "the default node"
 ],
 "F-6b3252c1fc": [
  "取消",
  "Cancel"
 ],
 "F-8acfebc016": [
  "刷新",
  "Refresh"
 ],
 "F-0099f48c6c": [
  "按名称筛选",
  "Filter by name"
 ],
 "F-cf14b527ac": [
  "名称前缀（可选）",
  "Name prefix (optional)"
 ],
 "F-78ee7be410": [
  "找到 {total} 条，本页 {page} 条，已选 {selected} 条",
  "{total} found, {page} on this page, {selected} selected"
 ],
 "F-2d2fa295c7": [
  "选择",
  "Select"
 ],
 "F-ddcfa93383": [
  "名称",
  "Name"
 ],
 "F-477218f276": [
  "状态",
  "Status"
 ],
 "F-8c83c2e944": [
  "更新到",
  "Update into"
 ],
 "F-6012af22cd": [
  "—",
  "—"
 ],
 "F-de97f70c96": [
  "新增为节点",
  "Add as new node"
 ],
 "F-ca9dbd4ff0": [
  "—",
  "—"
 ],
 "F-7877614501": [
  "查看并选择",
  "Review and pick"
 ],
 "F-81612f508a": [
  "选好后还要预览、确认才会生效。订阅里已经没有的节点不会被自动删除；同名的条目需要手动指定更新哪个节点。",
  "Picks take effect only after preview and confirmation. Nodes gone from the subscription are never deleted automatically; for duplicate names, choose which node to update."
 ],
 "F-975efbd135": [
  "筛选",
  "Filter"
 ],
 "F-000b7149aa": [
  "上一页",
  "Previous"
 ],
 "F-8c9af6fd51": [
  "下一页",
  "Next"
 ],
 "F-c87d025af8": [
  "全选筛选结果",
  "Select all results"
 ],
 "F-4079ee91ff": [
  "超过 21 条，请缩小筛选范围。",
  "More than 21 results. Narrow the filter."
 ],
 "F-e62be776d6": [
  "清空选择",
  "Clear selection"
 ],
 "F-7c65693187": [
  "名称前缀（可选）",
  "Name prefix (optional)"
 ],
 "F-f7d61bb5ab": [
  "取消",
  "Cancel"
 ],
 "F-bb69479596": [
  "预览所选",
  "Preview selected"
 ],
 "F-d7db747a04": [
  "请选择 1 到 21 条。",
  "Select 1–21 items."
 ],
 "F-7981b2dc33": [
  "预览没有完成，节点没有改动。",
  "The preview didn’t finish. No nodes were changed."
 ],
 "F-199b5fa7ce": [
  "刷新",
  "Refresh"
 ],
 "F-818b88a6a5": [
  "编辑",
  "Edit"
 ],
 "F-622a968fab": [
  "删除",
  "Delete"
 ],
 "F-2bb611ca11": [
  "查看并选择",
  "Review and pick"
 ],
 "F-08defc145e": [
  "已用上传",
  "Uploaded"
 ],
 "F-ce10648813": [
  "已用下载",
  "Downloaded"
 ],
 "F-f36d7a1ae3": [
  "总流量",
  "Total"
 ],
 "F-a8a82a95db": [
  "到期",
  "Expires"
 ],
 "F-cffde15f0c": [
  "—",
  "—"
 ],
 "F-f549f0a739": [
  "直连拉取",
  "fetched directly"
 ],
 "F-307ca6d431": [
  "经默认节点拉取",
  "fetched via default node"
 ],
 "F-f1e6d2a59a": [
  "{time}刷新",
  "Refreshed {time}"
 ],
 "F-0abe9a63aa": [
  "还没有拉取成功过",
  "Never fetched successfully"
 ],
 "F-ae8fd3e5be": [
  "正在读取订阅……",
  "Loading subscriptions…"
 ],
 "F-9f806e8ab4": [
  "重新读取",
  "Reload"
 ],
 "F-f0fd4f269a": [
  "新增订阅",
  "Add subscription"
 ],
 "F-a324968ee7": [
  "订阅",
  "Subscriptions"
 ],
 "F-b40407daa2": [
  "只在你点击时刷新。刷新不会改动已有的节点和规则。",
  "Refreshes only when you click. Refreshing never changes existing nodes or rules."
 ],
 "F-a69af5c86c": [
  "订阅功能还在开发中，暂时不能添加或刷新。",
  "Subscriptions are still in development and can’t be added or refreshed yet."
 ],
 "F-ae252d5504": [
  "",
  ""
 ],
 "F-43b6dfb038": [
  "",
  ""
 ],
 "F-d69c6c5f2d": [
  "",
  ""
 ],
 "F-a0a8958194": [
  "",
  ""
 ],
 "F-4b86da8d3f": [
  "",
  ""
 ],
 "F-2be4bf96df": [
  "",
  ""
 ],
 "F-d4c99eab2a": [
  "",
  ""
 ],
 "F-95bc0cc58c": [
  "还没有订阅。",
  "No subscriptions yet."
 ],
 "F-649c57dc2a": [
  "订阅状态已更新",
  "Subscriptions updated"
 ],
 "N-01": [
  "管理代理节点和两跳链。每个模式可以指定走哪个节点。",
  "Manage proxy nodes and two-hop chains. Each mode can be pointed at its own node."
 ],
 "N-02": [
  "说明",
  "How it works"
 ],
 "N-03": [
  "断线保护",
  "Kill switch"
 ],
 "N-04": [
  "待命",
  "Standby"
 ],
 "N-05": [
  "已触发",
  "Triggered"
 ],
 "N-06": [
  "默认节点「{name}」连不上，所有走代理的流量正在被阻断。",
  "Default node “{name}” is unreachable. All proxied traffic is being blocked."
 ],
 "N-07": [
  "未知",
  "Unknown"
 ],
 "N-08": [
  "暂时读不到断线保护的状态。",
  "Can’t read the kill switch status right now."
 ],
 "N-09": [
  "了解详情",
  "Learn more"
 ],
 "N-10": [
  "说明",
  "How it works"
 ],
 "N-11": [
  "收起",
  "Hide"
 ],
 "N-12": [
  "默认节点与断线保护",
  "Default node and kill switch"
 ],
 "N-13": [
  "健康检测只盯默认节点。它连不上时触发断线保护，指定了其他节点的规则也一起阻断。",
  "Health checks watch the default node only. If it is unreachable the kill switch trips, and rules pinned to other nodes are blocked too."
 ],
 "N-14": [
  "测试",
  "Testing"
 ],
 "N-15": [
  "两跳链",
  "Two-hop chains"
 ],
 "N-16": [
  "数量上限",
  "Limits"
 ],
 "N-17": [
  "订阅缓存在内存里，重启路由器后需要手动刷新一次；已导入的节点不受影响。",
  "The subscription cache lives in memory, so refresh once after the router restarts. Imported nodes are not affected."
 ],
 "N-18": [
  "含 {chains} 条两跳链",
  "incl. {chains} chain(s)"
 ],
 "N-19": [
  "两跳链",
  "Two-hop chain"
 ],
 "N-20": [
  "来自订阅",
  "From subscription"
 ],
 "N-21": [
  "更多操作",
  "More actions"
 ],
 "N-22": [
  "已经是默认节点",
  "Already the default node"
 ],
 "N-23": [
  "查看并选择",
  "Review and pick"
 ],
 "N-24": [
  "{domain} · 地址已隐藏",
  "{domain} · URL hidden"
 ],
 "N-25": [
  "缓存 {n} 个节点",
  "{n} nodes cached"
 ],
 "N-26": [
  "已有节点不能改协议",
  "Protocol can’t be changed on an existing node"
 ],
 "N-27": [
  "不会显示，也不写入日志",
  "Never shown or logged"
 ],
 "N-28": [
  "高级设置",
  "Advanced"
 ]
};
function t(id,params){var pair=entries[id];if(!pair)throw new Error('Unknown copy key: '+id);return pair[i18n.language==='en'?1:0].replace(/\{(\w+)\}/g,function(_,k){return params&&params[k]!=null?String(params[k]):'—';});}
var exported = {t:t,entries:entries,language:i18n.language};
// LuCI instantiates modules; keep dictionary keys as own enumerable properties.
return baseclass.extend({ __init__: function() { Object.assign(this, exported); } });
