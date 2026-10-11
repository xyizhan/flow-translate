import AppKit
import Combine
import NaturalLanguage
import Translation
import CryptoKit
import FlowCore

@MainActor
final class TranslationModel: ObservableObject {
    @Published var source = ""
    @Published var context = ""
    @Published var output = ""
    @Published var phase = "准备翻译"
    @Published var error = ""
    @Published var busy = false
    @Published var elapsed: TimeInterval = 0
    @Published var ocrElapsed: TimeInterval = 0
    @Published var fromCache = false
    @Published var requestID = UUID()
    @Published var appleConfiguration: TranslationSession.Configuration?
    @Published var targetName = "简体中文"
    @Published var mode = "框选翻译"
    @Published var isExample = false
    @Published var explanation: WordExplanation?
    @Published var pinned = false
    @Published var targetCode = "zh-Hans"
    @Published var sourceCode = ""
    @Published var dictionary = false
    var onFinish: ((TranslationModel) -> Void)?
    private var task: Task<Void, Never>?
    private var started = Date()
    private static var cache: [String: (String, WordExplanation?, Date)] = [:]
    private var activeCacheKey = ""
    let settings: AppSettings

    init(settings: AppSettings) { self.settings = settings }

    func begin(_ mode: String, dictionary: Bool = false) -> UUID {
        task?.cancel()
        appleConfiguration = nil
        requestID = UUID()
        self.mode = mode
        self.dictionary = dictionary; explanation = nil
        source = ""; context = ""; output = ""; error = ""
        busy = true; fromCache = false; isExample = false
        elapsed = 0; ocrElapsed = 0; started = Date()
        phase = "正在识别屏幕文字"
        return requestID
    }
    func cancel() {
        if busy { phase = "已取消"; elapsed = Date().timeIntervalSince(started) }
        task?.cancel()
        task = nil
        appleConfiguration = nil
        requestID = UUID()
        busy = false
    }
    func launch(id: UUID, operation: @escaping () async throws -> OCRResult) {
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await operation()
                try Task.checkCancellation()
                guard self.requestID == id else { return }
                self.ocrElapsed = Date().timeIntervalSince(self.started)
                await self.translate(result.text, context: result.context, id: id)
            } catch is CancellationError {} catch {
                self.fail(error, id: id)
            }
        }
    }
    func text(_ text: String, mode: String, context: String = "", dictionary: Bool = false) {
        let id = begin(mode, dictionary: dictionary)
        task = Task { await translate(text, context: context, id: id) }
    }
    private func translate(_ text: String, context: String, id: UUID) async {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard requestID == id else { return }
        guard !text.isEmpty else { fail(AppError.message("请输入或框选需要翻译的文字。"), id: id); return }
        guard text.count <= 12000 else { fail(AppError.message("本次文字超过 12,000 字，请缩小框选范围或拆分输入。"), id: id); return }
        source = text; self.context = context
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(context.isEmpty ? text : context)
        let sourceCode = recognizer.dominantLanguage?.rawValue
        self.sourceCode = sourceCode ?? ""
        var target = settings.target
        if let sourceCode, sourceCode.prefix(2) == target.prefix(2), settings.alternate.prefix(2) != target.prefix(2) { target = settings.alternate }
        targetName = AppSettings.languages.first(where: { $0.0 == target })?.1 ?? target
        targetCode = target
        let keyHash = SHA256.hash(data: Data(settings.apiKey.utf8)).map { String(format: "%02x", $0) }.joined()
        activeCacheKey = [settings.provider.rawValue, settings.endpoint, settings.model, String(settings.fastMode), String(dictionary), keyHash, target, text, context].joined(separator: "\u{0}")
        if let hit = Self.cache[activeCacheKey], Date().timeIntervalSince(hit.2) < 1800 {
            output = hit.0; explanation = hit.1
            if let language = hit.1?.language, !language.isEmpty { self.sourceCode = language }
            fromCache = true; finish(id: id); return
        }
        phase = "正在翻译"
        if settings.provider == .system {
            appleConfiguration = TranslationSession.Configuration(source: sourceCode.map { Locale.Language(identifier: $0) }, target: Locale.Language(identifier: target))
            return
        }
        let config = APIConfiguration(endpoint: settings.endpoint, model: settings.model, key: settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines), fastMode: settings.fastMode)
        do {
            let update: @MainActor (String) -> Void = { [weak self] value in
                guard let self, self.requestID == id else { return }
                self.output = value
            }
            let result: String
            if dictionary {
                var entry = try await APITranslator.explain(text, context: context, target: target, configuration: config, update: update)
                try Task.checkCancellation()
                guard requestID == id else { return }
                // Preserve the actual OCR context, not an AI reconstruction of it.
                entry.context = context; entry.word = text
                if entry.language.isEmpty { entry.language = self.sourceCode }
                else { self.sourceCode = entry.language }
                explanation = entry; result = entry.meaning
            } else { result = try await APITranslator.translate(text, context: context, target: target, configuration: config, update: update) }
            try Task.checkCancellation()
            guard requestID == id else { return }
            output = result
            storeResult()
            finish(id: id)
        } catch is CancellationError {} catch { fail(error, id: id) }
    }
    func translateWithApple(_ session: TranslationSession, id: UUID) async {
        guard requestID == id, settings.provider == .system, !source.isEmpty else { return }
        let text = source
        do {
            let response = try await session.translate(text)
            try Task.checkCancellation()
            guard requestID == id else { return }
            output = response.targetText
            storeResult()
            finish(id: id)
        } catch is CancellationError {} catch { fail(error, id: id) }
    }
    private func storeResult() {
        guard !output.isEmpty else { return }
        if Self.cache.count >= 100, let oldest = Self.cache.min(by: { $0.value.2 < $1.value.2 })?.key { Self.cache.removeValue(forKey: oldest) }
        Self.cache[activeCacheKey] = (output, explanation, Date())
    }
    private func finish(id: UUID) {
        guard requestID == id else { return }
        busy = false; elapsed = Date().timeIntervalSince(started); phase = fromCache ? "来自内存缓存" : "翻译完成"
        onFinish?(self)
    }
    func fail(_ failure: Error, id: UUID) {
        guard requestID == id else { return }
        error = failure.localizedDescription
        phase = "需要处理"; busy = false; elapsed = Date().timeIntervalSince(started)
    }
    func showExample() {
        cancel()
        explanation = nil; dictionary = false; fromCache = false
        isExample = true; mode = "界面示例"; phase = "示例内容，未调用翻译服务"
        source = "Fast translation keeps you in the flow."
        output = "快速翻译，让阅读保持连贯。"
        context = ""; error = ""; targetName = "简体中文"; elapsed = 0
    }
    var entry: WordExplanation {
        explanation ?? WordExplanation(word: source, meaning: output, language: sourceCode, context: context)
    }
    var copyText: String {
        guard let e = explanation else { return output }
        return [e.word, e.phonetic, e.partOfSpeech, e.expansion, e.meaning, e.context, e.contextTranslation, e.example, e.exampleTranslation].filter { !$0.isEmpty }.joined(separator: "\n")
    }
    var saveable: Bool { !busy && error.isEmpty && !output.isEmpty && source.count <= 150 && !isExample }
}
