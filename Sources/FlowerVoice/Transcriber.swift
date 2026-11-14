import FluidAudio
import Foundation

/// Local speech-to-text with NVIDIA Parakeet TDT v3 (FluidAudio, Core ML on the Apple Neural Engine).
/// Multilingual (25 European languages incl. Italian), auto-detects the spoken language.
actor Transcriber {
    private static let MODEL_VERSION = AsrModelVersion.v3

    private let modelDirectory = FlowerPaths.modelsDirectory.appending(path: "parakeet-v3", directoryHint: .isDirectory)
    private var manager: AsrManager?

    /// Downloads the model on first run (skipped when already present), loads it and runs one warm-up pass.
    func prepare() async throws {
        if manager != nil { return }
        let models = try await AsrModels.downloadAndLoad(to: modelDirectory, version: Self.MODEL_VERSION)
        let loaded = AsrManager(config: .default)
        try await loaded.loadModels(models)
        _ = try? await run(loaded, [Float](repeating: 0, count: Int(RecordedAudio.SAMPLE_RATE)), language: nil)
        manager = loaded
    }

    func transcribe(_ samples: [Float], config: FlowerConfig) async throws -> String {
        try await prepare()
        guard let manager else { return "" }
        let language = config.language.flatMap(Language.init(rawValue:))
        return try await run(manager, samples, language: language).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func run(_ manager: AsrManager, _ samples: [Float], language: Language?) async throws -> String {
        var decoderState = TdtDecoderState.make()
        return try await manager.transcribe(samples, decoderState: &decoderState, language: language).text
    }
}
