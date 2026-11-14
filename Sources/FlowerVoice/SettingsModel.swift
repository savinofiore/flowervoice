import FluidAudio
import Foundation

/// Editable copy of the config shown in the Settings window; nothing is applied until `save()`.
@MainActor
final class SettingsModel: ObservableObject {
    @Published var config: FlowerConfig
    @Published var dictionaryText: String
    @Published private(set) var isLaunchAtLoginEnabled = LaunchAtLogin.isEnabled

    let codexModels = CodexModelCatalog.load()
    let microphones = MicrophoneCatalog.availableNames()
    let languages = Language.allCases.map(\.rawValue).sorted()

    var onSave: ((FlowerConfig) -> Void)?

    init(config: FlowerConfig) {
        self.config = config
        dictionaryText = config.dictionary.joined(separator: "\n")
    }

    /// Model slugs, keeping the configured one even if the Codex cache no longer lists it.
    var modelSlugs: [String] {
        let slugs = codexModels.map(\.slug)
        return slugs.contains(config.codexModel) ? slugs : [config.codexModel] + slugs
    }

    var reasoningEfforts: [String] {
        let efforts = CodexModelCatalog.efforts(for: config.codexModel, in: codexModels)
        return efforts.contains(config.reasoningEffort) ? efforts : [config.reasoningEffort] + efforts
    }

    func languageName(_ code: String) -> String {
        Locale.current.localizedString(forLanguageCode: code)?.capitalized ?? code
    }

    func setLaunchAtLogin(_ isEnabled: Bool) {
        LaunchAtLogin.setEnabled(isEnabled)
        isLaunchAtLoginEnabled = LaunchAtLogin.isEnabled
    }

    func save() {
        var saved = config
        saved.dictionary = dictionaryText
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        ConfigStore.save(saved)
        onSave?(saved)
    }
}
