import AppKit
import ScreenCaptureKit
import Vision
import FlowCore

struct OCRResult {
    let text: String
    let context: String
    let rect: CGRect
}

@MainActor
final class ScreenCapture {
    func capture(_ rect: CGRect) async throws -> (CGImage, CGRect) {
        guard CGPreflightScreenCaptureAccess() else {
            throw AppError.message("请先在首页开启屏幕录制权限；授权后可能需要退出并重新打开Flow Translate。")
        }
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let globalRect = ScreenGeometry.captureRect(rect, primaryHeight: primaryHeight)
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.frame.contains(CGPoint(x: globalRect.midX, y: globalRect.midY)) }) else {
            throw AppError.message("没有找到所选屏幕。请在同一块屏幕内框选。")
        }
        let clipped = globalRect.intersection(display.frame)
        guard clipped.width >= 3, clipped.height >= 3 else { throw AppError.message("选择的区域太小。") }
        let ownApps = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
        let filter = SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: [])
        let config = SCStreamConfiguration()
        let screen = NSScreen.screens.first { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == display.displayID }
        let scale = screen?.backingScaleFactor ?? 2
        config.sourceRect = CGRect(x: clipped.minX - display.frame.minX, y: clipped.minY - display.frame.minY,
                                   width: clipped.width, height: clipped.height)
        config.width = max(1, Int(clipped.width * scale))
        config.height = max(1, Int(clipped.height * scale))
        config.showsCursor = false
        config.captureResolution = .best
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        return (image, ScreenGeometry.appKitRect(clipped, primaryHeight: primaryHeight))
    }
}

enum OCR {
    static func recognize(_ image: CGImage, screenRect: CGRect, pointer: CGPoint?, wordOnly: Bool) throws -> OCRResult {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.automaticallyDetectsLanguage = true
        request.usesLanguageCorrection = true
        let supported = try request.supportedRecognitionLanguages()
        request.recognitionLanguages = ["en-US", "zh-Hans", "zh-Hant", "ja-JP", "ko-KR", "fr-FR", "de-DE", "es-ES", "pt-BR", "it-IT", "ru-RU"].filter { supported.contains($0) }
        try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        var observations = request.results ?? []
        var orientation: CGImagePropertyOrientation = .up
        func score(_ values: [VNRecognizedTextObservation]) -> Double {
            values.reduce(0) { total, observation in
                guard let text = observation.topCandidates(1).first else { return total }
                return total + Double(text.confidence) * Double(text.string.filter { $0.isLetter || $0.isNumber }.count)
            }
        }
        // Sparse/tall recognition gets orientation retries; ordinary horizontal
        // text retains the single-pass fast path.
        if score(observations) < 8 || observations.contains(where: { $0.boundingBox.height * screenRect.height > $0.boundingBox.width * screenRect.width * 2 }) {
            for candidateOrientation: CGImagePropertyOrientation in [.right, .left] {
                try VNImageRequestHandler(cgImage: image, orientation: candidateOrientation, options: [:]).perform([request])
                let candidate = request.results ?? []
                if score(candidate) > score(observations) * 1.1 {
                    observations = candidate; orientation = candidateOrientation
                }
            }
        }
        let width = screenRect.width
        let height = screenRect.height
        func localRect(_ box: CGRect) -> CGRect {
            let original: CGRect
            switch orientation {
            case .right: original = CGRect(x: 1 - box.maxY, y: box.minX, width: box.height, height: box.width)
            case .left: original = CGRect(x: box.minY, y: 1 - box.maxX, width: box.height, height: box.width)
            default: original = box
            }
            return CGRect(x: original.minX * width, y: (1 - original.maxY) * height, width: original.width * width, height: original.height * height)
        }
        let entries = observations.compactMap { observation -> (VNRecognizedText, TextLine)? in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            return (candidate, TextLine(text: candidate.string, rect: localRect(observation.boundingBox)))
        }
        guard !entries.isEmpty else { throw AppError.message("这个区域没有识别到文字。试着放大内容或重新框选。") }
        let ordered = TextPicking.readingOrder(entries.map { $0.1 })
        guard let pointer else {
            return OCRResult(text: ordered.map(\.text).joined(separator: "\n"), context: "", rect: screenRect)
        }
        let point = CGPoint(x: pointer.x - screenRect.minX, y: screenRect.maxY - pointer.y)
        guard let line = TextPicking.nearestLine(ordered, to: point),
              let entry = entries.first(where: { $0.1.text == line.text && $0.1.rect == line.rect }) else {
            throw AppError.message("鼠标附近没有文字。把指针移到字上再按 ⌥ Space，或使用框选。")
        }
        if wordOnly {
            let candidate = entry.0
            // Vision supplies character-range boxes, avoiding proportional-font guesses.
            var picked: (String, CGRect, NSRange)?
            candidate.string.enumerateSubstrings(in: candidate.string.startIndex..<candidate.string.endIndex, options: [.byWords, .localized]) { substring, range, _, _ in
                guard substring != nil else { return }
                let expanded = Self.compoundRange(range, in: candidate.string)
                guard let observation = try? candidate.boundingBox(for: expanded) else { return }
                let box = localRect(observation.boundingBox)
                if box.insetBy(dx: -3, dy: -5).contains(point) {
                    picked = (String(candidate.string[expanded]), box, NSRange(expanded, in: candidate.string))
                }
            }
            if let picked {
                let context = ContextSentence.extract(anchor: line, wordRange: picked.2, lines: ordered)
                let box = CGRect(x: screenRect.minX + picked.1.minX, y: screenRect.maxY - picked.1.maxY, width: picked.1.width, height: picked.1.height)
                return OCRResult(text: picked.0, context: context, rect: box)
            }
        }
        let box = CGRect(x: screenRect.minX + line.rect.minX, y: screenRect.maxY - line.rect.maxY, width: line.rect.width, height: line.rect.height)
        return OCRResult(text: line.text, context: "", rect: box)
    }

    static func compoundRange(_ range: Range<String.Index>, in text: String) -> Range<String.Index> {
        func latin(_ c: Character) -> Bool { c.isASCII && (c.isLetter || c.isNumber || "-_’'".contains(c)) }
        guard text[range].allSatisfy(latin) else { return range }
        var lower = range.lowerBound, upper = range.upperBound
        while lower > text.startIndex, latin(text[text.index(before: lower)]) { lower = text.index(before: lower) }
        while upper < text.endIndex, latin(text[upper]) { upper = text.index(after: upper) }
        return lower..<upper
    }

    static func fixtureImage() -> CGImage {
        let width = 1100, height = 200
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let text = NSAttributedString(string: "Fast translation keeps you in the flow.", attributes: [
            .font: NSFont.systemFont(ofSize: 38), .foregroundColor: NSColor.black
        ])
        let line = CTLineCreateWithAttributedString(text)
        context.textPosition = CGPoint(x: 30, y: 95)
        CTLineDraw(line, context)
        return context.makeImage()!
    }
}
