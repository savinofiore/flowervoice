import AppKit
import Combine

@MainActor
final class HistoryModel: ObservableObject {
    @Published private(set) var records: [DictationRecord] = []
    @Published var query = ""
    @Published private(set) var copiedRecord: DictationRecord?

    private var appNames: [String: String] = [:]
    private var historyObserver: AnyCancellable?

    init() {
        reload()
        historyObserver = NotificationCenter.default.publisher(for: DictationHistory.didChange)
            .sink { [weak self] _ in self?.reload() }
    }

    var filteredRecords: [DictationRecord] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return records }
        return records.filter {
            $0.text.localizedCaseInsensitiveContains(trimmed) || appName(for: $0.app).localizedCaseInsensitiveContains(trimmed)
        }
    }

    func reload() {
        records = DictationHistory.loadAll()
    }

    /// Human-readable app name for a bundle identifier (e.g. "Slack"), falling back to the identifier.
    func appName(for bundleId: String) -> String {
        if let cached = appNames[bundleId] { return cached }
        let name = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId)
            .map { FileManager.default.displayName(atPath: $0.path).replacingOccurrences(of: ".app", with: "") }
            ?? bundleId
        appNames[bundleId] = name
        return name
    }

    func appIcon(for bundleId: String) -> NSImage? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId).map { NSWorkspace.shared.icon(forFile: $0.path) }
    }

    func copy(_ record: DictationRecord) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(record.text, forType: .string)
        copiedRecord = record
    }

    func clear() {
        DictationHistory.clear()
    }
}
