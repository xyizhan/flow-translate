import SwiftUI

struct OnboardingView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var navigation: Navigation
    let controller: AppController
    @State private var step = 0
    private func tr(_ zh: String, _ en: String) -> String { settings.tr(zh, en) }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 8) {
                FlowMark().frame(width: 24, height: 24).foregroundStyle(.teal)
                Text("Flow Translate").font(.system(size: 19, weight: .semibold, design: .rounded))
                Spacer()
                Picker("Language", selection: $settings.options.uiLanguage) { Text("中文").tag("zh"); Text("English").tag("en") }.labelsHidden().frame(width: 95)
            }
            HStack(spacing: 12) {
                ForEach(0..<3) { index in
                    Text("\(index + 1)  " + [tr("翻译服务", "Service"), tr("权限", "Permissions"), tr("开始使用", "Start")][index])
                        .font(.system(size: 11, weight: index == step ? .semibold : .regular))
                        .foregroundStyle(index == step ? Color.primary : .secondary)
                    if index != 2 { Image(systemName: "chevron.right").font(.system(size: 8)).foregroundStyle(.tertiary) }
                }
            }
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if step == 0 { service }
                    else if step == 1 { permissions }
                    else { shortcuts }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 4)
            }
            HStack {
                Button(tr("稍后设置", "Set up later")) { finish() }.buttonStyle(.plain).foregroundStyle(.secondary)
                Spacer()
                if step > 0 { Button(tr("上一步", "Back")) { step -= 1 }.buttonStyle(QuietButton()) }
                Button(step == 2 ? tr("开始使用", "Start reading") : tr("下一步", "Next")) {
                    Task {
                        if step == 0, settings.provider == .compatibleAPI, !settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            guard await settings.persistKey() else { return }
                        }
                        if step == 2 { finish() } else { step += 1; settings.refreshPermissions() }
                    }
                }.buttonStyle(QuietButton()).disabled(settings.keyBusy)
            }
        }.padding(28).frame(width: 510, height: 550).background(Palette.background)
    }
    private var service: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(tr("先连接翻译服务", "Choose your translation service")).font(.system(size: 23, weight: .semibold))
            Text(tr("应用免费开源。API 的用量费用由服务商收取；请使用自己的 Key。", "The app is free and open source. API providers bill usage separately; bring your own key.")).font(.system(size: 12)).foregroundStyle(.secondary)
            Picker(tr("服务", "Service"), selection: $settings.provider) {
                Text("DeepSeek / OpenAI API").tag(TranslationProvider.compatibleAPI)
                Text(tr("Apple 系统翻译", "Apple Translation")).tag(TranslationProvider.system)
            }
            if settings.provider == .compatibleAPI {
                input(tr("API 地址（仅填写可信服务）", "API endpoint (trusted services only)")) { TextField("https://api.deepseek.com", text: $settings.endpoint) }
                input(tr("模型名称", "Model name")) { TextField("deepseek-flash", text: $settings.model) }
                input("API Key") { SecureField(tr("填写自己的 Key", "Enter your own key"), text: $settings.apiKey).disabled(settings.keyBusy) }
                Text(tr("点击下一步时将 Key 保存到本机钥匙串。支持 HTTPS；本机服务可使用 HTTP。", "Next saves the key in this Mac's Keychain. HTTPS is required except for local servers.")).font(.system(size: 10)).foregroundStyle(.secondary)
                if settings.keyRequiresUnlock { Button(tr("解锁已保存的 Key", "Unlock saved key")) { settings.unlockKey() }.buttonStyle(QuietButton()).disabled(settings.keyBusy) }
                if !settings.keyMessage.isEmpty { Text(settings.keyMessage).font(.system(size: 11)).foregroundStyle(.secondary) }
                Link(tr("获取 DeepSeek API Key ↗", "Get a DeepSeek API key ↗"), destination: URL(string: "https://platform.deepseek.com/api_keys")!).font(.system(size: 11))
            } else {
                Text(tr("无需 API Key；首次翻译可能需要下载语言包。完整语境释义、词性及例句请使用 API 模式。", "No API key is needed. Language packs may be downloaded on first use. Use API mode for full contextual definitions, parts of speech, and examples.")).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Picker(tr("译成", "Translate into"), selection: $settings.target) { ForEach(AppSettings.languages, id: \.0) { Text($0.1).tag($0.0) } }
        }.textFieldStyle(.roundedBorder)
    }
    private var permissions: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(tr("让屏幕上的词可以被读到", "Read words from your screen")).font(.system(size: 23, weight: .semibold))
            permission(tr("屏幕录制", "Screen recording"), tr("框选和鼠标取词需要。截图只在本机进行 OCR。", "Required for region and pointer OCR. Screenshots stay on this Mac."), settings.screenPermission, settings.requestScreenPermission)
            permission(tr("辅助功能", "Accessibility"), tr("Option 手势、悬停和读取选中文字需要。", "Required for Option gestures, hover, and selected text."), settings.accessibilityPermission, settings.requestAccessibility)
            Text(tr("系统要求重开时，请退出再打开应用。输入 / 粘贴翻译无需这些屏幕权限，可以先试用。", "Quit and reopen when macOS asks. You can try typed or pasted text without either screen permission.")).font(.system(size: 12)).foregroundStyle(.secondary)
            Button(tr("刷新权限状态", "Refresh permissions")) { settings.refreshPermissions() }.buttonStyle(QuietButton())
            Text(tr("API 模式仅把识别出的文字和目标句发送到你配置的服务；自动悬停默认关闭。", "API mode sends recognized text and its context sentence to your configured service. Automatic hover is off by default.")).font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }
    private var shortcuts: some View {
        VStack(alignment: .leading, spacing: 17) {
            Text(tr("理解，然后继续阅读", "Understand. Keep reading.")).font(.system(size: 23, weight: .semibold))
            shortcut("Option", tr("轻按左 Option：鼠标取词", "Tap left Option: word under pointer"))
            shortcut("⌥ R", tr("框选一段文字", "Select a screen region"))
            shortcut("⌥ S", tr("翻译已选中文字", "Translate selected text"))
            shortcut("⌥ I", tr("输入或粘贴翻译", "Type or paste text"))
            Text(tr("也支持 Option 点击 / 拖动。菜单栏图标可打开设置、暂停取词；Esc 关闭浮窗。", "Option-click / drag also work. Use the menu bar icon for settings or pause; Esc closes a card.")).font(.system(size: 12)).foregroundStyle(.secondary)
            HStack {
                Button(settings.needsAPIKey ? tr("先填写 API Key", "Set an API key first") : tr("试译一句话", "Try a sentence")) {
                    if settings.needsAPIKey { step = 0 }
                    else { finish(); controller.translateInput("Reading should feel effortless.") }
                }.buttonStyle(QuietButton())
                Button(tr("查看卡片示例", "Preview a card")) { finish(); controller.showExample() }.buttonStyle(.plain)
            }
            Text(tr("所有快捷键、目标语言和悬停选项都可以稍后在设置中调整。", "Customize shortcuts, languages, and hover behavior in Settings.")).font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }
    private func input<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) { Text(title).font(.system(size: 11)).foregroundStyle(.secondary); content() }
    }
    private func permission(_ title: String, _ detail: String, _ ready: Bool, _ action: @escaping () -> Void) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) { Text(title).fontWeight(.medium); Text(detail).font(.system(size: 11)).foregroundStyle(.secondary) }
            Spacer()
            if ready { Image(systemName: "checkmark.circle.fill").foregroundStyle(.teal) }
            else { Button(tr("开启", "Enable"), action: action).buttonStyle(QuietButton()) }
        }.padding(14).background(Palette.card, in: RoundedRectangle(cornerRadius: 10))
    }
    private func shortcut(_ key: String, _ title: String) -> some View {
        HStack { Text(key).font(.system(size: 12, weight: .medium, design: .monospaced)).frame(width: 66, alignment: .leading); Text(title).font(.system(size: 12)) }
    }
    private func finish() { settings.options.onboardingDone = true; navigation.onboarding = false }
}
