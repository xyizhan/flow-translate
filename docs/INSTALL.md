# 安装、更新与卸载 / Installation

## 下载包

- `Flow-Translate-0.4.0-beta.1-macos-arm64.dmg`：推荐，打开后把应用拖到 Applications。
- 同名 `.zip`：解压后把 `Flow Translate.app` 移到 Applications。
- `SHA256SUMS.txt`：同一发布对应的 SHA-256 校验值。
- `Source code` 或带 `source` 的 ZIP：供开发者构建，不是可直接启动的应用。

要求 Apple Silicon（M1+）和 macOS 15+。发布为预览版，未获 Developer ID 签名 / Apple 公证。普通用户无需安装 Swift、Python 或 Xcode。

## 第一次打开

1. 从 [官方仓库 Releases](https://github.com/xyizhan/flow-translate/releases) 下载并校验文件。
2. 拖入“应用程序”，推出 DMG，再打开 `/Applications/Flow Translate.app`。
3. 如提示开发者无法验证，先尝试打开，再到系统设置 → 隐私与安全性 → 仍要打开，按提示确认。请阅读 [Apple 官方说明](https://support.apple.com/102445)。若系统提示恶意软件或文件损坏，不要直接绕过，先停止并核对下载与校验值。
4. 按应用内三步引导配置 API（或选择 Apple 翻译）、授予需要的权限、试译一句话。

不需要 `sudo`、不需要禁用 SIP / Gatekeeper，也不提供自动移除 quarantine 的脚本。组织管理的电脑可能禁止未公证应用，请遵循管理员设置或从源码构建。

## 更新

从菜单栏退出应用，下载同架构的新版本，替换 Applications 中的旧副本。不要同时运行 DMG 和 Applications 内的两份应用。

预览版使用临时签名，更新后 macOS 可能重新询问录屏、辅助功能或钥匙串权限。只为 Flow Translate 授权；如开关开启但无效，退出重开，必要时在系统设置中移除该应用旧记录，再添加安装位置的当前版本。其他应用的权限无需重置。

如果出现钥匙串提示，密码是本机登录钥匙串密码，通常等于 Mac 登录密码，**不是 API Key**。只在系统弹窗输入，确认应用身份后可点“始终允许”。启动不会主动索要密码；需要时在设置里点“解锁已保存的 Key”。不要把密码告诉项目维护者。

## 卸载

1. 关闭“设置 → 通用 → 登录时自动启动”，从菜单退出应用。
2. 将 Applications 中的应用移到废纸篓。
3. 若想同时删除学习数据，请先导出生词本，再移除 `~/Library/Application Support/FlowTranslate/`。这是可选操作，更新通常无需删数据。
4. 如需移除 Key，在“钥匙串访问”中搜索 `io.github.xyizhan.FlowTranslate.api`，只删除该服务对应项目。
5. 系统设置中可移除 Flow Translate 的录屏、辅助功能及登录项记录。

## English quick steps

Download the arm64 DMG from Releases, verify its checksum, drag the app into Applications, eject the image, and open the installed app. This preview is **not Developer ID signed or notarized**. For an unidentified-developer warning, follow Apple's linked “Open Anyway” flow after verifying origin and integrity. Never disable global security controls. Managed Macs may prohibit this preview.

Configure your own API key or choose Apple Translation, then grant only the permissions you need. Quit before replacing the app during an update. Ad-hoc updates may require permission renewal. Quit and remove the app to uninstall; local learning files and Keychain items are retained unless you explicitly remove them.
