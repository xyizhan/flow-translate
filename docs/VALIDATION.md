# 0.4.0-beta.1 验证范围 / Validation scope

本版作为公开预览发布。测试环境：Apple Silicon、macOS 26.5、Swift 6.2.3 / Command Line Tools；最低部署目标是 macOS 15.0。最低目标不等于已经覆盖所有 macOS 15 设备。以下检查使用生成文字、临时数据目录和本地模拟 API，不含真实凭据或私人屏幕内容。

## 已执行

- **干净源码验证**：独立源码目录不继承原开发目录的构建缓存、配置或测试输出；`scripts/verify.sh` 通过。修复了导出检查对预先存在输出目录的依赖。
- **核心逻辑**：API 地址校验、拒绝带凭据 / 查询参数 / fragment 的地址、SSE 分帧、CRLF / EOF、JSON 响应、过滤推理和用量字段、目标语言及多屏坐标。
- **手势状态机**：轻按、组合键、点击、拖动、取消、悬停停留与重复抑制。此项为事件状态机检查，不替代实体键鼠验收。
- **OCR / 语境**：生成图片的 0° / 8° / 90° 识别；复合词；菜单栏和标尺排除；跨行句子；重复单词定位；分栏、段落、缩写及中日韩句界。
- **应用数据**：收藏去重、撤销、重新添加、40 条历史限制、复习调度、写入失败回滚、损坏数据保留和备份恢复、文件权限、Anki 导出。
- **API 客户端**：loopback 模拟服务验证流式及普通 JSON、401、拒绝重定向、取消、最新请求优先、缓存、截断流不缓存、结构化词典。
- **Keychain**：独立随机服务中的假凭据测试：相同构建读取、不同构建静默拒绝、授权续接、替换和清理。没有导入真实 API Key。
- **卡片布局**：浅 / 深色各六种状态。词典卡片 350 × 233 pt、短段落 350 × 142 pt、长文最高 440 pt 后滚动；长文切回短文能收缩。README 图像为真实视图的生成数据渲染。
- **原生首次启动**：从 DMG 提取应用后启动，显示服务 → 权限 → 使用引导；Key 为空、历史和收藏为空；无需权限可看示例；首页“去设置”直接打开翻译服务。
- **安装后的翻译**：通过实际安装包界面连接本机模拟 API，显示完整译文；测试后恢复默认服务地址。此项没有访问付费服务。
- **安装包检查**：DMG 校验通过，DMG / ZIP 都可解包且应用签名完整；Mach-O 为 arm64、最低版本 15.0，仅链接系统运行库。包内没有配置、Key、历史、测试材料或扩展属性资源文件。
- **发布隐私检查**：独立目录通过 Gitleaks 凭据扫描和本项目路径 / 私人文件检查，应用二进制同样扫描；仅使用 GitHub no-reply 提交邮箱。扫描不能证明不存在一切安全问题。

## 尚未承诺的范围

- Developer ID 签名、Apple 公证和所有组织管理策略下的安装。当前为 ad-hoc 签名，用户可能需要“仍要打开”。
- 每一种 macOS 15 / 26 版本、Intel、所有分辨率与显示器组合。
- 全部第三方模型、Apple 语言包下载、所有应用选中文字接口、复杂版面与受保护内容。
- 本次公开构建的录屏 / 辅助功能真实授权和实体键鼠全组合。原开发版本已有人机验收记录，但它不等于另一台电脑的权限验证。
- 真实注销 / 登录后的自动启动、全英文错误提示、自动更新。

GitHub Actions 在每次推送时重新执行离线功能验证、应用构建和隐私检查。请查看对应提交的实际结果。发布资产通过独立下载与校验后，发布说明会记录结果；本地包通过并不自动意味着公网下载通过。

## English

The release was checked on Apple Silicon / macOS 26.5 / Swift 6.2.3. Offline core, gestures, OCR, context, learning persistence, Keychain fixtures, HTTP/SSE errors, cancellation and caching checks pass. Both card themes and fresh native setup were inspected. A DMG-extracted app completed a GUI translation against a local mock server without a real key. DMG and ZIP integrity, architecture, deployment target, dependencies and bundle signature were verified.

The package is ad-hoc signed, not notarized. This is not a complete macOS/Intel/device/provider matrix, a fresh physical-permission acceptance test, or an independent security audit. GitHub CI and the release notes record subsequent source and public-download verification.
