import SwiftUI

@MainActor
final class SettingsWindowController {
    var onSave: ((FlowerConfig) -> Void)?

    let presenter = WindowPresenter(title: "Impostazioni FlowerVoice")

    /// Opens (or brings to front) the Settings window with a fresh copy of the current config.
    func show(config: FlowerConfig) {
        let model = SettingsModel(config: config)
        model.onSave = onSave
        presenter.show(SettingsView(model: model) { [weak self] in self?.presenter.close() })
    }
}
