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
    NSColor(calibratedRed: 0.25, green: 0.28, blue: 0.70, alpha: 1).setFill()
    squircle.fill()
    NSShadow().set()

    NSGradient(colors: [
        NSColor(calibratedRed: 0.38, green: 0.42, blue: 0.92, alpha: 1),
        NSColor(calibratedRed: 0.22, green: 0.24, blue: 0.62, alpha: 1),
    ])!.draw(in: squircle, angle: -90)

    // Avatar disc
    let avatarD = tile.width * 0.56
    let avatar = NSRect(x: tile.midX - avatarD / 2, y: tile.midY - avatarD / 2 + tile.height * 0.03, width: avatarD, height: avatarD)
    NSColor.white.setFill()
    NSBezierPath(ovalIn: avatar).fill()

    // Person silhouette, clipped to the disc
    NSGraphicsContext.current?.saveGraphicsState()
    NSBezierPath(ovalIn: avatar).addClip()
    NSColor(calibratedRed: 0.30, green: 0.33, blue: 0.78, alpha: 1).setFill()
    let headD = avatarD * 0.34
    NSBezierPath(ovalIn: NSRect(x: avatar.midX - headD / 2, y: avatar.midY + avatarD * 0.02, width: headD, height: headD)).fill()
    let bodyW = avatarD * 0.66, bodyH = avatarD * 0.52
    NSBezierPath(ovalIn: NSRect(x: avatar.midX - bodyW / 2, y: avatar.minY - bodyH * 0.45, width: bodyW, height: bodyH)).fill()
    NSGraphicsContext.current?.restoreGraphicsState()

    // Presence dot (Teams "Available" green) with white ring and check mark
    let dotD = tile.width * 0.26
    let dot = NSRect(x: avatar.maxX - dotD * 0.78, y: avatar.minY - dotD * 0.05, width: dotD, height: dotD)
    NSColor.white.setFill()
    NSBezierPath(ovalIn: dot.insetBy(dx: -dotD * 0.10, dy: -dotD * 0.10)).fill()
    NSColor(calibratedRed: 0.36, green: 0.69, blue: 0.33, alpha: 1).setFill()
    NSBezierPath(ovalIn: dot).fill()

    let check = NSBezierPath()
    check.lineWidth = dotD * 0.13
    check.lineCapStyle = .round
    check.lineJoinStyle = .round
    check.move(to: NSPoint(x: dot.minX + dotD * 0.28, y: dot.midY))
    check.line(to: NSPoint(x: dot.minX + dotD * 0.44, y: dot.midY - dotD * 0.15))
    check.line(to: NSPoint(x: dot.minX + dotD * 0.72, y: dot.midY + dotD * 0.17))
    NSColor.white.setStroke()
    check.stroke()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for (points, scale) in [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)] {
    let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
    try render(px: points * scale).write(to: outDir.appendingPathComponent(name))
}
print("Wrote iconset to \(outDir.path)")
