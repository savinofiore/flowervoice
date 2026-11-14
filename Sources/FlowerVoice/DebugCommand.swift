import AVFoundation
import Foundation

/// `FlowerVoice --transcribe <audio-file> [app-bundle-id]` runs the full pipeline without the UI.
enum DebugCommand {
    static func runIfRequested() -> Bool {
        let arguments = CommandLine.arguments
        if arguments.contains("--mic-test") { runMicTest(); return true }
        guard let flagIndex = arguments.firstIndex(of: "--transcribe"), arguments.count > flagIndex + 1 else { return false }
        let bundleId = arguments.count > flagIndex + 2 ? arguments[flagIndex + 2] : "com.tinyspeck.slackmacgap"
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            await run(path: arguments[flagIndex + 1], bundleId: bundleId)
            semaphore.signal()
        }
        semaphore.wait()
        return true
    }

    /// Records 2 s from the configured microphone (local only) to check the capture format and level.
    private static func runMicTest() {
        let recorder = AudioRecorder()
        do {
            try recorder.start(inputDeviceName: ConfigStore.load().inputDevice)
        } catch {
            return print("ERROR: \(error.localizedDescription)")
        }
        RunLoop.main.run(until: Date().addingTimeInterval(2))
        let audio = recorder.stop()
        let seconds = Double(audio.samples.count) / RecordedAudio.SAMPLE_RATE
        print("MIC TEST: \(audio.samples.count) samples = \(String(format: "%.2f", seconds))s at 16 kHz (expect ~2s), peak \(audio.peakLevel)")
    }

    private static func run(path: String, bundleId: String) async {
        let config = ConfigStore.load()
        let context = FocusContext(appName: bundleId, bundleId: bundleId, textBeforeCursor: nil, isSensitive: false)
        do {
            let samples = try loadSamples(URL(fileURLWithPath: path))
            let transcriber = Transcriber()
            let loadStart = Date()
            try await transcriber.prepare()
            print("MODEL LOAD: \(String(format: "%.2f", Date().timeIntervalSince(loadStart)))s")
            let start = Date()
            let transcript = try await transcriber.transcribe(samples, config: config)
            let speechSeconds = Date().timeIntervalSince(start)
            let text = await TranscriptCleaner().clean(transcript, context: context, config: config)
            let totalSeconds = Date().timeIntervalSince(start)
            print("RAW (\(String(format: "%.2f", speechSeconds))s): \(transcript)")
            print("FINAL (\(String(format: "%.2f", totalSeconds))s total): \(text)")
        } catch {
            print("ERROR: \(error.localizedDescription)")
        }
    }

    private static func loadSamples(_ url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: RecordedAudio.SAMPLE_RATE, channels: 1, interleaved: false)!
        guard let converter = AVAudioConverter(from: file.processingFormat, to: format),
              let input = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else { return [] }
        try file.read(into: input)
        let capacity = AVAudioFrameCount(Double(input.frameLength) * format.sampleRate / file.processingFormat.sampleRate) + 32
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return [] }
        var isConsumed = false
        converter.convert(to: output, error: nil) { _, status in
            if isConsumed { status.pointee = .endOfStream; return nil }
            isConsumed = true
            status.pointee = .haveData
            return input
        }
        return Array(UnsafeBufferPointer(start: output.floatChannelData![0], count: Int(output.frameLength)))
    }
}
