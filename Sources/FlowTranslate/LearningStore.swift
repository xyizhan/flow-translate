import Foundation
import Combine
import FlowCore
import AVFoundation

struct RecentLookup: Identifiable, Codable {
    let id: UUID
    let explanation: WordExplanation
    let target: String
    let date: Date
    init(explanation: WordExplanation, target: String, date: Date = Date()) {
        id = UUID(); self.explanation = explanation; self.target = target; self.date = date
    }
}

@MainActor
final class LearningStore: ObservableObject {
    @Published private(set) var words: [VocabularyWord] = []
    @Published private(set) var recent: [RecentLookup] = []
    @Published private(set) var lookupCount = 0
    @Published var error = ""
    @Published private(set) var historyError = ""
    @Published private(set) var canUndo = false
    private var removed: (VocabularyWord, Int)?
    let fileURL: URL
    let historyURL: URL
    private let defaults: UserDefaults
    private var loadFailed = false
    private var historyLoadFailed = false
    struct Archive: Codable { var version = 1; var words: [VocabularyWord] }
    struct HistoryArchive: Codable { var version = 1; var items: [RecentLookup] }
    init(directory: URL? = nil, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("FlowTranslate")
        fileURL = directory.appendingPathComponent("vocabulary.json")
        historyURL = directory.appendingPathComponent("history.json")
        lookupCount = defaults.integer(forKey: "lookupCount")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do { words = try JSONDecoder().decode(Archive.self, from: Data(contentsOf: fileURL)).words }
            catch {
                self.error = "生词本读取失败，原文件已保留。请检查 \(fileURL.path)"
                loadFailed = true
            }
        }
        if FileManager.default.fileExists(atPath: historyURL.path) {
            do {
                let archive = try JSONDecoder().decode(HistoryArchive.self, from: Data(contentsOf: historyURL))
                guard archive.version == 1 else { throw CocoaError(.coderReadCorrupt) }
                recent = Array(archive.items.prefix(40))
            } catch {
                historyLoadFailed = true
                historyError = "最近查询读取失败，原文件已保留。本次新查询暂时只保留在内存中。"
            }
        }
    }
    var due: [VocabularyWord] { words.filter { !$0.schedule.suspended && $0.schedule.due <= Date() }.sorted { $0.schedule.due < $1.schedule.due } }
    var masteredCount: Int { words.filter { $0.schedule.mastered }.count }
    var canRecover: Bool { loadFailed && FileManager.default.fileExists(atPath: fileURL.appendingPathExtension("backup").path) }
    func recoverBackup() {
        do {
            let data = try Data(contentsOf: fileURL.appendingPathExtension("backup"))
            let restored = try JSONDecoder().decode(Archive.self, from: data)
            let preserved = fileURL.appendingPathExtension("damaged-\(Int(Date().timeIntervalSince1970))")
            try FileManager.default.copyItem(at: fileURL, to: preserved)
            try Self.writePrivate(data, to: fileURL)
            words = restored.words; loadFailed = false; error = ""
        } catch { self.error = "备份恢复失败：\(error.localizedDescription)" }
    }
    func record(_ explanation: WordExplanation, target: String, includeRecent: Bool = true) {
        lookupCount += 1; defaults.set(lookupCount, forKey: "lookupCount")
        guard includeRecent else { return }
        recent.insert(RecentLookup(explanation: explanation, target: target), at: 0)
        if recent.count > 40 { recent.removeLast(recent.count - 40) }
        guard !historyLoadFailed else { return }
        do {
            let data = try JSONEncoder().encode(HistoryArchive(items: recent))
            try Self.writePrivate(data, to: historyURL)
            historyError = ""
        } catch { historyError = "最近查询保存失败：\(error.localizedDescription)" }
    }
    func saved(_ e: WordExplanation, target: String) -> VocabularyWord? {
        words.first { $0.identity == VocabularyWord.identity(word: e.word, language: e.language, target: target) }
    }
    @discardableResult func add(_ e: WordExplanation, target: String) -> Bool {
        guard saved(e, target: target) == nil else { return true }
        let before = words
        words.insert(VocabularyWord(explanation: e, target: target), at: 0)
        let success = commit(previous: before)
        if success, removed?.0.identity == VocabularyWord.identity(word: e.word, language: e.language, target: target) {
            removed = nil; canUndo = false
        }
        return success
    }
    func remove(_ id: UUID) {
        guard let index = words.firstIndex(where: { $0.id == id }) else { return }
        let before = words, word = words[index]
        words.remove(at: index)
        if commit(previous: before) { removed = (word, index); canUndo = true }
    }
    func undo() {
        guard let (word, index) = removed else { return }
        guard !words.contains(where: { $0.identity == word.identity }) else { removed = nil; canUndo = false; return }
        let before = words
        words.insert(word, at: min(index, words.count))
        if commit(previous: before) { removed = nil; canUndo = false }
    }
    @discardableResult func review(_ id: UUID, grade: ReviewGrade, now: Date = Date()) -> Bool {
        guard let index = words.firstIndex(where: { $0.id == id }) else { return false }
        let before = words
        words[index].schedule.review(grade, now: now)
        return commit(previous: before)
    }
    @discardableResult func suspend(_ id: UUID, value: Bool) -> Bool {
        guard let index = words.firstIndex(where: { $0.id == id }) else { return false }
        let before = words
        words[index].schedule.suspended = value
        if !value { words[index].schedule.due = Date() }
        return commit(previous: before)
    }
    private func commit(previous: [VocabularyWord]) -> Bool {
        guard !loadFailed else { words = previous; return false }
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(Archive(words: words))
            // Keep the last readable version without replacing the current file before encoding succeeds.
            if let old = try? Data(contentsOf: fileURL) { try Self.writePrivate(old, to: fileURL.appendingPathExtension("backup")) }
            try Self.writePrivate(data, to: fileURL)
            error = ""; return true
        } catch { words = previous; self.error = "生词本保存失败：\(error.localizedDescription)"; return false }
    }
    private static func writePrivate(_ data: Data, to url: URL) throws {
        let directory = url.deletingLastPathComponent(), fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let temporary = directory.appendingPathComponent(".write-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: temporary) }
        guard fm.createFile(atPath: temporary.path, contents: nil, attributes: [.posixPermissions: 0o600]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let handle = try FileHandle(forWritingTo: temporary)
        do { try handle.write(contentsOf: data); try handle.synchronize(); try handle.close() }
        catch { try? handle.close(); throw error }
        guard rename(temporary.path, url.path) == 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
    }
}

@MainActor
final class Pronunciation: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published var speaking = false
    @Published var slow = false
    private let synthesizer = AVSpeechSynthesizer()
    private var last = ""
    override init() { super.init(); synthesizer.delegate = self }
    func say(_ text: String, language: String, englishVoice: String, automatic: Bool = false) {
        guard !text.isEmpty else { return }
        slow = !automatic && text == last ? !slow : false
        last = text
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        let code = language.hasPrefix("en") || language.isEmpty ? englishVoice : language
        utterance.voice = AVSpeechSynthesisVoice(language: code)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * (slow ? 0.75 : 1)
        speaking = true; synthesizer.speak(utterance)
    }
    func stop() { synthesizer.stopSpeaking(at: .immediate); speaking = false }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) { Task { @MainActor in self.speaking = self.synthesizer.isSpeaking } }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) { Task { @MainActor in self.speaking = self.synthesizer.isSpeaking } }
}
