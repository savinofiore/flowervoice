import AVFoundation
import os

struct RecordedAudio {
    static let SAMPLE_RATE: Double = 16_000
    private static let SPEECH_LEVEL_THRESHOLD: Float = 0.005
    private static let MIN_DURATION_SECONDS: Double = 0.3

    let samples: [Float]
    let peakLevel: Float

    /// Avoids transcribing silence or accidental taps.
    var hasSpeech: Bool {
        Double(samples.count) / Self.SAMPLE_RATE >= Self.MIN_DURATION_SECONDS && peakLevel >= Self.SPEECH_LEVEL_THRESHOLD
    }
}

enum AudioRecorderError: LocalizedError {
    case noInputDevice
    case cannotAttach(String)

    var errorDescription: String? {
        switch self {
        case .noInputDevice: "No microphone available."
        case .cannotAttach(let name): "Cannot record from \"\(name)\"."
        }
    }
}

/// Captures 16 kHz mono Float32 audio with AVCaptureSession.
/// Unlike AVAudioEngine it opens only the chosen microphone (never the system default, so Bluetooth
/// headphones stay in music mode), and it starts/stops off the main thread, so the UI cannot freeze.
/// A new session per recording also picks up device changes and releases the mic on stop.
final class AudioRecorder: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate {
    var onLevel: ((Float) -> Void)?
    /// Called on the main thread when the first audio buffer arrives: the microphone is really live.
    var onCaptureStarted: (() -> Void)?

    private let sessionQueue = DispatchQueue(label: "dev.fiore.flowervoice.capture-session")
    private let sampleQueue = DispatchQueue(label: "dev.fiore.flowervoice.capture-samples")
    private let logger = Logger(subsystem: "dev.fiore.flowervoice", category: "audio")
    private var session: AVCaptureSession?

    private let lock = NSLock()
    private var samples: [Float] = []
    private var peakLevel: Float = 0
    private var hasReceivedAudio = false
    private var isCapturing = false

    /// Records from the named microphone when connected, otherwise from the system default input.
    func start(inputDeviceName: String?) throws {
        stopSession()
        guard let device = findDevice(named: inputDeviceName) else { throw AudioRecorderError.noInputDevice }
        let session = try makeSession(device)
        self.session = session
        lock.withLock {
            samples.removeAll(keepingCapacity: true)
            peakLevel = 0
            hasReceivedAudio = false
            isCapturing = true
        }
        logger.notice("Recording from \"\(device.localizedName, privacy: .public)\"")
        sessionQueue.async { session.startRunning() }
    }

    func stop() -> RecordedAudio {
        let audio = lock.withLock {
            isCapturing = false
            return RecordedAudio(samples: samples, peakLevel: peakLevel)
        }
        stopSession()
        return audio
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let chunk = floatSamples(of: sampleBuffer), !chunk.isEmpty else { return }
        let level = rootMeanSquare(chunk)
        let isFirstBuffer: Bool? = lock.withLock {
            guard isCapturing else { return nil }
            samples.append(contentsOf: chunk)
            peakLevel = max(peakLevel, level)
            defer { hasReceivedAudio = true }
            return !hasReceivedAudio
        }
        guard let isFirstBuffer else { return }
        DispatchQueue.main.async { [weak self] in
            if isFirstBuffer { self?.onCaptureStarted?() }
            self?.onLevel?(level)
        }
    }

    private func findDevice(named name: String?) -> AVCaptureDevice? {
        guard let name else { return AVCaptureDevice.default(for: .audio) }
        if let match = MicrophoneCatalog.device(named: name) { return match }
        logger.notice("Input device \"\(name, privacy: .public)\" not connected: using system default")
        return AVCaptureDevice.default(for: .audio)
    }

    private func makeSession(_ device: AVCaptureDevice) throws -> AVCaptureSession {
        let session = AVCaptureSession()
        let input = try AVCaptureDeviceInput(device: device)
        let output = AVCaptureAudioDataOutput()
        output.audioSettings = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: RecordedAudio.SAMPLE_RATE,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsNonInterleaved: false,
            AVLinearPCMIsBigEndianKey: false,
        ]
        output.setSampleBufferDelegate(self, queue: sampleQueue)
        guard session.canAddInput(input), session.canAddOutput(output) else {
            throw AudioRecorderError.cannotAttach(device.localizedName)
        }
        session.addInput(input)
        session.addOutput(output)
        return session
    }

    private func stopSession() {
        guard let session else { return }
        self.session = nil
        sessionQueue.async { session.stopRunning() }
    }

    private func floatSamples(of sampleBuffer: CMSampleBuffer) -> [Float]? {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return nil }
        let byteCount = CMBlockBufferGetDataLength(blockBuffer)
        var chunk = [Float](repeating: 0, count: byteCount / MemoryLayout<Float>.size)
        let status = chunk.withUnsafeMutableBytes { bytes in
            CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: bytes.count, destination: bytes.baseAddress!)
        }
        return status == kCMBlockBufferNoErr ? chunk : nil
    }

    private func rootMeanSquare(_ chunk: [Float]) -> Float {
        (chunk.reduce(0) { $0 + $1 * $1 } / Float(chunk.count)).squareRoot()
    }
}
