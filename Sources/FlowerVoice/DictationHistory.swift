import Foundation

struct DictationRecord: Codable, Hashable {
    let date: Date
    /// Bundle identifier of the app the text was pasted into.
    let app: String
    /// Raw speech-to-text output, before Codex cleanup.
    let transcript: String
    /// Final text that was pasted.
    let text: String
}

/// Local log of dictations, one JSON object per line (~/.config/flowervoice/history.jsonl).
enum DictationHistory {
    /// Posted on the main thread whenever the history changes.
    static let didChange = Notification.Name("FlowerVoiceHistoryDidChange")

    static func append(transcript: String, text: String, context: FocusContext) {
        let record = DictationRecord(date: Date(), app: context.bundleId, transcript: transcript, text: text)
        guard var line = try? makeEncoder().encode(record) else { return }
        line.append(0x0A)
        write(line)
        notifyChange()
    }

    /// All dictations, newest first. Unreadable lines are skipped.
    static func loadAll() -> [DictationRecord] {
        guard let content = try? String(contentsOf: FlowerPaths.historyFile, encoding: .utf8) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return content.split(separator: "\n")
            .compactMap { try? decoder.decode(DictationRecord.self, from: Data($0.utf8)) }
            .reversed()
    }

    static func lastText() -> String? {
        loadAll().first?.text
    }

    static func clear() {
        try? FileManager.default.removeItem(at: FlowerPaths.historyFile)
        notifyChange()
    }

    private static func write(_ line: Data) {
        try? PrivateFiles.createDirectory(FlowerPaths.configDirectory)
        try? PrivateFiles.append(line, to: FlowerPaths.historyFile)
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static func notifyChange() {
        DispatchQueue.main.async { NotificationCenter.default.post(name: didChange, object: nil) }
    }
}
