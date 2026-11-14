import AppKit
import ApplicationServices

/// What the user is typing into: frontmost app and the text right before the cursor.
struct FocusContext {
    let appName: String
    let bundleId: String
    /// nil when the focused app does not expose its text via Accessibility (e.g. many terminals), or the field is sensitive.
    let textBeforeCursor: String?
    /// Password field or password manager: the dictation is pasted raw, never sent to Codex nor saved to history.
    let isSensitive: Bool
}

enum FocusContextReader {
    private static let MAX_CONTEXT_CHARACTERS = 400

    static func read() -> FocusContext {
        let app = NSWorkspace.shared.frontmostApplication
        let bundleId = app?.bundleIdentifier ?? "unknown"
        let element = focusedElement()
        let isSensitive = TargetAppPolicy.isSensitiveApp(bundleId) || element.map(isSecureField) ?? false
        return FocusContext(
            appName: app?.localizedName ?? "Unknown",
            bundleId: bundleId,
            textBeforeCursor: isSensitive ? nil : element.flatMap(readTextBeforeCursor),
            isSensitive: isSensitive
        )
    }

    private static func readTextBeforeCursor(of element: AXUIElement) -> String? {
        guard let value = attribute(kAXValueAttribute, of: element) as? String,
              let cursor = cursorLocation(of: element) else { return nil }
        let prefix = String(value.utf16.prefix(cursor)) ?? ""
        return String(prefix.suffix(MAX_CONTEXT_CHARACTERS))
    }

    private static func isSecureField(_ element: AXUIElement) -> Bool {
        let subrole = attribute(kAXSubroleAttribute, of: element) as? String
        return subrole == kAXSecureTextFieldSubrole
    }

    private static func focusedElement() -> AXUIElement? {
        guard let focused = attribute(kAXFocusedUIElementAttribute, of: AXUIElementCreateSystemWide()),
              CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        return unsafeDowncast(focused, to: AXUIElement.self)
    }

    private static func cursorLocation(of element: AXUIElement) -> Int? {
        guard let rangeValue = attribute(kAXSelectedTextRangeAttribute, of: element),
              CFGetTypeID(rangeValue) == AXValueGetTypeID() else { return nil }
        var range = CFRange()
        guard AXValueGetValue(unsafeDowncast(rangeValue, to: AXValue.self), .cfRange, &range) else { return nil }
        return range.location
    }

    private static func attribute(_ name: String, of element: AXUIElement) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }
}
