import AppKit
import os

/// Hold the trigger (⌃⌘M) to talk, release to insert. A quick tap locks hands-free mode; tap again to finish.
@MainActor
final class DictationController {
    private static let TAP_THRESHOLD_SECONDS = 0.3
    /// Consecutive dictations into the same app within this window are joined with a space.
    private static let CONTINUATION_WINDOW_SECONDS: TimeInterval = 120

    private struct Insertion {
        let bundleId: String
        let text: String
        let date: Date
    }

    var config: FlowerConfig
    private(set) var phase = DictationPhase.idle
    private var isLocked = false
    private var pressedAt = Date.distantPast
    private var lastInsertion: Insertion?

    private let recorder = AudioRecorder()
    private let transcriber = Transcriber()
    private let cleaner = TranscriptCleaner()
    private let overlay = OverlayPanel()
    private let logger = Logger(subsystem: "dev.fiore.flowervoice", category: "dictation")

    init(config: FlowerConfig) {
        self.config = config
        recorder.onLevel = { [weak overlay] level in overlay?.model.push(level: level) }
        recorder.onCaptureStarted = { NSSound(named: "Tink")?.play() }
    }

    func warmUp() async throws {
        try await transcriber.prepare()
    }

    func handleTriggerPress() {
        if phase == .idle { startRecording() } else if phase == .recording, isLocked { finishRecording() }
    }

    func handleTriggerRelease() {
        guard phase == .recording, !isLocked else { return }
        guard Date().timeIntervalSince(pressedAt) >= Self.TAP_THRESHOLD_SECONDS else { return lockHandsFree() }
        finishRecording()
    }

    private func lockHandsFree() {
        isLocked = true
        overlay.model.isLocked = true
    }

    private func startRecording() {
        do {
            try recorder.start(inputDeviceName: config.inputDevice)
        } catch {
            logger.error("Recording failed: \(error.localizedDescription, privacy: .public)")
            return NSSound.beep()
        }
        pressedAt = Date()
        isLocked = false
        overlay.model.isLocked = false
        setPhase(.recording)
    }

    private func finishRecording() {
        let audio = recorder.stop()
        let context = FocusContextReader.read()
        setPhase(.processing)
        Task { await process(audio, context: context) }
    }

    private func process(_ audio: RecordedAudio, context: FocusContext) async {
        defer { setPhase(.idle) }
        guard audio.hasSpeech else { return NSSound.beep() }
        do {
            let transcript = try await transcriber.transcribe(audio.samples, config: config)
            guard !transcript.isEmpty else { return NSSound.beep() }
            let text = await cleanUnlessSensitive(transcript, context: context)
            TextInserter.insert(TargetAppPolicy.adaptForPaste(text, bundleId: context.bundleId), after: textBefore(context))
            guard !context.isSensitive else { return }
            lastInsertion = Insertion(bundleId: context.bundleId, text: text, date: Date())
            DictationHistory.append(transcript: transcript, text: text, context: context)
        } catch {
            logger.error("Dictation failed: \(error.localizedDescription, privacy: .public)")
            NSSound.beep()
        }
    }

    /// Sensitive targets (password fields, password managers) get the raw transcript: nothing is sent to Codex.
    private func cleanUnlessSensitive(_ transcript: String, context: FocusContext) async -> String {
        guard !context.isSensitive else { return transcript }
        return await cleaner.clean(transcript, context: context, config: config)
    }

    /// Real text before the cursor when readable; otherwise our own last insertion in the same app, if recent.
    private func textBefore(_ context: FocusContext) -> String {
        if let textBeforeCursor = context.textBeforeCursor { return textBeforeCursor }
        guard let lastInsertion, lastInsertion.bundleId == context.bundleId,
              Date().timeIntervalSince(lastInsertion.date) < Self.CONTINUATION_WINDOW_SECONDS else { return "" }
        return lastInsertion.text
    }

    private func setPhase(_ newPhase: DictationPhase) {
        phase = newPhase
        overlay.model.phase = newPhase
        newPhase == .idle ? overlay.hide() : overlay.show()
    }
}
