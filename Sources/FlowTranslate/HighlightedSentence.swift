import SwiftUI

struct HighlightedSentence: View {
    let sentence: String
    let word: String
    var highlightColor: Color = .primary
    var highlightBackground: Color = .blue.opacity(0.09)
    var body: some View { Text(highlighted) }
    private var highlighted: AttributedString {
        var result = AttributedString(sentence)
        guard !word.isEmpty else { return result }
        let boundary = word.first?.isASCII == true ? "[\\p{L}\\p{N}_]" : ""
        let escaped = NSRegularExpression.escapedPattern(for: word)
        let pattern = boundary.isEmpty ? escaped : "(?<!\(boundary))\(escaped)(?!\(boundary))"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return result }
        for match in regex.matches(in: sentence, range: NSRange(sentence.startIndex..., in: sentence)) {
            guard let range = Range(match.range, in: sentence),
                  let start = AttributedString.Index(range.lowerBound, within: result),
                  let end = AttributedString.Index(range.upperBound, within: result) else { continue }
            result[start..<end].inlinePresentationIntent = .stronglyEmphasized
            result[start..<end].foregroundColor = highlightColor
            result[start..<end].backgroundColor = highlightBackground
        }
        return result
    }
}

@MainActor func languageName(_ code: String, settings: AppSettings) -> String {
    guard !code.isEmpty else { return "" }
    return Locale(identifier: settings.options.uiLanguage == "en" ? "en" : "zh-Hans")
        .localizedString(forLanguageCode: code) ?? code
}
