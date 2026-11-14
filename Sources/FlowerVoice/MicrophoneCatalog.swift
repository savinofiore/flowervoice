import AVFoundation

/// Audio input devices as AVCaptureDevice sees them (same names as System Settings → Sound).
enum MicrophoneCatalog {
    static func availableNames() -> [String] {
        discoverDevices().map(\.localizedName)
    }

    /// The named microphone when connected, otherwise nil.
    static func device(named name: String) -> AVCaptureDevice? {
        discoverDevices().first { $0.localizedName.caseInsensitiveCompare(name) == .orderedSame }
    }

    private static func discoverDevices() -> [AVCaptureDevice] {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external], mediaType: .audio, position: .unspecified
        ).devices
    }
}
