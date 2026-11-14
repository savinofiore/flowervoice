import AppKit
import SwiftUI

/// Shows a SwiftUI view in a regular window from a menu bar app (which has no windows of its own),
/// reusing the same window and bringing the app to the front.
@MainActor
final class WindowPresenter {
    private let title: String
    private let styleMask: NSWindow.StyleMask
    private var window: NSWindow?

    init(title: String, isResizable: Bool = false) {
        self.title = title
        styleMask = isResizable ? [.titled, .closable, .resizable, .miniaturizable] : [.titled, .closable]
    }

    func show(_ view: some View) {
        let window = window ?? makeWindow()
        let isFirstShow = self.window == nil
        window.contentViewController = NSHostingController(rootView: view)
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        if isFirstShow { window.center() }
        window.makeKeyAndOrderFront(nil)
    }

    /// Writes the window content as PNG (debug: `--snapshot <dir>`), no Screen Recording permission needed.
    func snapshot(to url: URL) {
        guard let view = window?.contentView,
              let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        try? bitmap.representation(using: .png, properties: [:])?.write(to: url)
    }

    func close() {
        window?.close()
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentRect: .zero, styleMask: styleMask, backing: .buffered, defer: false)
        window.title = title
        window.isReleasedWhenClosed = false
        return window
    }
}
