# Privacy / 隐私说明

Flow Translate 不运营用户账号、同步服务器、统计 SDK、广告系统或自动更新服务。

## 在本机处理的数据

- 屏幕截图：只在执行屏幕取词 / 框选时用于 Apple Vision OCR，在内存处理，不保存截图文件。
- 辅助功能：用于监听手势和读取前台应用提供的选中文字。
- API Key：系统钥匙串服务 `io.github.xyizhan.FlowTranslate.api`。偏好设置只保存条目定位符，不保存 Key 明文。
- 设置：存储在 macOS UserDefaults，域 `io.github.xyizhan.FlowTranslate`。
- 生词本：`~/Library/Application Support/FlowTranslate/vocabulary.json` 及上一版备份。
- 最近 40 次词典查询：同目录的 `history.json`。这些 JSON 使用仅当前用户读写的权限，不是加密存储。
- 翻译缓存：仅在内存中，最多 100 条 / 30 分钟，重启清除。只有成功的完整结果会缓存。
- 复制：用户点击复制时把结果写入系统剪贴板。

## 发送给谁

**API 模式**：识别出的文字 / 用户输入的文字、目标词所在句、语言设置及请求参数发送到用户配置的 endpoint，并通过 Authorization 头发送所配置的 Key。截图不上传。默认是 DeepSeek；更换 endpoint 就是更换接收方。网络请求使用临时会话并拒绝 HTTP 重定向。请阅读你选择的服务商的数据保留、计费及隐私政策。

**Apple 系统翻译**：文字交由 macOS Translation 框架处理；系统可能下载语言包。应用不把这些请求发给配置的第三方 API。

自动悬停和普通点击取词默认关闭；开启后会根据这些交互触发查询，请避免在敏感应用中启用，可使用应用排除或暂停功能。翻译敏感原文前，应判断是否愿意把其发送给当前服务商。

## 删除与控制

可以退出应用清空内存缓存，导出 / 移除生词，或按 [卸载说明](docs/INSTALL.md) 删除本机数据和 Keychain 项目。撤销 macOS 权限后，相应屏幕功能停止工作；手动输入不需要这些权限。

不要在公共 Issue 附 Key、私人原文、完整系统日志、用户名路径或未脱敏截图。安全问题请使用 [私密报告入口](SECURITY.md)。

## English

Screenshots stay in memory on this Mac for Vision OCR and are not uploaded. API mode sends recognized or typed text, its relevant context sentence, and your API credential to **your configured endpoint**. Provider retention and billing policies apply. Only enter endpoints you trust. Apple Translation uses the system framework and may download language packs.

Keys are stored in macOS Keychain; preferences contain only a locator. Vocabulary, a backup, and the last 40 dictionary lookups are local permission-restricted JSON files, **not encrypted databases**. There is no analytics, account backend, cloud sync, or automatic updater. Hover and ordinary-click lookup are opt-in. Quit to clear the memory cache; follow the installation guide to remove local data and Keychain items.
