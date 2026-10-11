import AppKit
import FlowCore

enum FeatureVerification {
    @MainActor static func run() throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("FlowTranslate-check-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: path) }
        let name = "FlowTranslate-check-\(UUID().uuidString)", defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let entry = WordExplanation(word: "bank", meaning: "河岸", language: "en", phonetic: "/bæŋk/", context: "We sat on the bank of the river.")
        let store = LearningStore(directory: path, defaults: defaults)
        precondition(store.add(entry, target: "zh-Hans"))
        precondition(store.add(entry, target: "zh-Hans") && store.words.count == 1)
        let id = store.words[0].id
        store.remove(id); precondition(store.words.isEmpty); store.undo(); precondition(store.words.count == 1)
        store.review(id, grade: .good)
        let reload = LearningStore(directory: path, defaults: defaults)
        precondition(reload.words.count == 1 && reload.words[0].schedule.repetitions == 1 && reload.due.isEmpty)
        let words = reload.words
        try Data("damaged".utf8).write(to: reload.fileURL)
        let corrupt = LearningStore(directory: path, defaults: defaults)
        precondition(!corrupt.error.isEmpty && corrupt.canRecover)
        precondition(!corrupt.add(entry, target: "zh-Hans"))
        let preserved = try String(contentsOf: corrupt.fileURL, encoding: .utf8)
        precondition(preserved == "damaged")
        corrupt.recoverBackup(); precondition(corrupt.error.isEmpty && corrupt.words.count == 1)
        // Undo must not recreate a duplicate after the same word was saved again.
        let restoredID = corrupt.words[0].id
        corrupt.remove(restoredID)
        precondition(corrupt.add(entry, target: "zh-Hans"))
        corrupt.undo(); precondition(corrupt.words.count == 1 && !corrupt.canUndo)
        // History survives a new store instance, but never enrolls a word by itself.
        for index in 0..<45 { corrupt.record(WordExplanation(word: "word\(index)", meaning: "Meaning \(index)"), target: "zh-Hans") }
        let lastID = corrupt.recent[0].id, lastDate = corrupt.recent[0].date
        corrupt.record(entry, target: "zh-Hans", includeRecent: false)
        let historyReload = LearningStore(directory: path, defaults: defaults)
        precondition(historyReload.recent.count == 40 && historyReload.lookupCount == 46 && historyReload.words.count == 1)
        precondition(historyReload.recent.first?.id == lastID && historyReload.recent.first?.date == lastDate)
        precondition(historyReload.recent.first?.explanation.word == "word44" && historyReload.recent.last?.explanation.word == "word5")
        for url in [corrupt.fileURL, corrupt.fileURL.appendingPathExtension("backup"), corrupt.historyURL] {
            let mode = try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber
            precondition(mode?.intValue == 0o600)
        }
        // A failed disk write must not advance a card or change its pause state.
        let moved = path.appendingPathExtension("moved")
        try FileManager.default.moveItem(at: path, to: moved)
        defer { try? FileManager.default.removeItem(at: moved) }
        try Data("not a directory".utf8).write(to: path)
        let schedule = historyReload.words[0].schedule, reviewID = historyReload.words[0].id
        precondition(!historyReload.review(reviewID, grade: .easy))
        precondition(historyReload.words[0].schedule == schedule && !historyReload.error.isEmpty)
        precondition(!historyReload.suspend(reviewID, value: true) && !historyReload.words[0].schedule.suspended)
        try FileManager.default.removeItem(at: path)
        try FileManager.default.moveItem(at: moved, to: path)
        // Preserve unreadable history instead of overwriting it on the next lookup.
        try Data("damaged history".utf8).write(to: corrupt.historyURL)
        let brokenHistory = LearningStore(directory: path, defaults: defaults)
        precondition(!brokenHistory.historyError.isEmpty && brokenHistory.words.count == 1)
        brokenHistory.record(entry, target: "zh-Hans")
        let historyBytes = try String(contentsOf: corrupt.historyURL, encoding: .utf8)
        precondition(historyBytes == "damaged history" && brokenHistory.recent.count == 1)
        let output = path.appendingPathComponent("fixture.apkg")
        try VocabularyExporter.write(words, format: .anki, to: output)
        print("APP FEATURES PASS: vocabulary/history reload, 40-entry history limit, private file modes, deduplication, undo/re-add, review write-failure rollback, corruption preservation/recovery, Anki archive")
    }
    static func keychainStatus() {
        let start = Date(), result = KeyStore.readResult(allowUI: false)
        print("KEYCHAIN NONINTERACTIVE: status=\(result.status), hasCredential=\(result.value != nil), elapsed=\(String(format: "%.3f", Date().timeIntervalSince(start)))s")
    }
    static func ocr() throws {
        let original = OCR.fixtureImage()
        for degrees in [0.0, 8.0, 90.0] {
            let size = 1300
            let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            ctx.setFillColor(NSColor.white.cgColor); ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
            ctx.translateBy(x: CGFloat(size) / 2, y: CGFloat(size) / 2); ctx.rotate(by: degrees * .pi / 180)
            ctx.draw(original, in: CGRect(x: -550, y: -100, width: 1100, height: 200))
            let result = try OCR.recognize(ctx.makeImage()!, screenRect: CGRect(x: 0, y: 0, width: size, height: size), pointer: nil, wordOnly: false)
            guard result.text.contains("translation") && result.text.contains("flow") else { throw AppError.message("OCR rotation \(degrees): \(result.text)") }
            print("OCR ROTATION PASS: \(Int(degrees)) degrees")
        }
        let compound = "a state-of-the-art getUserName function"
        let range = compound.range(of: "state")!
        precondition(String(compound[OCR.compoundRange(range, in: compound)]) == "state-of-the-art")
        print("OCR COMPOUND PASS")
        try contextSentences()
    }

