import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: SettingsModel
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Form {
                microphoneSection
                transcriptionSection
                cleanupSection
                generalSection
            }
            .formStyle(.grouped)
            footer
        }
        .frame(width: 520, height: 680)
    }

    private var microphoneSection: some View {
        Section {
            Picker("Microfono", selection: $model.config.inputDevice) {
                Text("Predefinito di sistema").tag(String?.none)
                ForEach(model.microphones, id: \.self) { Text($0).tag(String?.some($0)) }
            }
        } header: {
            Text("Microfono")
        } footer: {
            Text("Usa un microfono non Bluetooth: le cuffie Bluetooth passano in modalità chiamata e mettono in pausa i media.")
        }
    }

    private var transcriptionSection: some View {
        Section("Trascrizione (Parakeet, sul Mac)") {
            Picker("Lingua", selection: $model.config.language) {
                Text("Automatica").tag(String?.none)
                ForEach(model.languages, id: \.self) { Text(model.languageName($0)).tag(String?.some($0)) }
            }
            VStack(alignment: .leading) {
                Text("Dizionario: nomi e termini da scrivere sempre così, uno per riga")
                TextEditor(text: $model.dictionaryText)
                    .font(.body.monospaced())
                    .frame(height: 70)
            }
        }
    }

    private var cleanupSection: some View {
        Section("Pulizia del testo (abbonamento Codex)") {
            Toggle("Pulisci il testo con Codex", isOn: $model.config.isCleanupEnabled)
            Picker("Modello", selection: $model.config.codexModel) {
                ForEach(model.modelSlugs, id: \.self) { Text($0).tag($0) }
            }
            .disabled(!model.config.isCleanupEnabled)
            Picker("Ragionamento", selection: $model.config.reasoningEffort) {
                ForEach(model.reasoningEfforts, id: \.self) { Text($0).tag($0) }
            }
            .disabled(!model.config.isCleanupEnabled)
            VStack(alignment: .leading) {
                Text("Istruzioni di stile")
                TextEditor(text: $model.config.extraInstructions)
                    .frame(height: 60)
            }
            .disabled(!model.config.isCleanupEnabled)
        }
    }

    private var generalSection: some View {
        Section("Generale") {
            Toggle("Avvia FlowerVoice al login", isOn: Binding(
                get: { model.isLaunchAtLoginEnabled },
                set: { model.setLaunchAtLogin($0) }
            ))
            LabeledContent("Scorciatoia", value: "⌃⌘M — tocca per iniziare/finire, tieni premuto per parlare")
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Annulla", action: onClose)
                .keyboardShortcut(.cancelAction)
            Button("Salva") {
                model.save()
                onClose()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding()
    }
}
