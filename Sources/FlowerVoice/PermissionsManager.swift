import AppKit
import AVFoundation

/// The macOS permissions FlowerVoice needs, with request + System Settings shortcuts.
enum Permission: CaseIterable {
    case microphone, accessibility

    var title: String {
        switch self {
        case .microphone: "Microfono"
        case .accessibility: "Accessibilità"
        }
    }

    var isGranted: Bool {
        switch self {
        case .microphone: AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        case .accessibility: AXIsProcessTrusted()
        }
    }

    private var settingsURL: URL {
        let anchor = switch self {
        case .microphone: "Privacy_Microphone"
        case .accessibility: "Privacy_Accessibility"
        }
        return URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)")!
    }

    /// Shows the system prompt; if macOS no longer prompts (already denied), opens System Settings.
    func request() {
        switch self {
        case .microphone: requestMicrophone()
        case .accessibility: requestAccessibility()
        }
    }

    func openSettings() {
        NSWorkspace.shared.open(settingsURL)
    }

    private func requestMicrophone() {
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined else { return openSettings() }
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
    }

    private func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(options) { openSettings() }
    }
}

enum PermissionsManager {
    static var missing: [Permission] { Permission.allCases.filter { !$0.isGranted } }

    /// Requests missing permissions one at a time, so system dialogs don't stack on each other.
    static func requestNextMissing() {
        missing.first?.request()
    }
}
