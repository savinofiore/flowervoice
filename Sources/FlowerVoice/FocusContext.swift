import AppKit
import ApplicationServices

/// What the user is typing into: frontmost app and the text right before the cursor.
struct FocusContext {
    let appName: String
    let bundleId: String
    /// nil when the focused app does not expose its text via Accessibility (e.g. many terminals).
    let textBeforeCursor: String?
}

enum FocusContextReader {
    private static let MAX_CONTEXT_CHARACTERS = 400

    static func read() -> FocusContext {
        let app = NSWorkspace.shared.frontmostApplication
        return FocusContext(
            appName: app?.localizedName ?? "Unknown",
            bundleId: app?.bundleIdentifier ?? "unknown",
            textBeforeCursor: readTextBeforeCursor()
        )
    }

    private static func readTextBeforeCursor() -> String? {
        guard let element = focusedElement(),
              let value = attribute(kAXValueAttribute, of: element) as? String,
              let cursor = cursorLocation(of: element) else { return nil }
        let prefix = String(value.utf16.prefix(cursor)) ?? ""
        return String(prefix.suffix(MAX_CONTEXT_CHARACTERS))
    }

    private static func focusedElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        guard let focused = attribute(kAXFocusedUIElementAttribute, of: systemWide) else { return nil }
        return (focused as! AXUIElement)
    }

    private static func cursorLocation(of element: AXUIElement) -> Int? {
        guard let rangeValue = attribute(kAXSelectedTextRangeAttribute, of: element) else { return nil }
        var range = CFRange()
        guard AXValueGetValue(rangeValue as! AXValue, .cfRange, &range) else { return nil }
        return range.location
    }

    private static func attribute(_ name: String, of element: AXUIElement) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }
}
