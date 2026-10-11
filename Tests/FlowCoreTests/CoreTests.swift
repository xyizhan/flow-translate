import Foundation
import CoreGraphics
import FlowCore

private func expectEqual<T: Equatable>(_ value: T, _ expected: T) { precondition(value == expected, "Expected \(expected), got \(value)") }
private func expectNil<T>(_ value: T?) { precondition(value == nil) }
private func expectTrue(_ value: Bool) { precondition(value) }
private func expectThrows<T>(_ value: @autoclosure () throws -> T) {
    do { _ = try value() } catch { return }
    preconditionFailure("Expected an error")
}

final class CoreTests {
    func testEndpointPreservesProviderPrefix() throws {
        expectEqual(try APIEndpoint.completions("https://example.com/v1/").absoluteString, "https://example.com/v1/chat/completions")
        expectEqual(try APIEndpoint.completions("https://example.com/api/openai/v1").path, "/api/openai/v1/chat/completions")
        expectEqual(try APIEndpoint.completions("https://example.com/v1/chat/completions").path, "/v1/chat/completions")
        expectEqual(try APIEndpoint.completions("http://127.0.0.1:8080/v1").port, 8080)
        expectEqual(try APIEndpoint.completions("https://api.deepseek.com").absoluteString, "https://api.deepseek.com/chat/completions")
    }
    func testRejectsCredentialBearingOrInsecureURLs() {
        for url in ["http://example.com/v1", "https://key@example.com/v1", "file:///tmp/x", "https://example.com/v1?key=secret", "not a url"] {
            expectThrows(try APIEndpoint.completions(url))
        }
    }
    func testSSECommentsMultilineCRLFAndEOF() {
        var parser = SSEParser()
        expectNil(parser.consume(": heartbeat"))
        expectNil(parser.consume("data: first\r"))
        expectNil(parser.consume("data: second\r"))
        expectEqual(parser.consume("\r"), "first\nsecond")
        expectNil(parser.consume("data: [DONE]"))
        expectEqual(parser.finish(), "[DONE]")
        expectNil(parser.finish())
    }
    func testTokenAndNonstreamingJSON() throws {
        let decoder = JSONDecoder()
        let delta = try decoder.decode(ChatResponse.self, from: Data(#"{"choices":[{"delta":{"content":"译文"}}]}"#.utf8))
        let message = try decoder.decode(ChatResponse.self, from: Data(#"{"choices":[{"message":{"content":"完整译文"}}]}"#.utf8))
        expectEqual(delta.text, "译文")
        expectEqual(message.text, "完整译文")
    }
    func testDeepSeekV4DisablesThinkingForFastTranslation() {
        for model in ["deepseek-flash", "deepseek-v4-flash", "deepseek-v4-pro"] {
            let body = TranslationRequest.body(text: "Hello", target: "zh-Hans", model: model, fastMode: true)
            expectEqual(body["model"] as? String, model)
            expectEqual((body["thinking"] as? [String: String])?["type"], "disabled")
        }
        expectNil(TranslationRequest.body(text: "Hello", target: "zh-Hans", model: "custom-model", fastMode: true)["thinking"])
    }
    func testReasoningAndUsageFramesNeverBecomeTranslation() throws {
        let decoder = JSONDecoder()
        let reasoning = try decoder.decode(ChatResponse.self, from: Data(#"{"choices":[{"delta":{"reasoning_content":"private reasoning"},"finish_reason":null}]}"#.utf8))
        expectEqual(reasoning.text, "")
        let usage = try decoder.decode(ChatResponse.self, from: Data(#"{"choices":[],"usage":{"total_tokens":5}}"#.utf8))
        expectEqual(usage.text, "")
    }
    func testMultipleMonitorCoordinatesRoundTrip() {
        for rect in [CGRect(x: 40, y: 120, width: 500, height: 200), CGRect(x: -1920, y: 0, width: 200, height: 50), CGRect(x: 100, y: 1200, width: 300, height: 90)] {
            let capture = ScreenGeometry.captureRect(rect, primaryHeight: 900)
            expectEqual(ScreenGeometry.appKitRect(capture, primaryHeight: 900), rect)
        }
    }
    func testPopupStaysOnNegativeOriginScreen() {
        let frame = CGRect(x: -1920, y: 0, width: 1920, height: 1080)
        let origin = ScreenGeometry.popupOrigin(anchor: CGRect(x: -20, y: 50, width: 10, height: 20), size: CGSize(width: 430, height: 400), visibleFrame: frame)
        expectTrue(frame.contains(CGRect(origin: origin, size: CGSize(width: 430, height: 400))))
    }
    func testHoverDoesNotPickUnrelatedColumn() {
        let lines = [TextLine(text: "Left", rect: CGRect(x: 0, y: 10, width: 100, height: 20)), TextLine(text: "Right", rect: CGRect(x: 300, y: 10, width: 100, height: 20))]
        expectEqual(TextPicking.nearestLine(lines, to: CGPoint(x: 350, y: 15))?.text, "Right")
        expectNil(TextPicking.nearestLine(lines, to: CGPoint(x: 200, y: 100)))
    }
}

@main
struct RunCoreChecks {
    static func main() throws {
        let tests = CoreTests()
        try tests.testEndpointPreservesProviderPrefix()
        tests.testRejectsCredentialBearingOrInsecureURLs()
        tests.testSSECommentsMultilineCRLFAndEOF()
        try tests.testTokenAndNonstreamingJSON()
        tests.testDeepSeekV4DisablesThinkingForFastTranslation()
        try tests.testReasoningAndUsageFramesNeverBecomeTranslation()
        tests.testMultipleMonitorCoordinatesRoundTrip()
        tests.testPopupStaysOnNegativeOriginScreen()
        tests.testHoverDoesNotPickUnrelatedColumn()
        try LearningChecks.run()
        ContextSentenceChecks.run()
        print("CORE PASS: 9 checks")
    }
}
