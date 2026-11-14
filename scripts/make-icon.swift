// Renders the FlowerVoice app icon (1024×1024 PNG): white flower on a pink→violet rounded square.
// Usage: swift scripts/make-icon.swift <output.png>
import AppKit

let CANVAS: CGFloat = 1024
let TILE_INSET: CGFloat = 100 // macOS icon grid: 824 pt tile centered in 1024 canvas
let TILE_RADIUS: CGFloat = 185
let SYMBOL_POINT_SIZE: CGFloat = 470

func drawTile(in rect: NSRect) {
    let tile = NSBezierPath(roundedRect: rect, xRadius: TILE_RADIUS, yRadius: TILE_RADIUS)
    let gradient = NSGradient(colors: [
        NSColor(red: 1.00, green: 0.42, blue: 0.62, alpha: 1),
        NSColor(red: 0.55, green: 0.30, blue: 0.95, alpha: 1),
    ])
    gradient?.draw(in: tile, angle: -60)
}

func drawFlower(in rect: NSRect) {
    let configuration = NSImage.SymbolConfiguration(pointSize: SYMBOL_POINT_SIZE, weight: .medium)
        .applying(.init(paletteColors: [.white]))
    guard let symbol = NSImage(systemSymbolName: "camera.macro", accessibilityDescription: nil)?
        .withSymbolConfiguration(configuration) else { fatalError("SF Symbol camera.macro not found") }
    let origin = NSPoint(x: rect.midX - symbol.size.width / 2, y: rect.midY - symbol.size.height / 2)
    symbol.draw(at: origin, from: .zero, operation: .sourceOver, fraction: 1)
}

guard CommandLine.arguments.count > 1 else { fatalError("usage: make-icon.swift <output.png>") }
let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(CANVAS), pixelsHigh: Int(CANVAS), bitsPerSample: 8,
    samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
let tileRect = NSRect(x: TILE_INSET, y: TILE_INSET, width: CANVAS - 2 * TILE_INSET, height: CANVAS - 2 * TILE_INSET)
drawTile(in: tileRect)
drawFlower(in: tileRect)
NSGraphicsContext.restoreGraphicsState()
try! bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
