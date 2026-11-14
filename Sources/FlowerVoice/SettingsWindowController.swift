import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    var onSave: ((FlowerConfig) -> Void)?

    private var window: NSWindow?

    /// Opens (or brings to front) the Settings window with a fresh copy of the current config.
    func show(config: FlowerConfig) {
        let model = SettingsModel(config: config)
        model.onSave = onSave
        let view = SettingsView(model: model) { [weak self] in self?.window?.close() }
        let window = window ?? makeWindow()
        window.contentViewController = NSHostingController(rootView: view)
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 680),
            styleMask: [.titled, .closable], backing: .buffered, defer: false
        )
        window.title = "Impostazioni FlowerVoice"
        window.isReleasedWhenClosed = false
        return window
    }
}
