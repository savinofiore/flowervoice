import AppKit
import Carbon.HIToolbox

/// Inserts text into the focused app: clipboard + Cmd+V, then restores the previous clipboard.
enum TextInserter {
    private static let RESTORE_DELAY_SECONDS = 0.5

    static func insert(_ text: String, after textBeforeCursor: String) {
        let pasteboard = NSPasteboard.general
        let savedItems = snapshot(pasteboard)
        pasteboard.clearContents()
        pasteboard.setString(withLeadingSpace(text, after: textBeforeCursor), forType: .string)
        pressCommandV()
        DispatchQueue.main.asyncAfter(deadline: .now() + RESTORE_DELAY_SECONDS) {
            restore(savedItems, to: pasteboard)
        }
    }

    private static func withLeadingSpace(_ text: String, after textBeforeCursor: String) -> String {
        guard let last = textBeforeCursor.last, !last.isWhitespace, !text.hasPrefix(" ") else { return text }
        let isPunctuationStart = text.first.map { ".,;:!?)".contains($0) } ?? false
        return isPunctuationStart ? text : " " + text
    }

    private static func pressCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyCode = CGKeyCode(kVK_ANSI_V)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    private static func snapshot(_ pasteboard: NSPasteboard) -> [[NSPasteboard.PasteboardType: Data]] {
        (pasteboard.pasteboardItems ?? []).map { item in
            Dictionary(uniqueKeysWithValues: item.types.compactMap { type in
                item.data(forType: type).map { (type, $0) }
            })
        }
    }

    private static func restore(_ items: [[NSPasteboard.PasteboardType: Data]], to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        let restored = items.map { entries in
            let item = NSPasteboardItem()
            entries.forEach { item.setData($0.value, forType: $0.key) }
            return item
        }
        pasteboard.writeObjects(restored)
    }
}
