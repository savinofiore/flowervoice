import Foundation

struct CodexRequest {
    let model: String
    let reasoningEffort: String
    let instructions: String
    let input: String
}

enum CodexClientError: LocalizedError {
    case http(Int, String)
    case responseFailed(String)

    var errorDescription: String? {
        switch self {
        case .http(let status, let body): "Codex HTTP \(status): \(body)"
        case .responseFailed(let reason): "Codex response failed: \(reason)"
        }
    }
}

/// Calls the ChatGPT-backed Codex Responses endpoint with the user's Codex subscription.
final class CodexClient {
    private static let RESPONSES_URL = URL(string: "https://chatgpt.com/backend-api/codex/responses")!
    /// Identifies FlowerVoice honestly instead of posing as the Codex CLI.
    private static let ORIGINATOR = "flowervoice"
    private let auth = CodexAuth()

    func complete(_ request: CodexRequest) async throws -> String {
        let credentials = try await auth.credentials()
        do {
            return try await send(request, credentials: credentials)
        } catch CodexClientError.http(401, _) {
            return try await send(request, credentials: try await auth.refresh(rejecting: credentials.accessToken))
        }
    }

    private func send(_ request: CodexRequest, credentials: CodexCredentials) async throws -> String {
        let urlRequest = try makeURLRequest(request, credentials: credentials)
        let (bytes, response) = try await URLSession.shared.bytes(for: urlRequest)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            var body = ""
            for try await line in bytes.lines { body += line }
            throw CodexClientError.http(status, String(body.prefix(300)))
        }
        return try await collectOutputText(bytes.lines)
    }

    private func collectOutputText(_ lines: AsyncLineSequence<URLSession.AsyncBytes>) async throws -> String {
        var output = ""
        for try await line in lines where line.hasPrefix("data:") {
            guard let event = parseEvent(line) else { continue }
            switch event["type"] as? String {
            case "response.output_text.delta": output += event["delta"] as? String ?? ""
            case "response.completed": return output
            case "response.failed", "error": throw CodexClientError.responseFailed(describe(event))
            default: continue
            }
        }
        return output
    }

    private func parseEvent(_ line: String) -> [String: Any]? {
        let payload = Data(line.dropFirst(5).utf8)
        return try? JSONSerialization.jsonObject(with: payload) as? [String: Any]
    }

    private func describe(_ event: [String: Any]) -> String {
        let response = event["response"] as? [String: Any]
        let error = (response?["error"] ?? event["error"]) as? [String: Any]
        return error?["message"] as? String ?? "unknown error"
    }

    private func makeURLRequest(_ request: CodexRequest, credentials: CodexCredentials) throws -> URLRequest {
        var urlRequest = URLRequest(url: Self.RESPONSES_URL, timeoutInterval: 30)
        urlRequest.httpMethod = "POST"
        let headers = [
            "Authorization": "Bearer \(credentials.accessToken)",
            "chatgpt-account-id": credentials.accountId,
            "Content-Type": "application/json",
            "Accept": "text/event-stream",
            "OpenAI-Beta": "responses=experimental",
            "originator": Self.ORIGINATOR,
            "session_id": UUID().uuidString,
        ]
        headers.forEach { urlRequest.setValue($0.value, forHTTPHeaderField: $0.key) }
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: makeBody(request))
        return urlRequest
    }

    private func makeBody(_ request: CodexRequest) -> [String: Any] {
        [
            "model": request.model,
            "instructions": request.instructions,
            "input": [[
                "type": "message",
                "role": "user",
                "content": [["type": "input_text", "text": request.input]],
            ]],
            "stream": true,
            "store": false,
            "reasoning": ["effort": request.reasoningEffort],
            "tools": [],
            "tool_choice": "auto",
            "parallel_tool_calls": false,
        ]
    }
}
