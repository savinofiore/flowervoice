import AppKit

@MainActor
final class MenuBarController: NSObject {
    var onOpenSettings: (() -> Void)?
    var onRequestPermissions: (() -> Void)?

    private var statusItem: NSStatusItem?
    private let statusLine = NSMenuItem(title: "Avvio…", action: nil, keyEquivalent: "")
    private let permissionLines = Permission.allCases.map { _ in NSMenuItem(title: "", action: nil, keyEquivalent: "") }

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "camera.macro", accessibilityDescription: "FlowerVoice")
        item.menu = makeMenu()
        statusItem = item
    }

    func setStatus(_ text: String) {
        statusLine.title = text
    }

    func showPermissions(_ states: [(Permission, Bool)]) {
        zip(permissionLines, states).forEach { line, state in
            line.title = "\(state.1 ? "✅" : "❌") \(state.0.title)"
        }
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(statusLine)
        menu.addItem(.separator())
        permissionLines.forEach(menu.addItem)
        menu.addItem(makeItem("Concedi permessi…", #selector(requestPermissions)))
        menu.addItem(.separator())
        menu.addItem(makeItem("Copia ultima dettatura", #selector(copyLast)))
        menu.addItem(makeItem("Apri storico", #selector(openHistory)))
        menu.addItem(makeItem("Impostazioni…", #selector(openSettings), key: ","))
        menu.addItem(.separator())
        menu.addItem(makeItem("Esci", #selector(quit), key: "q"))
        return menu
    }

    private func makeItem(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func copyLast() {
        guard let text = DictationHistory.lastText() else { return NSSound.beep() }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    @objc private func openSettings() {
        onOpenSettings?()
    }

    @objc private func requestPermissions() {
        onRequestPermissions?()
    }

    @objc private func openHistory() {
        NSWorkspace.shared.open(FlowerPaths.historyFile)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
