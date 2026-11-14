import Carbon.HIToolbox

/// System-wide shortcut via Carbon hot keys: needs no permission and swallows the key combo,
/// so the focused app never receives it. Reports both press and release (for hold-to-talk).
final class GlobalHotkey {
    private static let SIGNATURE: OSType = 0x464C_5752 // "FLWR"

    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    /// Defaults to ⌃⌘M.
    func register(keyCode: Int = kVK_ANSI_M, modifiers: Int = controlKey | cmdKey) -> Bool {
        guard installHandler() else { return false }
        let hotKeyID = EventHotKeyID(signature: Self.SIGNATURE, id: 1)
        let status = RegisterEventHotKey(
            UInt32(keyCode), UInt32(modifiers), hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef
        )
        return status == noErr
    }

    fileprivate func handle(_ eventKind: UInt32) {
        eventKind == UInt32(kEventHotKeyPressed) ? onPress?() : onRelease?()
    }

    private func installHandler() -> Bool {
        let eventTypes = [kEventHotKeyPressed, kEventHotKeyReleased].map {
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32($0))
        }
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        let status = eventTypes.withUnsafeBufferPointer { types in
            InstallEventHandler(
                GetApplicationEventTarget(), globalHotkeyHandler, types.count, types.baseAddress, selfPointer, &handlerRef
            )
        }
        return status == noErr
    }
}

private func globalHotkeyHandler(
    _: EventHandlerCallRef?, event: EventRef?, userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }
    Unmanaged<GlobalHotkey>.fromOpaque(userData).takeUnretainedValue().handle(GetEventKind(event))
    return noErr
}
