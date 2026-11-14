import Foundation

/// How FlowerVoice treats the app it is about to type into.
enum TargetAppPolicy {
    /// Password managers and system credential prompts: nothing about them leaves the Mac or is saved to history.
    private static let SENSITIVE_BUNDLE_IDS: Set<String> = [
        "com.1password.1password", "com.agilebits.onepassword7", "com.apple.Passwords",
        "com.apple.keychainaccess", "com.apple.SecurityAgent", "com.apple.loginwindow",
        "com.bitwarden.desktop", "com.lastpass.LastPass", "com.dashlane.dashlanephonefinal",
        "org.keepassxc.keepassxc", "com.proton.pass.electron", "com.enpass.Enpass",
    ]

    /// Terminals run every pasted line as a command when bracketed paste is off.
    private static let TERMINAL_BUNDLE_IDS: Set<String> = [
        "com.apple.Terminal", "com.googlecode.iterm2", "dev.warp.Warp-Stable", "net.kovidgoyal.kitty",
        "com.mitchellh.ghostty", "org.alacritty", "com.github.wez.wezterm", "co.zeit.hyper",
        "com.raphaelamorim.rio", "dev.herdr.app",
    ]

    static func isSensitiveApp(_ bundleId: String) -> Bool {
        SENSITIVE_BUNDLE_IDS.contains(bundleId)
    }

    /// Text safe to paste into the app: a single line for terminals, so no line can run on its own.
    static func adaptForPaste(_ text: String, bundleId: String) -> String {
        guard TERMINAL_BUNDLE_IDS.contains(bundleId) else { return text }
        return text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
