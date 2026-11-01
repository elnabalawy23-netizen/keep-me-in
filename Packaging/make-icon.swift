// Draws the app icon with AppKit and writes an .iconset folder.
// Usage: swift Packaging/make-icon.swift <output.iconset>
import AppKit

let outDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build/AppIcon.iconset")
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

func render(px: Int) -> Data {
    let s = CGFloat(px)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // macOS icon grid: the squircle sits inside a ~10% margin.
    let margin = s * 0.10
    let tile = NSRect(x: margin, y: margin, width: s - 2 * margin, height: s - 2 * margin)
    let squircle = NSBezierPath(roundedRect: tile, xRadius: tile.width * 0.2237, yRadius: tile.width * 0.2237)

    let shadow = NSShadow()
    shadow.shadowBlurRadius = s * 0.02
    shadow.shadowOffset = NSSize(width: 0, height: -s * 0.01)
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.set()
    NSColor(calibratedRed: 0.16, green: 0.14, blue: 0.13, alpha: 1).setFill()
    squircle.fill()
    NSShadow().set()

    // Warm dark tile, matching the menu panel.
    NSGradient(colors: [
        NSColor(calibratedRed: 0.25, green: 0.22, blue: 0.20, alpha: 1),
        NSColor(calibratedRed: 0.13, green: 0.12, blue: 0.11, alpha: 1),
    ])!.draw(in: squircle, angle: -90)

    // Steaming cup in the panel's tan accent.
    let tan = NSColor(calibratedRed: 0.914, green: 0.796, blue: 0.635, alpha: 1)
    let config = NSImage.SymbolConfiguration(pointSize: s * 0.40, weight: .medium)
    if let symbol = NSImage(systemSymbolName: "cup.and.heat.waves.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let tinted = NSImage(size: symbol.size, flipped: false) { rect in
            symbol.draw(in: rect)
            tan.set()
            rect.fill(using: .sourceAtop)
            return true
        }
        let glyph = NSRect(x: tile.midX - tinted.size.width / 2, y: tile.midY - tinted.size.height / 2,
                           width: tinted.size.width, height: tinted.size.height)
        tinted.draw(in: glyph)
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for (points, scale) in [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)] {
    let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
    try render(px: points * scale).write(to: outDir.appendingPathComponent(name))
}
print("Wrote iconset to \(outDir.path)")
