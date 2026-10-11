import Foundation

public struct WordExplanation: Codable, Equatable {
    public var word: String
    public var phonetic: String
    public var partOfSpeech: String
    public var language: String
    public var meaning: String
    public var context: String
    public var contextTranslation: String
    public var example: String
    public var exampleTranslation: String
    public var expansion: String
    public init(word: String, meaning: String, language: String = "", phonetic: String = "", partOfSpeech: String = "",
                context: String = "", contextTranslation: String = "", example: String = "", exampleTranslation: String = "", expansion: String = "") {
        self.word = word; self.meaning = meaning; self.language = language; self.phonetic = phonetic
        self.partOfSpeech = partOfSpeech; self.context = context; self.contextTranslation = contextTranslation
        self.example = example; self.exampleTranslation = exampleTranslation; self.expansion = expansion
    }
    enum CodingKeys: String, CodingKey { case word, phonetic, partOfSpeech, language, meaning, context, contextTranslation, example, exampleTranslation, expansion }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func string(_ k: CodingKeys) -> String { (try? c.decodeIfPresent(String.self, forKey: k)) ?? "" }
        word = string(.word); meaning = string(.meaning); language = string(.language); phonetic = string(.phonetic)
        partOfSpeech = string(.partOfSpeech); context = string(.context); contextTranslation = string(.contextTranslation)
        example = string(.example); exampleTranslation = string(.exampleTranslation); expansion = string(.expansion)
        guard !word.isEmpty, !meaning.isEmpty else { throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Missing word or meaning")) }
    }
    public static func parse(_ raw: String) throws -> Self {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let fence = String(repeating: String(UnicodeScalar(96)), count: 3)
        if text.hasPrefix(fence), let first = text.firstIndex(of: "\n"), let last = text.range(of: fence, options: .backwards), first < last.lowerBound {
            text = String(text[text.index(after: first)..<last.lowerBound])
        }
        return try JSONDecoder().decode(Self.self, from: Data(text.utf8))
    }
}

/// Extracts only a complete or streaming JSON string field, never JSON syntax.
public enum PartialJSON {
    public static func string(_ field: String, in input: String) -> String {
        guard let key = input.range(of: "\"\(field)\""), let colon = input[key.upperBound...].firstIndex(of: ":") else { return "" }
        let tail = input[input.index(after: colon)...].drop(while: { $0.isWhitespace })
        guard tail.first == "\"" else { return "" }
        var encoded = "\""
        var escaping = false
        for ch in tail.dropFirst() {
            if ch == "\"" && !escaping { encoded.append(ch); return (try? JSONDecoder().decode(String.self, from: Data(encoded.utf8))) ?? "" }
            encoded.append(ch)
            if escaping { escaping = false } else if ch == "\\" { escaping = true }
        }
        if escaping { encoded.removeLast() }
        if let range = encoded.range(of: "\\u", options: .backwards), encoded.distance(from: range.upperBound, to: encoded.endIndex) < 4 {
            encoded = String(encoded[..<range.lowerBound])
        }
        return (try? JSONDecoder().decode(String.self, from: Data((encoded + "\"").utf8))) ?? ""
    }
}

public enum ReviewGrade: Int, CaseIterable, Codable { case again = 0, hard = 1, good = 2, easy = 3 }

public struct ReviewSchedule: Codable, Equatable {
    public var due: Date
    public var intervalDays: Double = 0
    public var ease: Double = 2.5
    public var repetitions: Int = 0
    public var lapses: Int = 0
    public var suspended: Bool = false
    public var lastReviewed: Date?
    public init(now: Date = Date()) { due = now }
    public var mastered: Bool { repetitions >= 3 && intervalDays >= 21 }
    public mutating func review(_ grade: ReviewGrade, now: Date = Date()) {
        suspended = false; lastReviewed = now
        switch grade {
        case .again:
            lapses += 1; repetitions = 0; ease = max(1.3, ease - 0.2)
            intervalDays = 10.0 / 1440
        case .hard:
            repetitions += 1; ease = max(1.3, ease - 0.15)
            intervalDays = max(1, intervalDays * 1.2)
        case .good:
            repetitions += 1
            intervalDays = repetitions == 1 ? 1 : (repetitions == 2 ? 3 : max(1, intervalDays * ease))
        case .easy:
            repetitions += 1; ease = min(3.5, ease + 0.15)
            intervalDays = max(4, intervalDays * ease * 1.3)
        }
        intervalDays = min(3650, intervalDays)
        due = now.addingTimeInterval(intervalDays * 86400)
    }
}

public struct VocabularyWord: Codable, Identifiable, Equatable {
    public var id: UUID
    public var explanation: WordExplanation
    public var target: String
    public var createdAt: Date
    public var schedule: ReviewSchedule
    public init(explanation: WordExplanation, target: String, now: Date = Date()) {
        id = UUID(); self.explanation = explanation; self.target = target; createdAt = now; schedule = ReviewSchedule(now: now)
    }
    public var identity: String { Self.identity(word: explanation.word, language: explanation.language, target: target) }
    public static func identity(word: String, language: String, target: String) -> String {
        [word.trimmingCharacters(in: .whitespacesAndNewlines).folding(options: [.caseInsensitive], locale: Locale(identifier: "en_US_POSIX")), language, target].joined(separator: "\u{0}")
    }
}

public enum VocabularyFormat: String, CaseIterable { case csv, anki, text }
public enum VocabularyExport {
    public static func csv(_ words: [VocabularyWord]) -> String {
        let header = ["Word", "Meaning", "Phonetic", "Part of speech", "Language", "Target language", "Context", "Context translation", "Example", "Example translation", "Expansion", "Created", "Next review", "State"]
        let format = ISO8601DateFormatter()
        let rows = words.map { w -> [String] in
            let e = w.explanation
            return [e.word, e.meaning, e.phonetic, e.partOfSpeech, e.language, w.target, e.context, e.contextTranslation, e.example, e.exampleTranslation, e.expansion,
                    format.string(from: w.createdAt), format.string(from: w.schedule.due), w.schedule.suspended ? "paused" : (w.schedule.mastered ? "mastered" : "learning")]
        }
        func cell(_ s: String) -> String {
            let value = ["=", "+", "-", "@", "\t", "\r"].contains(where: { s.hasPrefix($0) }) ? "'" + s : s
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return "\u{FEFF}" + ([header] + rows).map { $0.map(cell).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
    }
    public static func text(_ words: [VocabularyWord]) -> String {
        words.map { $0.explanation.word.replacingOccurrences(of: "\n", with: " ") }.joined(separator: "\n") + "\n"
    }
    public static func html(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;").replacingOccurrences(of: "\n", with: "<br>")
    }
}
