import AppKit
import SwiftUI
import Carbon

struct SettingsPage: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var navigation: Navigation
    let controller: AppController
    private var tab: String { navigation.settingsTab }
    @State private var recording: String?
    private func tr(_ zh: String, _ en: String) -> String { settings.tr(zh, en) }
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(tr("设置", "Settings")).font(.system(size: 29, weight: .semibold))
            Picker("", selection: $navigation.settingsTab) {
                Text(tr("通用", "General")).tag("general")
                Text(tr("翻译服务", "Translation")).tag("api")
                Text(tr("取词与快捷键", "Gestures & keys")).tag("gestures")
            }.pickerStyle(.segmented).labelsHidden()
            switch tab { case "api": api; case "gestures": gestures; default: general }
        }
        .sheet(item: $recording) { kind in
            VStack(spacing: 20) {
                Text(tr("按下新的快捷键", "Press a new shortcut")).font(.title3.weight(.semibold))
                Text(tr("需包含 Command、Option 或 Control；Esc 取消。", "Include Command, Option, or Control. Esc cancels.")).font(.caption).foregroundStyle(.secondary)
                ShortcutRecorder { shortcut in
                    if let shortcut { settings.options.shortcuts[kind] = shortcut }
                    recording = nil
                }.frame(width: 300, height: 54)
                Button(tr("取消", "Cancel")) { recording = nil }
            }.padding(30).frame(width: 400)
        }
    }
    private var general: some View {
        VStack(spacing: 16) {
            Paper {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        section(tr("当前运行的Flow Translate", "Running application"))
                        Spacer()
                        Text(BuildIdentity.version).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    if let date = BuildIdentity.date {
                        Text(tr("构建于 ", "Built ") + date.formatted(date: .numeric, time: .standard))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Text(BuildIdentity.appURL.path).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                    HStack {
                        Button(tr("在访达中显示此版本", "Show this version in Finder")) {
                            NSWorkspace.shared.activateFileViewerSelecting([BuildIdentity.appURL])
                        }.buttonStyle(.plain).font(.caption)
                        Spacer()
                        Text(BuildIdentity.buildID).font(.system(size: 10, design: .monospaced)).foregroundStyle(.tertiary).textSelection(.enabled)
                    }
                }
            }
            Paper {
                VStack(alignment: .leading, spacing: 16) {
                    section(tr("权限", "Permissions"))
                    permission(tr("屏幕录制", "Screen recording"), detail: tr("截图在本机识别，只发送识别出的文字。", "OCR runs locally. Only recognized text is sent."), ready: settings.screenPermission, action: settings.requestScreenPermission)
                    Divider()
                    permission(tr("辅助功能", "Accessibility"), detail: tr("用于 Option 手势、自动悬停和读取选中文字。", "For Option gestures, auto-hover and selected text."), ready: settings.accessibilityPermission, action: settings.requestAccessibility)
                    if !settings.triggerMessage.isEmpty { Text(settings.triggerMessage).font(.caption).foregroundStyle(.secondary) }
                    Button(tr("刷新状态", "Refresh status")) { settings.refreshPermissions() }.buttonStyle(.plain).font(.caption).foregroundStyle(.secondary)
                    if !settings.screenPermission || !settings.accessibilityPermission {
                        Text(tr("更新后开关已开启但仍未生效时，请先退出并重开Flow Translate；仍无效时，在系统设置中移除旧记录，再添加上方显示的此版本。", "If access is enabled after an update but still unavailable, quit and reopen Flow Translate. If needed, remove the old entry in System Settings and add the application shown above."))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Paper {
                VStack(alignment: .leading, spacing: 17) {
                    section(tr("外观与运行", "Appearance & startup"))
                    Picker(tr("外观", "Appearance"), selection: $settings.options.appearance) {
                        Text(tr("跟随系统", "System")).tag("system"); Text(tr("浅色", "Light")).tag("light"); Text(tr("深色", "Dark")).tag("dark")
                    }
                    Picker(tr("界面语言", "Interface language"), selection: $settings.options.uiLanguage) { Text("简体中文").tag("zh"); Text("English").tag("en") }
                    Toggle(tr("在 Dock 显示图标", "Show Dock icon"), isOn: $settings.options.showDock)
                    Toggle(tr("菜单栏显示待复习数量", "Show due count in menu bar"), isOn: $settings.options.reviewBadge)
                    Toggle(tr("登录时自动启动", "Launch at login"), isOn: Binding(get: { controller.launchAtLogin }, set: { controller.setLaunchAtLogin($0) }))
                    if !navigation.loginMessage.isEmpty { Text(navigation.loginMessage).font(.caption).foregroundStyle(.orange) }
                }
            }
            Paper {
                VStack(alignment: .leading, spacing: 17) {
                    section(tr("发音", "Pronunciation"))
                    Picker(tr("英语口音", "English voice"), selection: $settings.options.englishVoice) { Text(tr("美式", "American")).tag("en-US"); Text(tr("英式", "British")).tag("en-GB") }
                    Toggle(tr("取词后自动朗读", "Speak words automatically"), isOn: $settings.options.autoSpeak)
                    Text(tr("再次点击发音按钮，切换为 75% 慢速；其他语言使用系统对应语音。", "Click pronunciation again for 75% speed. Other languages use their system voice.")).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
    private var api: some View {
        VStack(spacing: 16) {
            Paper {
                VStack(alignment: .leading, spacing: 18) {
                    section(tr("翻译引擎", "Translation engine"))
                    Picker(tr("服务", "Provider"), selection: $settings.provider) {
                        Text("DeepSeek / OpenAI API").tag(TranslationProvider.compatibleAPI)
                        Text(tr("Apple 系统翻译", "Apple Translation")).tag(TranslationProvider.system)
                    }
                    if settings.provider == .compatibleAPI {
                        field(tr("API 地址", "API endpoint")) { TextField("https://api.deepseek.com", text: $settings.endpoint) }
                        field(tr("模型", "Model")) { TextField("deepseek-flash", text: $settings.model) }
                        HStack {
                            Text("DeepSeek Flash").font(.caption).foregroundStyle(.secondary); Spacer()
                            Button(tr("使用默认配置", "Use defaults")) { settings.endpoint = "https://api.deepseek.com"; settings.model = "deepseek-flash"; settings.fastMode = true }.buttonStyle(.plain).font(.caption)
                        }
                        field("API Key") { SecureField(tr("输入 API Key", "Enter API key"), text: $settings.apiKey).disabled(settings.keyBusy) }
                        HStack {
                            Button(tr("保存到钥匙串", "Save to Keychain")) { settings.saveKey() }.buttonStyle(QuietButton()).disabled(settings.keyBusy || settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            if settings.keyRequiresUnlock {
                                Button(tr("解锁已保存的 Key", "Unlock saved key")) { settings.unlockKey() }.buttonStyle(QuietButton()).disabled(settings.keyBusy)
                            }
                        }
                        Text(settings.keyRequiresUnlock ? tr("已保存的 Key 需要系统授权。点击解锁后，macOS 才会显示授权窗口。", "Your saved key needs permission. macOS asks only when you click Unlock.") : tr("Key 保存在这台 Mac 的系统钥匙串中。", "Your key is stored in this Mac's system Keychain.")).font(.caption).foregroundStyle(.secondary)
                        if !settings.keyMessage.isEmpty { Text(settings.keyMessage).font(.caption).foregroundStyle(.secondary) }
                        Toggle(tr("快速模式（关闭 DeepSeek 思考）", "Fast mode (disable DeepSeek thinking)"), isOn: $settings.fastMode)
                    } else {
                        Text(tr("首次使用可能需要下载系统语言包。语境词典使用 API 引擎时提供完整字段。", "Language packs may be downloaded on first use. Use the API engine for full contextual dictionary details.")).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Paper {
                VStack(alignment: .leading, spacing: 18) {
                    section(tr("语言", "Languages"))
                    Picker(tr("目标语言", "Target language"), selection: $settings.target) { ForEach(AppSettings.languages, id: \.0) { Text($0.1).tag($0.0) } }
                    Picker(tr("第二目标语言", "Alternate target"), selection: $settings.alternate) { ForEach(AppSettings.languages, id: \.0) { Text($0.1).tag($0.0) } }
                    Text(tr("原文与目标语言相同时，自动翻译为第二目标语言。", "When source and target match, the alternate target is used.")).font(.caption).foregroundStyle(.secondary)
                    Button(tr("测试翻译", "Test translation")) { controller.translateInput("Fast translation keeps you in the flow.") }.buttonStyle(QuietButton())
                    Button(tr("查看浮窗示例（不调用 API）", "Preview result card (no API request)")) { controller.showExample() }.buttonStyle(.plain).font(.caption).foregroundStyle(.secondary)
                }
            }
        }.textFieldStyle(.roundedBorder)
    }
    private var gestures: some View {
        VStack(spacing: 16) {
            Paper {
                VStack(alignment: .leading, spacing: 17) {
                    section(tr("取词方式", "Lookup gestures"))
                    Picker(tr("修饰键", "Modifier"), selection: $settings.options.modifier) {
                        Text(tr("左 Option", "Left Option")).tag("leftOption")
                        Text(tr("右 Option", "Right Option")).tag("rightOption")
                        Text("Control + Option").tag("controlOption")
                    }
                    Toggle(tr("轻按修饰键，翻译鼠标下的词", "Tap modifier to look up a word"), isOn: $settings.options.modifierTap)
                    Toggle(tr("修饰键 + 点击取词", "Modifier + click to look up"), isOn: $settings.options.modifierClick)
                    Toggle(tr("修饰键 + 拖动框选", "Modifier + drag to select a region"), isOn: $settings.options.modifierDrag)
                    Toggle(tr("普通点击也取词", "Look up on ordinary clicks"), isOn: $settings.options.plainClick)
                    Toggle(tr("自动悬停取词", "Automatic hover lookup"), isOn: $settings.options.autoHover)
                    if settings.options.autoHover {
                        HStack {
                            Text(tr("停留延迟", "Dwell time"))
                            Slider(value: $settings.options.hoverDelay, in: 0.35...2, step: 0.05)
                            Text(String(format: "%.2fs", settings.options.hoverDelay)).monospacedDigit().frame(width: 48)
                        }
                    }
                    Toggle(tr("取词快捷键优先翻译选中文字", "Prefer selected text for lookup shortcut"), isOn: $settings.options.preferSelection)
                    Toggle(tr("优先识别单词", "Recognize individual words"), isOn: $settings.hoverWord)
                    Toggle(tr("暂停所有全局取词", "Pause global lookup"), isOn: $settings.options.paused)
                    field(tr("排除应用（名称或 Bundle ID，每行一个）", "Excluded apps (name or bundle ID, one per line)")) {
                        TextEditor(text: $settings.options.excludedApps).font(.system(size: 12)).frame(height: 55).border(Palette.stroke)
                    }
                }
            }
            Paper {
                VStack(alignment: .leading, spacing: 15) {
                    section(tr("键盘快捷键", "Keyboard shortcuts"))
                    shortcut("lookup", tr("鼠标取词", "Word lookup"))
                    shortcut("area", tr("框选翻译", "Region translation"))
                    shortcut("selection", tr("选中文字", "Selected text"))
                    shortcut("input", tr("输入翻译", "Text input"))
                    if !settings.hotkeyMessage.isEmpty { Text(settings.hotkeyMessage).font(.caption).foregroundStyle(.orange) }
                    Button(tr("恢复默认快捷键", "Reset shortcuts")) { settings.options.shortcuts = AppOptions().shortcuts }.buttonStyle(.plain).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
    private func section(_ title: String) -> some View { Text(title).font(.system(size: 14, weight: .semibold)) }
    private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 7) { Text(title).font(.system(size: 11)).foregroundStyle(.secondary); content() }
    }
    private func permission(_ title: String, detail: String, ready: Bool, action: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) { Text(title); Text(detail).font(.system(size: 11)).foregroundStyle(.secondary) }
            Spacer()
            if ready { Image(systemName: "checkmark.circle").foregroundStyle(.secondary) }
            else { Button(tr("开启", "Enable"), action: action).buttonStyle(QuietButton()) }
        }
    }
    private func shortcut(_ kind: String, _ title: String) -> some View {
        HStack { Text(title); Spacer(); Button(settings.options.shortcuts[kind]?.label ?? "—") { recording = kind }.buttonStyle(QuietButton()).monospaced() }
    }
}
extension String: @retroactive Identifiable { public var id: String { self } }

struct ShortcutRecorder: NSViewRepresentable {
    let complete: (Shortcut?) -> Void
    func makeNSView(context: Context) -> RecorderView {
        let view = RecorderView(); view.complete = complete
        DispatchQueue.main.async { view.window?.makeFirstResponder(view) }; return view
    }
    func updateNSView(_ nsView: RecorderView, context: Context) {}
}
final class RecorderView: NSView {
    var complete: ((Shortcut?) -> Void)?
    override var acceptsFirstResponder: Bool { true }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { complete?(nil); return }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard !flags.intersection([.command, .option, .control]).isEmpty else { NSSound.beep(); return }
        var mask: UInt32 = 0
        if flags.contains(.command) { mask |= UInt32(cmdKey) }; if flags.contains(.option) { mask |= UInt32(optionKey) }
        if flags.contains(.control) { mask |= UInt32(controlKey) }; if flags.contains(.shift) { mask |= UInt32(shiftKey) }
        let key = event.keyCode == 49 ? "Space" : (event.charactersIgnoringModifiers?.uppercased() ?? "\(event.keyCode)")
        complete?(Shortcut(keyCode: UInt32(event.keyCode), modifiers: mask, key: key))
    }
    override func draw(_ dirtyRect: NSRect) {
        ("⌘  ⌥  ⇧  ⌃" as NSString).draw(at: CGPoint(x: 75, y: 12), withAttributes: [.font: NSFont.systemFont(ofSize: 24), .foregroundColor: NSColor.secondaryLabelColor])
    }
}

