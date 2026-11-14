import Foundation

/// Append-only local log of dictations (~/.config/flowervoice/history.jsonl).
enum DictationHistory {
    private struct Entry: Encodable {
        let date: Date
        let app: String
        let transcript: String
        let text: String
    }

    static func append(transcript: String, text: String, context: FocusContext) {
        let entry = Entry(date: Date(), app: context.bundleId, transcript: transcript, text: text)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard var line = try? encoder.encode(entry) else { return }
        line.append(0x0A)
        let file = FlowerPaths.historyFile
        guard let handle = try? FileHandle(forWritingTo: file) else {
            try? line.write(to: file, options: .atomic)
            return
        }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: line)
    }

    static func lastText() -> String? {
        guard let content = try? String(contentsOf: FlowerPaths.historyFile, encoding: .utf8),
              let lastLine = content.split(separator: "\n").last,
              let json = try? JSONSerialization.jsonObject(with: Data(lastLine.utf8)) as? [String: Any] else { return nil }
        return json["text"] as? String
    }
}