    private static func contextSentences() throws {
        typealias Row = (text: String, x: CGFloat, y: CGFloat, size: CGFloat)
        let fixtures: [(rows: [Row], anchor: Int, word: String, expected: String)] = [
            ([("TextEdit File Edit Format View Window Help", 20, 230, 16),
              ("2 4 6 8 10 12 14 16", 50, 202, 16),
              ("The bank was covered with wild flowers.", 50, 164, 26),
              ("Fast translation keeps you in the flow.", 50, 128, 26),
              ("Select a region of the screen and translate it.", 50, 92, 26)],
             2, "with", "The bank was covered with wild flowers."),
            ([("Previous sentence. The bank was", 50, 194, 26),
              ("covered with wild flowers along", 50, 158, 26),
              ("the river. We went home.", 50, 122, 26),
              ("Unrelated sidebar", 650, 158, 26)],
             1, "with", "The bank was covered with wild flowers along the river."),
            ([("We went to the bank. The river bank was green.", 50, 160, 26)],
             0, "bank", "The river bank was green.")
        ]
        for (index, fixture) in fixtures.enumerated() {
            let rect = CGRect(x: 0, y: 0, width: 1000, height: 260)
            let ctx = CGContext(data: nil, width: 1000, height: 260, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            ctx.setFillColor(NSColor.white.cgColor); ctx.fill(rect)
            var pointer = CGPoint.zero
            for (rowIndex, row) in fixture.rows.enumerated() {
                let attributed = NSAttributedString(string: row.text, attributes: [.font: NSFont.systemFont(ofSize: row.size), .foregroundColor: NSColor.black])
                let line = CTLineCreateWithAttributedString(attributed)
                ctx.textPosition = CGPoint(x: row.x, y: row.y)
                CTLineDraw(line, ctx)
                if rowIndex == fixture.anchor {
                    let range = (row.text as NSString).range(of: fixture.word, options: .backwards)
                    let start = CTLineGetOffsetForStringIndex(line, range.location, nil)
                    let end = CTLineGetOffsetForStringIndex(line, NSMaxRange(range), nil)
                    pointer = CGPoint(x: row.x + (start + end) / 2, y: row.y + row.size * 0.35)
                }
            }
            let image = ctx.makeImage()!
            let result = try OCR.recognize(image, screenRect: rect, pointer: pointer, wordOnly: true)
            guard result.text == fixture.word && result.context == fixture.expected else {
                throw AppError.message("OCR context \(index): word=[\(result.text)] sentence=[\(result.context)]")
            }
            if index == 0 {
                let area = try OCR.recognize(image, screenRect: rect, pointer: nil, wordOnly: false)
                guard area.text.contains("TextEdit") && area.text.contains("Select a region") else {
                    throw AppError.message("Area OCR unexpectedly filtered selected content")
                }
            }
            print("OCR CONTEXT PASS \(index + 1): \(result.text) → \(result.context)")
        }
    }
}
