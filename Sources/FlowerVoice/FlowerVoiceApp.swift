import AppKit
import os

@main
enum FlowerVoiceMain {
    static func main() {
        if DebugCommand.runIfRequested() { return }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let PERMISSION_POLL_SECONDS = 1.5

    private let globalHotkey = GlobalHotkey()
    private let menuBar = MenuBarController()
    private let settingsWindow = SettingsWindowController()
    private var controller: DictationController!
    private var requestedPermissions = Set<Permission>()
    private var isHotkeyRegistered = false
    private var isModelReady = false
    private var modelError: String?
    private let logger = Logger(subsystem: "dev.fiore.flowervoice", category: "app")

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = DictationController(config: ConfigStore.load())
        settingsWindow.onSave = { [weak self] config in self?.controller.config = config }
        menuBar.onOpenSettings = { [weak self] in
            guard let self else { return }
            settingsWindow.show(config: controller.config)
        }
        menuBar.onRequestPermissions = { [weak self] in self?.requestPermissionsAgain() }
        menuBar.install()
        registerGlobalHotkey()
        warmUpModel()
        Timer.scheduledTimer(withTimeInterval: Self.PERMISSION_POLL_SECONDS, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkPermissions() }
        }
        checkPermissions()
    }

    /// Requests the next missing permission once and refreshes the menu.
    private func checkPermissions() {
        if let next = PermissionsManager.missing.first, !requestedPermissions.contains(next) {
            requestedPermissions.insert(next)
            next.request()
        }
        menuBar.showPermissions(Permission.allCases.map { ($0, $0.isGranted) })
        refreshStatus()
    }

    private func requestPermissionsAgain() {
        requestedPermissions.removeAll()
        PermissionsManager.missing.forEach { $0.openSettings() }
        checkPermissions()
    }

    private func registerGlobalHotkey() {
        globalHotkey.onPress = { [weak self] in MainActor.assumeIsolated { self?.controller.handleTriggerPress() } }
        globalHotkey.onRelease = { [weak self] in MainActor.assumeIsolated { self?.controller.handleTriggerRelease() } }
        isHotkeyRegistered = globalHotkey.register()
        if !isHotkeyRegistered { logger.error("⌃⌘M is already taken by another app") }
    }

    private func warmUpModel() {
        Task {
            do {
                try await controller.warmUp()
                isModelReady = true
            } catch {
                logger.error("Speech model load failed: \(error.localizedDescription, privacy: .public)")
                modelError = error.localizedDescription
            }
            refreshStatus()
        }
    }

    private func refreshStatus() {
        if !PermissionsManager.missing.isEmpty { return menuBar.setStatus("⚠️ Mancano permessi (vedi sotto)") }
        if let modelError { return menuBar.setStatus("⚠️ Errore modello vocale: \(modelError)") }
        if !isHotkeyRegistered { return menuBar.setStatus("⚠️ ⌃⌘M è già usato da un'altra app") }
        menuBar.setStatus(isModelReady ? "Pronto: ⌃⌘M per dettare" : "Carico il modello vocale…")
    }
}
