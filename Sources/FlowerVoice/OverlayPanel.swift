import AppKit
import SwiftUI

enum DictationPhase {
    case idle, recording, processing
}

final class OverlayModel: ObservableObject {
    private static let LEVEL_COUNT = 24

    @Published var phase = DictationPhase.idle
    @Published var isLocked = false
    @Published private(set) var levels = [Float](repeating: 0, count: LEVEL_COUNT)

    func push(level: Float) {
        levels.removeFirst()
        levels.append(min(1, level * 12))
    }

    func resetLevels() {
        levels = [Float](repeating: 0, count: Self.LEVEL_COUNT)
    }
}

/// Small floating pill at the bottom of the screen, like Willow's bar.
struct OverlayView: View {
    @ObservedObject var model: OverlayModel

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: model.isLocked ? "lock.fill" : "mic.fill")
                .foregroundStyle(model.phase == .recording ? .pink : .secondary)
            content.frame(width: 120, height: 22)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.15)))
    }

    @ViewBuilder private var content: some View {
        if model.phase == .processing {
            ProgressView().controlSize(.small)
        } else {
            HStack(spacing: 2) {
                ForEach(Array(model.levels.enumerated()), id: \.offset) { _, level in
                    Capsule().fill(.white.opacity(0.85))
                        .frame(width: 3, height: max(3, CGFloat(level) * 22))
                }
            }
            .animation(.linear(duration: 0.08), value: model.levels)
        }
    }
}

final class OverlayPanel {
    private static let BOTTOM_MARGIN: CGFloat = 70

    let model = OverlayModel()
    private lazy var panel = makePanel()

    func show() {
        position()
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
        model.resetLevels()
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 40),
            styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: true
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.contentView = NSHostingView(rootView: OverlayView(model: model))
        return panel
    }

    private func position() {
        guard let screen = NSScreen.main else { return }
        let size = panel.contentView?.fittingSize ?? panel.frame.size
        let origin = NSPoint(x: screen.frame.midX - size.width / 2, y: screen.visibleFrame.minY + Self.BOTTOM_MARGIN)
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
    }
}
