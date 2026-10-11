# 配置参考 / Configuration reference

主窗口的设置分为“通用 / General”“翻译服务 / Translation”“取词与快捷键 / Gestures & keys”。菜单栏可打开设置；首次配置不完整时首页会直接引导到对应页面。

## 翻译服务

| 设置 | 默认值 | 说明 |
| --- | --- | --- |
| Provider | DeepSeek / OpenAI API | Apple 系统翻译为可选项；不需 API Key，但首次可能下载语言包 |
| Endpoint | `https://api.deepseek.com` | 只填可信服务；应用把 Key 发送到此地址，不跟随重定向 |
| Model | `deepseek-flash` | 可改成账号支持的模型名称 |
| API Key | 空 | 自备 Key，系统钥匙串保存，不随安装包提供 |
| Fast mode | 开 | 对 `deepseek-` 开头模型发送 `thinking.type=disabled`；关闭时为 `enabled`；其他模型不发送此字段 |
| Target | 简体中文 | 支持中文简繁、英、日、韩、法、德、西、葡、意、俄 |
| Alternate target | English | 原文与目标语言相同时自动改用第二目标 |

### 兼容地址示例

| 输入地址 | 实际请求地址 |
| --- | --- |
| `https://api.deepseek.com` | `https://api.deepseek.com/chat/completions` |
| `https://example.org/v1` | `https://example.org/v1/chat/completions` |
| `https://example.org/v1/chat/completions` | 保持不变 |
| `http://127.0.0.1:1234/v1` | `http://127.0.0.1:1234/v1/chat/completions` |

`example.org` 仅为示例，请替换成服务商地址。本机服务器可以不填 Key，模型名按本机服务填写。当前是 Chat Completions 客户端，不是 Responses API 客户端。远程明文 HTTP、含用户名 / 密码 / 查询参数 / fragment 的地址会拒绝。

字典请求使用 `response_format: {"type":"json_object"}`，返回词义、音标、词性、语言、原句、译文或例句。服务需要支持这类 JSON 输出及流式响应。普通段落请求只要求返回翻译文本。自动缓存最多 100 条、30 分钟，按服务、模型、凭据、语言、原文和语境区分；重启后清空。

## 通用

| 设置 | 默认值 | 说明 |
| --- | --- | --- |
| Appearance | 浅色 | 可选跟随系统、浅色、深色 |
| Interface language | 简体中文 | 可选 English；部分运行消息尚未完整英文化 |
| Show Dock icon | 关 | 关闭时仍有菜单栏图标 |
| Review badge | 开 | 菜单栏显示待复习数量 |
| Launch at login | 关 | macOS 可能要求在登录项中批准 |
| English voice | 美式 | 可选英式；其他语言使用系统语音 |
| Auto speak | 关 | 完成取词后自动朗读 |

“当前运行版本”会显示你本机的应用位置，方便排查授权了不同副本的问题；这个位置不会上传。

## 取词与快捷键

| 设置 | 默认值 | 说明 |
| --- | --- | --- |
| Modifier | 左 Option | 可选右 Option、Control+Option |
| Modifier tap / click / drag | 开 | 轻按取词、点击取词、拖动框选 |
| Ordinary click | 关 | 开启后可能在更多点击动作触发查询，请按需使用 |
| Automatic hover | 关 | 开启后停留才触发，可能增加 API 调用次数 |
| Dwell delay | 0.75 秒 | 可选 0.35–2 秒，步长 0.05 |
| Prefer selection | 开 | 取词快捷键优先读取选中文字 |
| Recognize words | 开 | 鼠标附近优先取目标词；框选仍翻译选区全文 |
| Pause lookup | 关 | 暂停全局取词；手动输入仍可用 |
| Excluded apps | 空 | 每行一个应用名或 Bundle ID |

快捷键默认：取词 Option+Space、框选 Option+R、选中翻译 Option+S、输入 Option+I。重绑时须包含 Command、Option 或 Control，Esc 取消。若与其他应用冲突，请换组合，不要依赖冲突快捷键。

## 故障排查

| 现象 | 处理 |
| --- | --- |
| 找不到窗口 | 点击菜单栏 Flow Translate 图标，或重新打开 Applications 内的应用 |
| API 401 | 检查 Key 是否复制完整，是否保存，所属服务是否正确 |
| API 429 | 检查余额 / 额度 / 限流，稍后重试 |
| 其他 HTTP 错误 / 404 | 检查 endpoint、模型名；应用不会跟随重定向，请填最终 API 地址 |
| 词典格式不完整 | 模型可能不支持 JSON 输出，或连接截断；换兼容模型或使用段落翻译 |
| 屏幕取词没反应 | 检查暂停 / 排除应用 / 快捷键冲突 / 辅助功能；设置下方应显示监听开启 |
| 框选报权限错误 | 给 Applications 中的当前副本录屏权限，并按系统提示重启 |
| 更新后权限开关已开但无效 | 退出重开；必要时只移除并重新添加 Flow Translate 的旧记录 |
| 选中文字读取不到 | 有些应用不提供 AX 选区接口；改用框选 |
| 翻译内容太多 / 取错词 | 复杂布局可能识别错误；缩小框选区域，或复制到输入窗口 |
| 生词本读取失败 | 原文件会保留。使用界面的备份恢复入口前先备份该目录，不要直接覆盖损坏文件 |
| Apple 翻译不可用 | 检查系统版本、所选语言和语言包；必要时使用 API 服务 |

## English notes

The table labels match the English Settings interface. API keys are entered locally and stored in Keychain; no key is bundled. Only trust endpoints to which you intend to send text and credentials. The client supports Chat Completions, streaming, and JSON dictionary output—not every API advertised as compatible supports all three.

Typed text requires neither screen permission. Screen recording is needed for OCR; Accessibility is needed for global gestures and selected text. Restart the installed app after granting permissions. Automatic hover and ordinary-click lookup are off by default; enabling them can increase API calls. Rebind conflicting shortcuts in Settings. Use region capture when an application does not expose selected text.
