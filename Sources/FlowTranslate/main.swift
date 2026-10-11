import AppKit
import FlowCore

if let index = CommandLine.arguments.firstIndex(of: "--render-design"), CommandLine.arguments.count > index + 1 {
    MainActor.assumeIsolated {
        do { try DesignVerification.render(to: URL(fileURLWithPath: CommandLine.arguments[index + 1])); exit(0) }
        catch { fputs("DESIGN FAIL: \(error)\n", stderr); exit(1) }
    }
}

if CommandLine.arguments.contains("--ocr-expanded-test") {
    do { try FeatureVerification.ocr(); exit(0) }
    catch { fputs("OCR FAIL: \(error)\n", stderr); exit(1) }
}

if CommandLine.arguments.contains("--keychain-status") {
    FeatureVerification.keychainStatus()
    exit(0)
}
if CommandLine.arguments.contains("--feature-smoke-test") {
    MainActor.assumeIsolated {
        do { try FeatureVerification.run(); exit(0) }
        catch { fputs("APP FEATURES FAIL: \(error)\n", stderr); exit(1) }
    }
}

if let index = CommandLine.arguments.firstIndex(of: "--dictionary-smoke-test"), CommandLine.arguments.count > index + 1 {
    let endpoint = CommandLine.arguments[index + 1]
    Task {
        do {
            let entry = try await APITranslator.explain("bank", context: "We sat by the river bank.", target: "zh-Hans", configuration: APIConfiguration(endpoint: endpoint, model: "deepseek-v4-pro", key: "fixture-key")) { value in
                if value.contains("{") || value.contains("meaning") { preconditionFailure("JSON syntax leaked") }
            }
            precondition(entry.word == "bank" && entry.meaning == "河岸" && entry.language == "en")
            print("DICTIONARY PASS: streamed structured definition"); exit(0)
        } catch { fputs("DICTIONARY FAIL: \(error)\n", stderr); exit(1) }
    }
    RunLoop.main.run()
}

if CommandLine.arguments.contains("--ocr-smoke-test") {
    do {
        let start = Date()
        let result = try OCR.recognize(OCR.fixtureImage(), screenRect: CGRect(x: 0, y: 0, width: 1100, height: 200), pointer: nil, wordOnly: false)
        guard result.text.contains("translation") else { throw AppError.message("OCR fixture mismatch: \(result.text)") }
        print("OCR PASS: \(result.text) (\(String(format: "%.3f", Date().timeIntervalSince(start)))s)")
        exit(0)
    } catch { fputs("OCR FAIL: \(error)\n", stderr); exit(1) }
}

if let index = CommandLine.arguments.firstIndex(of: "--api-smoke-test"), CommandLine.arguments.count > index + 1 {
    let endpoint = CommandLine.arguments[index + 1]
    Task {
        do {
            let result = try await APITranslator.translate("Hello", target: "zh-Hans", configuration: APIConfiguration(endpoint: endpoint, model: "deepseek-v4-pro", key: "fixture-key")) { value in
                print("STREAM: \(value)")
            }
            print("API PASS: \(result)")
            exit(0)
        } catch { fputs("API FAIL: \(error)\n", stderr); exit(1) }
    }
    RunLoop.main.run()
}

if let index = CommandLine.arguments.firstIndex(of: "--model-smoke-test"), CommandLine.arguments.count > index + 1 {
    let endpoint = CommandLine.arguments[index + 1]
    Task { @MainActor in
        let suite = "FlowTranslateVerification-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(defaults: defaults, loadKey: false)
        settings.endpoint = endpoint
        settings.model = "deepseek-v4-pro"
        settings.apiKey = "fixture-key"
        let model = TranslationModel(settings: settings)
        @MainActor func wait() async throws {
            let deadline = Date().addingTimeInterval(8)
            while model.busy && Date() < deadline { try await Task.sleep(for: .milliseconds(25)) }
            guard !model.busy else { throw AppError.message("Model did not complete") }
        }
        do {
            model.text("slow", mode: "验证")
            try await Task.sleep(for: .milliseconds(100))
            model.text("new", mode: "验证")
            try await wait()
            guard model.output == "新的翻译", model.error.isEmpty else { throw AppError.message("Latest result mismatch") }
            try await Task.sleep(for: .milliseconds(700))
            guard model.output == "新的翻译" else { throw AppError.message("Stale result overwrote latest") }
            model.text("new", mode: "验证")
            try await wait()
            guard model.fromCache else { throw AppError.message("Cache miss") }
            model.text("truncated", mode: "验证")
            try await wait()
            guard !model.error.isEmpty else { throw AppError.message("Truncated stream was accepted") }
            model.text("truncated", mode: "验证")
            try await wait()
            guard !model.fromCache else { throw AppError.message("Failure was cached") }
            print("MODEL PASS: cancellation, latest request, cache, incomplete streams")
            defaults.removePersistentDomain(forName: suite)
            exit(0)
        } catch { defaults.removePersistentDomain(forName: suite); fputs("MODEL FAIL: \(error)\n", stderr); exit(1) }
    }
    RunLoop.main.run()
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppController()
    app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
}
