import AppKit
import UniformTypeIdentifiers
import CryptoKit
import FlowCore

enum VocabularyExporter {
    @MainActor static func save(_ words: [VocabularyWord], format: VocabularyFormat) throws -> Bool {
        let panel = NSSavePanel()
        let ext = format == .anki ? "apkg" : (format == .csv ? "csv" : "txt")
        panel.nameFieldStringValue = "Flow Translate.\(ext)"
        panel.allowedContentTypes = [UTType(filenameExtension: ext) ?? .data]
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        try write(words, format: format, to: url)
        return true
    }
    static func write(_ words: [VocabularyWord], format: VocabularyFormat, to url: URL) throws {
        if format == .csv { try VocabularyExport.csv(words).write(to: url, atomically: true, encoding: .utf8); return }
        if format == .text { try VocabularyExport.text(words).write(to: url, atomically: true, encoding: .utf8); return }
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("FlowTranslate-export-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: temp) }
        let database = temp.appendingPathComponent("collection.anki2")
        let sqlURL = temp.appendingPathComponent("collection.sql")
        try schemaAndData(words).write(to: sqlURL, atomically: true, encoding: .utf8)
        let input = try FileHandle(forReadingFrom: sqlURL)
        defer { try? input.close() }
        try run("/usr/bin/sqlite3", ["-bail", database.path], directory: temp, input: input)
        try "{}".write(to: temp.appendingPathComponent("media"), atomically: true, encoding: .utf8)
        let archive = temp.appendingPathComponent("export.apkg")
        try run("/usr/bin/zip", ["-q", archive.path, "collection.anki2", "media"], directory: temp)
        try Data(contentsOf: archive).write(to: url, options: .atomic)
    }
    private static func run(_ executable: String, _ arguments: [String], directory: URL, input: FileHandle? = nil) throws {
        let process = Process(), errors = Pipe()
        process.executableURL = URL(fileURLWithPath: executable); process.arguments = arguments; process.currentDirectoryURL = directory
        process.standardInput = input ?? FileHandle.nullDevice; process.standardOutput = FileHandle.nullDevice; process.standardError = errors
        try process.run()
        let message = errors.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw AppError.message("导出失败：\(String(data: message, encoding: .utf8) ?? "Archive error")") }
    }
    // Legacy Anki schema 11, compatible with the standard .apkg importer.
    // Format reference: https://github.com/kerrickstaley/genanki/blob/main/genanki/apkg_schema.py
    private static func schemaAndData(_ words: [VocabularyWord]) throws -> String {
        let now = Int64(Date().timeIntervalSince1970), modelID: Int64 = 1832048201, deckID: Int64 = 1832048202
        func q(_ value: String) -> String { "'" + value.replacingOccurrences(of: "\0", with: "").replacingOccurrences(of: "'", with: "''") + "'" }
        func json(_ value: Any) throws -> String { String(data: try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]), encoding: .utf8)! }
        let names = ["Word", "Meaning", "Phonetic", "PartOfSpeech", "Context", "ContextTranslation", "Example", "ExampleTranslation", "Expansion"]
        let fields: [[String: Any]] = names.enumerated().map { ["name": $0.element, "ord": $0.offset, "sticky": false, "rtl": false, "font": "Arial", "size": 20, "media": []] }
        let template: [String: Any] = ["name": "Word", "ord": 0, "qfmt": "<div class=word>{{Word}}</div><p>{{Context}}</p>", "afmt": "{{FrontSide}}<hr id=answer><p>{{Phonetic}} {{PartOfSpeech}}</p><h3>{{Meaning}}</h3><p>{{Expansion}}</p><p>{{ContextTranslation}}</p><p>{{Example}}<br>{{ExampleTranslation}}</p>", "bqfmt": "", "bafmt": "", "did": NSNull()]
        let model: [String: Any] = ["id": modelID, "name": "Flow Translate · Context", "type": 0, "mod": now, "usn": -1, "sortf": 0, "did": deckID, "tmpls": [template], "flds": fields, "css": ".card{font-family:Arial;font-size:20px;text-align:left;padding:24px;line-height:1.6}.word{font-size:32px;font-weight:bold}p{font-size:16px;opacity:.8}", "latexPre": "", "latexPost": "", "latexsvg": false, "req": [[0, "all", [0]]], "tags": [], "vers": []]
        let deck: [String: Any] = ["id": deckID, "name": "Flow Translate", "desc": "Saved words and context", "mod": now, "usn": -1, "collapsed": false, "browserCollapsed": false, "dyn": 0, "conf": 1, "extendNew": 10, "extendRev": 50, "newToday": [0, 0], "revToday": [0, 0], "lrnToday": [0, 0], "timeToday": [0, 0]]
        let config: [String: Any] = ["id": 1, "name": "Default", "mod": 0, "usn": 0, "maxTaken": 60, "autoplay": true, "replayq": true, "timer": 0,
           "new": ["bury": true, "delays": [1, 10], "initialFactor": 2500, "ints": [1, 4, 7], "order": 1, "perDay": 20],
           "rev": ["bury": true, "ease4": 1.3, "fuzz": 0.05, "ivlFct": 1, "maxIvl": 36500, "perDay": 200, "minSpace": 1],
           "lapse": ["delays": [10], "leechAction": 0, "leechFails": 8, "minInt": 1, "mult": 0]]
        let conf: [String: Any] = ["activeDecks": [deckID], "curDeck": deckID, "curModel": "\(modelID)", "nextPos": words.count + 1, "newSpread": 0, "collapseTime": 1200, "timeLim": 0, "sortType": "noteFld", "sortBackwards": false, "addToCur": true, "dueCounts": true, "estTimes": true]
        var sql = """
        PRAGMA journal_mode=DELETE;
        BEGIN;
        CREATE TABLE col (id integer primary key, crt integer not null, mod integer not null, scm integer not null, ver integer not null, dty integer not null, usn integer not null, ls integer not null, conf text not null, models text not null, decks text not null, dconf text not null, tags text not null);
        CREATE TABLE notes (id integer primary key, guid text not null, mid integer not null, mod integer not null, usn integer not null, tags text not null, flds text not null, sfld integer not null, csum integer not null, flags integer not null, data text not null);
        CREATE TABLE cards (id integer primary key, nid integer not null, did integer not null, ord integer not null, mod integer not null, usn integer not null, type integer not null, queue integer not null, due integer not null, ivl integer not null, factor integer not null, reps integer not null, lapses integer not null, left integer not null, odue integer not null, odid integer not null, flags integer not null, data text not null);
        CREATE TABLE revlog (id integer primary key, cid integer not null, usn integer not null, ease integer not null, ivl integer not null, lastIvl integer not null, factor integer not null, time integer not null, type integer not null);
        CREATE TABLE graves (usn integer not null, oid integer not null, type integer not null);
        CREATE INDEX ix_notes_usn ON notes(usn);
        CREATE INDEX ix_notes_csum ON notes(csum);
        CREATE INDEX ix_cards_usn ON cards(usn);
        CREATE INDEX ix_cards_nid ON cards(nid);
        CREATE INDEX ix_cards_sched ON cards(did,queue,due);
        CREATE INDEX ix_revlog_usn ON revlog(usn);
        CREATE INDEX ix_revlog_cid ON revlog(cid);
        """
        sql += "\nINSERT INTO col VALUES (1,\(now),\(now * 1000),\(now * 1000),11,0,-1,0,\(q(try json(conf))),\(q(try json(["\(modelID)": model]))),\(q(try json(["\(deckID)": deck]))),\(q(try json(["1": config]))),'{}');\n"
        for (index, word) in words.enumerated() {
            let e = word.explanation, id = now * 1000 + Int64(index)
            let values = [e.word, e.meaning, e.phonetic, e.partOfSpeech, e.context, e.contextTranslation, e.example, e.exampleTranslation, e.expansion]
            let flds = values.map { VocabularyExport.html($0.replacingOccurrences(of: "\u{1f}", with: " ")) }.joined(separator: "\u{1f}")
            let guid = SHA256.hash(data: Data(word.identity.utf8)).prefix(10).map { String(format: "%02x", $0) }.joined()
            let checksum = Insecure.SHA1.hash(data: Data(e.word.utf8)).prefix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
            sql += "INSERT INTO notes VALUES(\(id),\(q(guid)),\(modelID),\(now),-1,' FlowTranslate ',\(q(flds)),\(q(e.word)),\(checksum),0,'');\n"
            sql += "INSERT INTO cards VALUES(\(id),\(id),\(deckID),0,\(now),-1,0,0,\(index + 1),0,0,0,0,0,0,0,0,'');\n"
        }
        return sql + "COMMIT;\n"
    }
}
