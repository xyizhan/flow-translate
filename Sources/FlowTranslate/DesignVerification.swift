import AppKit
import SwiftUI
import FlowCore

/// Renders the real views with isolated, generated data. No visible windows, global
/// listeners, network requests, or user vocabulary are used by this check.
@MainActor enum DesignVerification {
    static func render(to output: URL) throws {
        let fm = FileManager.default
        let path = fm.temporaryDirectory.appendingPathComponent("FlowTranslate-design-\(UUID().uuidString)")
        let suite = "FlowTranslate-design-\(UUID().uuidString)", defaults = UserDefaults(suiteName: suite)!
        defer { try? fm.removeItem(at: path); defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(defaults: defaults, loadKey: false)
        settings.screenPermission = true; settings.accessibilityPermission = true
        settings.options.onboardingDone = true
        let learning = LearningStore(directory: path, defaults: defaults)
        let fixtures = [
            WordExplanation(word: "serendipity", meaning: "意外发现美好事物的机缘；意外的收获", language: "en", phonetic: "/ˌserənˈdɪpəti/", partOfSpeech: "名词", context: "Finding this quiet bookshop was pure serendipity.", contextTranslation: "发现这家安静的书店，完全是一场美丽的巧合。"),
            WordExplanation(word: "bank", meaning: "河岸；河畔", language: "en", phonetic: "/bæŋk/", partOfSpeech: "名词", context: "The bank was covered with wild flowers.", contextTranslation: "河岸上长满了野花。"),
            WordExplanation(word: "plausible", meaning: "看似合理的；说得通的", language: "en", phonetic: "/ˈplɔːzəbəl/", partOfSpeech: "形容词", context: "The simplest plausible explanation is that the result depends on context, and we can verify it with a separate experiment.", contextTranslation: "最简单、说得通的解释是：这个结果取决于上下文，我们可以通过另一个实验来验证。"),
            WordExplanation(word: "comprendre", meaning: "理解；领会", language: "fr", phonetic: "/kɔ̃.pʁɑ̃dʁ/", partOfSpeech: "动词", context: "Lire chaque jour aide à mieux comprendre le monde.", contextTranslation: "每天阅读有助于更好地理解世界。")
        ]
        for item in fixtures { learning.add(item, target: "zh-Hans"); learning.record(item, target: "zh-Hans") }
        let controller = AppController(settings: settings, learning: learning)
        try fm.createDirectory(at: output, withIntermediateDirectories: true)
        for dark in [false, true] {
            for page in ["home", "vocabulary", "review"] {
                controller.navigation.page = page
                let view = MainView(settings: settings, learning: learning, navigation: controller.navigation, controller: controller)
                    .frame(width: 920, height: 690).environment(\.colorScheme, dark ? .dark : .light)
                // ImageRenderer omits AppKit-backed scroll views. Lay out the
                // real hosting view in an offscreen window and cache its pixels.
                let host = NSHostingView(rootView: view)
                let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 920, height: 690), styleMask: .borderless, backing: .buffered, defer: false)
                window.isReleasedWhenClosed = false
                window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
                window.contentView = host
                host.layoutSubtreeIfNeeded()
                RunLoop.main.run(until: Date().addingTimeInterval(0.1))
                guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw AppError.message("No bitmap for \(page)") }
                host.cacheDisplay(in: host.bounds, to: bitmap)
                window.close()
                guard let data = bitmap.representation(using: .png, properties: [:]) else {
                    throw AppError.message("Could not render \(page)")
                }
                let file = output.appendingPathComponent("\(page)-\(dark ? "dark" : "light").png")
                try data.write(to: file)
                print("DESIGN RENDER: \(file.path)")
            }
        }
        try renderResults(to: output, settings: settings, learning: learning)
    }

    private static func renderResults(to output: URL, settings: AppSettings, learning: LearningStore) throws {
        var report: [[String: Any]] = []
        for dark in [false, true] {
            let model = TranslationModel(settings: settings), voice = Pronunciation()
            let window = NSPanel(contentRect: CGRect(x: 0, y: 0, width: ResultMetrics.width, height: 128), styleMask: [.borderless, .resizable, .nonactivatingPanel], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
            window.backgroundColor = .windowBackgroundColor
            var measured: CGFloat = 0
            let view = ResultView(model: model, learning: learning, voice: voice, preferences: settings, close: {}, pin: {}, openSettings: {}, contentHeightChanged: { height in
                DispatchQueue.main.async {
                    measured = height
                    let next = ResultMetrics.height(content: height, available: 900)
                    if abs(window.frame.height - next) > 0.5 {
                        window.setContentSize(CGSize(width: window.frame.width, height: next))
                    }
                }
            }).environment(\.colorScheme, dark ? .dark : .light)
            let host = NSHostingView(rootView: view); host.sizingOptions = []
            window.contentView = host
            for state in ["word", "paragraph", "long", "short-again", "loading", "error"] {
                model.source = ""; model.output = ""; model.error = ""; model.explanation = nil
                model.busy = false; model.dictionary = false; model.elapsed = 1.85; model.phase = "翻译完成"
                model.mode = "语境取词"; model.sourceCode = "en"; model.isExample = false
                switch state {
                case "word", "short-again":
                    model.dictionary = true; model.source = "the"
                    model.output = "用于特指已知或上下文中明确的人或事物"
                    model.explanation = WordExplanation(word: model.source, meaning: model.output, language: "en", phonetic: "/ðə/", partOfSpeech: "冠词", context: "Select a region of the screen and translate it.", contextTranslation: "选择屏幕上的一个区域并翻译它。")
                case "paragraph":
                    model.mode = "框选翻译"
                    model.source = "Read across languages, without losing your train of thought."
                    model.output = "跨越语言阅读，让思绪顺畅延续。"
                case "long":
                    model.mode = "框选翻译"
                    model.source = Array(repeating: "Read across languages, without losing your train of thought.", count: 12).joined(separator: "\n")
                    model.output = Array(repeating: "跨越语言阅读，让思绪顺畅延续。", count: 12).joined(separator: "\n")
                case "loading": model.busy = true; model.phase = "正在识别屏幕文字"
                default: model.error = "连接超时，请检查网络连接后重试。"; model.phase = "需要处理"
                }
                host.layoutSubtreeIfNeeded()
                RunLoop.main.run(until: Date().addingTimeInterval(0.35))
                host.layoutSubtreeIfNeeded()
                let height = window.frame.height
                guard measured > 0, abs(height - ResultMetrics.height(content: measured, available: 900)) < 1 else { throw AppError.message("Result failed to fit: \(state), \(height), \(measured)") }
                if state == "long" {
                    guard height == ResultMetrics.maximumHeight, measured > height else { throw AppError.message("Long result did not scroll") }
                } else if state == "word" || state == "short-again" {
                    guard height < 245, height >= measured + ResultMetrics.chromeHeight else { throw AppError.message("Word result clipped or did not shrink: \(height)") }
                }
                guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw AppError.message("No bitmap for result") }
                host.cacheDisplay(in: host.bounds, to: bitmap)
                guard let png = bitmap.representation(using: .png, properties: [:]) else { throw AppError.message("No result PNG") }
                let name = "result-\(state)-\(dark ? "dark" : "light")"
                try png.write(to: output.appendingPathComponent(name + ".png"))
                report.append(["fixture": name, "width": window.frame.width, "height": height, "contentHeight": measured])
                print("RESULT LAYOUT PASS: \(name) \(window.frame.width) × \(height), content \(measured)")
            }
            window.close()
        }
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("result-layout.json"))
    }
}
