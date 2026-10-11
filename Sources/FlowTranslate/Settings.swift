import AppKit
import Combine
import Security
import Carbon

struct Shortcut: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32
    var key: String
    var label: String {
        (modifiers & UInt32(controlKey) != 0 ? "⌃" : "") +
        (modifiers & UInt32(optionKey) != 0 ? "⌥" : "") +
        (modifiers & UInt32(shiftKey) != 0 ? "⇧" : "") +
        (modifiers & UInt32(cmdKey) != 0 ? "⌘" : "") + " " + key
    }
}

struct AppOptions: Codable, Equatable {
    var modifier = "leftOption"
    var modifierTap = true
    var modifierClick = true
    var modifierDrag = true
    var plainClick = false
    var autoHover = false
    var hoverDelay = 0.75
    var preferSelection = true
    var paused = false
    var excludedApps = ""
    var autoSpeak = false
    var englishVoice = "en-US"
    var appearance = "light"
    var uiLanguage = "zh"
    var showDock = false
    var reviewBadge = true
    var onboardingDone = false
    var shortcuts: [String: Shortcut] = [
        "lookup": Shortcut(keyCode: 49, modifiers: UInt32(optionKey), key: "Space"),
        "area": Shortcut(keyCode: 15, modifiers: UInt32(optionKey), key: "R"),
        "selection": Shortcut(keyCode: 1, modifiers: UInt32(optionKey), key: "S"),
        "input": Shortcut(keyCode: 34, modifiers: UInt32(optionKey), key: "I")
    ]
    static func load(_ data: Data?) -> Self {
        guard let data,
              let saved = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let initial = try? JSONEncoder().encode(Self()),
              var defaults = try? JSONSerialization.jsonObject(with: initial) as? [String: Any] else { return Self() }
        defaults.merge(saved) { _, new in new }
        guard let merged = try? JSONSerialization.data(withJSONObject: defaults),
              let value = try? JSONDecoder().decode(Self.self, from: merged) else { return Self() }
        return value
    }
}

enum TranslationProvider: String, CaseIterable, Identifiable {
    case system, compatibleAPI
    var id: String { rawValue }
    var title: String { self == .system ? "Apple 系统翻译" : "兼容 OpenAI 的 API" }
}

@MainActor
final class AppSettings: ObservableObject {
    @Published var provider: TranslationProvider { didSet { save() } }
    @Published var endpoint: String { didSet { save() } }
    @Published var model: String { didSet { save() } }
    @Published var target: String { didSet { save() } }
    @Published var alternate: String { didSet { save() } }
    @Published var hoverWord: Bool { didSet { save() } }
    @Published var fastMode: Bool { didSet { save() } }
    @Published var apiKey: String = ""
    @Published var keyMessage = ""
    @Published var revision = 0
    @Published var screenPermission = CGPreflightScreenCaptureAccess()
    @Published var accessibilityPermission = AXIsProcessTrusted()
    @Published var hotkeyMessage = ""
    @Published var options: AppOptions { didSet { save() } }
    @Published var keyRequiresUnlock = false
    @Published var keyBusy = false
    @Published var triggerMessage = ""
    var onChange: (() -> Void)?
    var needsAPIKey: Bool { provider == .compatibleAPI && URL(string: endpoint)?.host == "api.deepseek.com" && apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    func tr(_ chinese: String, _ english: String) -> String { options.uiLanguage == "en" ? english : chinese }

    static let languages = [("zh-Hans", "简体中文"), ("zh-Hant", "繁體中文"), ("en", "English"), ("ja", "日本語"), ("ko", "한국어"), ("fr", "Français"), ("de", "Deutsch"), ("es", "Español"), ("pt", "Português"), ("it", "Italiano"), ("ru", "Русский")]
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard, loadKey: Bool = true) {
        self.defaults = defaults
        let d = defaults
        provider = TranslationProvider(rawValue: d.string(forKey: "provider") ?? "compatibleAPI") ?? .compatibleAPI
        endpoint = d.string(forKey: "endpoint") ?? "https://api.deepseek.com"
        model = d.string(forKey: "model") ?? "deepseek-flash"
        target = d.string(forKey: "target") ?? "zh-Hans"
        alternate = d.string(forKey: "alternate") ?? "en"
        hoverWord = d.object(forKey: "hoverWord") as? Bool ?? true
        fastMode = d.object(forKey: "fastMode") as? Bool ?? true
        options = AppOptions.load(d.data(forKey: "options"))
        if loadKey {
            let result = KeyStore.readResult(allowUI: false)
            apiKey = result.value ?? ""
            keyRequiresUnlock = result.status != errSecSuccess && result.status != errSecItemNotFound
        }
    }
    private func save() {
        defaults.set(provider.rawValue, forKey: "provider")
        defaults.set(endpoint, forKey: "endpoint")
        defaults.set(model, forKey: "model")
        defaults.set(target, forKey: "target")
        defaults.set(alternate, forKey: "alternate")
        defaults.set(hoverWord, forKey: "hoverWord")
        defaults.set(fastMode, forKey: "fastMode")
        defaults.set(try? JSONEncoder().encode(options), forKey: "options")
        revision += 1
        onChange?()
    }
    func saveKey() { Task { _ = await persistKey() } }
    @discardableResult func persistKey() async -> Bool {
        guard !keyBusy else { return false }
        let value = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return false }
        keyBusy = true
        let status = await Task.detached(priority: .userInitiated) { KeyStore.write(value) }.value
        keyBusy = false
        keyMessage = status == errSecSuccess ? tr("已保存到系统钥匙串", "Saved to Keychain") : tr("钥匙串写入失败（\(status)），原有 Key 未替换。", "Keychain save failed (\(status)). The previous key is unchanged.")
        if status == errSecSuccess { keyRequiresUnlock = false }
        revision += 1
        return status == errSecSuccess
    }
    func unlockKey() {
        guard !keyBusy else { return }
        keyBusy = true
        keyMessage = tr("正在等待系统授权…", "Waiting for system authorization…")
        Task {
            let result = await Task.detached(priority: .userInitiated) { KeyStore.unlock() }.value
            keyBusy = false
            if let value = result.value {
                apiKey = value; keyRequiresUnlock = false
                keyMessage = result.persistenceStatus == errSecSuccess
                    ? tr("已连接钥匙串；当前版本可在重启后读取。", "Keychain connected. This build can read the key after reopening.")
                    : tr("本次已解锁，但未能保存当前版本的读取授权（\(result.persistenceStatus)）。", "Unlocked for this session, but could not persist this build's access (\(result.persistenceStatus)).")
            } else {
                keyMessage = tr("尚未授权读取 Key，可重试或重新填写。", "Key access was not granted. Retry or enter a key.")
            }
        }
    }
    func refreshPermissions() {
        screenPermission = CGPreflightScreenCaptureAccess()
        accessibilityPermission = AXIsProcessTrusted()
    }
    func requestScreenPermission() {
        _ = CGRequestScreenCaptureAccess()
        refreshPermissions()
        if !screenPermission { openPrivacy("ScreenCapture") }
    }
    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        refreshPermissions()
        if !accessibilityPermission { openPrivacy("Accessibility") }
    }
    func openPrivacy(_ name: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_\(name)") {
            NSWorkspace.shared.open(url)
        }
    }
}
