import os
import ServiceManagement

/// Registers FlowerVoice as a login item (System Settings → General → Login Items).
enum LaunchAtLogin {
    private static let logger = Logger(subsystem: "dev.fiore.flowervoice", category: "login-item")

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ isEnabled: Bool) {
        do {
            if isEnabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            logger.error("Login item update failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
