import Foundation
import FlowCore

enum AppError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case let .message(text) = self { return text }; return nil }
}

struct APIConfiguration {
    let endpoint: String
    let model: String
    let key: String
    var fastMode = true
}

private final class NoRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

enum APITranslator {
    static func translate(_ text: String, context: String = "", target: String, configuration: APIConfiguration,
                          update: @escaping @MainActor (String) -> Void) async throws -> String {
        let body = TranslationRequest.body(text: text, context: context, target: target, model: configuration.model.trimmingCharacters(in: .whitespacesAndNewlines), fastMode: configuration.fastMode)
        return try await stream(body: body, configuration: configuration, update: update)
    }
    static func explain(_ text: String, context: String, target: String, configuration: APIConfiguration,
                        update: @escaping @MainActor (String) -> Void) async throws -> WordExplanation {
        let body = TranslationRequest.dictionary(text: text, context: context, target: target, model: configuration.model.trimmingCharacters(in: .whitespacesAndNewlines), fastMode: configuration.fastMode)
        let raw = try await stream(body: body, configuration: configuration) { raw in
            let meaning = PartialJSON.string("meaning", in: raw)
            if !meaning.isEmpty { update(meaning) }
        }
        do { return try WordExplanation.parse(raw) }
        catch { throw AppError.message("释义格式不完整，请重试或检查模型是否支持 JSON 输出。") }
    }
    private static func stream(body: [String: Any], configuration: APIConfiguration,
                               update: @escaping @MainActor (String) -> Void) async throws -> String {
        guard !configuration.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppError.message("请先在「翻译服务」中填写服务商的模型名称。")
        }
        let url = try APIEndpoint.completions(configuration.endpoint)
        if url.host == "api.deepseek.com", configuration.key.isEmpty {
            throw AppError.message("请先在「翻译服务」中填写并保存你的 DeepSeek API Key。")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 40
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream, application/json", forHTTPHeaderField: "Accept")
        if !configuration.key.isEmpty { request.setValue("Bearer \(configuration.key)", forHTTPHeaderField: "Authorization") }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForResource = 90
        let session = URLSession(configuration: config, delegate: NoRedirects(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let (bytes, response) = try await session.bytes(for: request)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            let hint = code == 401 ? "检查 API Key。" : (code == 429 ? "服务限流，请稍后再试。" : "检查地址、模型和网络；不跟随重定向。")
            throw AppError.message("翻译服务返回 HTTP \(code)。\(hint)")
        }
        if !(response.value(forHTTPHeaderField: "Content-Type") ?? "").contains("text/event-stream") {
            var data = Data()
            for try await byte in bytes {
                try Task.checkCancellation()
                guard data.count < 2_000_000 else { throw AppError.message("翻译响应过大。") }
                data.append(byte)
            }
            let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
            if let reason = decoded.finishReason, reason != "stop" { throw AppError.message("译文没有正常完成（\(reason)），请重试。") }
            let result = decoded.text
            guard !result.isEmpty else { throw AppError.message("服务没有返回译文。") }
            await update(result)
            return result
        }
        var parser = SSEParser()
        var output = ""
        var completed = false
        func append(_ payload: String) async throws -> Bool {
            if payload == "[DONE]" { completed = true; return false }
            let result: ChatResponse
            do { result = try JSONDecoder().decode(ChatResponse.self, from: Data(payload.utf8)) }
            catch { throw AppError.message("服务返回了无法解析的流式数据，请检查 API 兼容性。") }
            output += result.text
            if let reason = result.finishReason {
                guard reason == "stop" else { throw AppError.message("译文没有正常完成（\(reason)），请重试。") }
                completed = true
            }
            guard output.utf8.count < 2_000_000 else { throw AppError.message("翻译响应过大。") }
            if !result.text.isEmpty { await update(output) }
            return true
        }
        // AsyncBytes.lines drops empty lines, which are SSE event delimiters.
        // Frame UTF-8 lines ourselves so CRLF, empty lines and EOF stay intact.
        var lineData = Data()
        for try await byte in bytes {
            try Task.checkCancellation()
            if byte == 10 {
                let line = String(decoding: lineData, as: UTF8.self)
                lineData.removeAll(keepingCapacity: true)
                if let payload = parser.consume(line), (try await append(payload)) == false { break }
            } else {
                guard lineData.count < 2_000_000 else { throw AppError.message("翻译响应行过大。") }
                lineData.append(byte)
            }
        }
        if !lineData.isEmpty { _ = parser.consume(String(decoding: lineData, as: UTF8.self)) }
        if let remaining = parser.finish() { _ = try await append(remaining) }
        try Task.checkCancellation()
        guard completed else { throw AppError.message("连接在译文完成前断开，请重试。") }
        guard !output.isEmpty else { throw AppError.message("服务没有返回译文。") }
        return output
    }
}
