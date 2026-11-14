import SwiftUI

struct HistoryView: View {
    @ObservedObject var model: HistoryModel
    @State private var isConfirmingClear = false

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            content.frame(maxHeight: .infinity)
        }
        .frame(minWidth: 520, idealWidth: 600, minHeight: 420, idealHeight: 620)
        .confirmationDialog("Svuotare lo storico?", isPresented: $isConfirmingClear) {
            Button("Svuota storico", role: .destructive) { model.clear() }
        } message: {
            Text("Tutte le dettature salvate su questo Mac verranno eliminate.")
        }
    }

    @ViewBuilder private var content: some View {
        if model.records.isEmpty {
            ContentUnavailableView(
                "Nessuna dettatura", systemImage: "waveform",
                description: Text("Premi ⌃⌘M per dettare: le dettature compariranno qui.")
            )
        } else if model.filteredRecords.isEmpty {
            ContentUnavailableView.search(text: model.query)
        } else {
            List(model.filteredRecords, id: \.self) { record in
                HistoryRow(record: record, model: model)
            }
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Cerca nelle dettature", text: $model.query)
                .textFieldStyle(.plain)
            Button("Svuota storico", systemImage: "trash") { isConfirmingClear = true }
                .disabled(model.records.isEmpty)
        }
        .padding(10)
    }
}

private struct HistoryRow: View {
    let record: DictationRecord
    @ObservedObject var model: HistoryModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            Text(record.text)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            if record.transcript != record.text {
                DisclosureGroup("Trascrizione originale") {
                    Text(record.transcript)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(.callout)
            }
        }
        .padding(.vertical, 6)
    }

    private var header: some View {
        HStack(spacing: 6) {
            if let icon = model.appIcon(for: record.app) {
                Image(nsImage: icon).resizable().frame(width: 16, height: 16)
            }
            Text(model.appName(for: record.app)).fontWeight(.medium)
            Text(record.date, format: .dateTime.day().month().hour().minute())
                .foregroundStyle(.secondary)
            Spacer()
            Button(model.copiedRecord == record ? "Copiato" : "Copia",
                   systemImage: model.copiedRecord == record ? "checkmark" : "doc.on.doc") {
                model.copy(record)
            }
            .buttonStyle(.borderless)
        }
        .font(.callout)
    }
}
