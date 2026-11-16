# Security policy / 安全政策

Supported release: **0.1.x**. This is an early release; the protection boundaries and IPv6 prerequisite are documented in [leak protection](docs/leak-protection.en.md).

安全问题请私下报告，**不要在公开 Issue、PR 或讨论中发布可利用细节、节点链接、订阅链接、UUID、密钥、密码、真实 IP、设备名或完整配置**。

Use the repository's **Security → Report a vulnerability** private reporting form when it is available. Include the affected version, a sanitized reproduction, expected versus actual behavior and impact. Use documentation addresses and fresh dummy credentials. Send an unredacted reproduction only after agreeing on a private channel with the maintainer.

This repository is initially private. GitHub's private vulnerability reporting control is unavailable in that state; the maintainer must enable it before making the repository public. Until a private reporting channel is available, request one without including vulnerability details or personal data. Do not turn a security report into a public bug report.

维护者公开仓库前应启用 GitHub 私密漏洞报告。收到报告后先复现并评估影响，再协调修复与披露；不承诺尚未建立的响应时限。

Do not attach raw exports from the router. Xray access/error logging is disabled, but application configuration, snapshots, subscriptions and operating-system logs can still contain sensitive information.
