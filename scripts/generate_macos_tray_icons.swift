import AppKit

// Render the existing cat/wave geometry without the app icon's background.
// Run from the repository root: swift scripts/generate_macos_tray_icons.swift
for (state, color) in [
    ("active", NSColor(srgbRed: 0.08, green: 0.72, blue: 0.76, alpha: 1)),
    ("inactive", NSColor(srgbRed: 0.55, green: 0.58, blue: 0.60, alpha: 1)),
] {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: 64, pixelsHigh: 64,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
        isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let context = NSGraphicsContext.current!.cgContext
    context.clear(CGRect(x: 0, y: 0, width: 64, height: 64))
    // A filled outer silhouette stays legible at the menu bar's 18pt size.
    // Cat ears form the top; a single broad wave forms the lower edge.
    context.translateBy(x: 0, y: 64)
    context.scaleBy(x: 1, y: -1)
    context.setFillColor(color.cgColor)
    context.move(to: CGPoint(x: 8, y: 52))
    context.addLine(to: CGPoint(x: 12, y: 7))
    context.addQuadCurve(to: CGPoint(x: 16, y: 6), control: CGPoint(x: 13, y: 2))
    context.addLine(to: CGPoint(x: 25, y: 20))
    context.addQuadCurve(to: CGPoint(x: 39, y: 20), control: CGPoint(x: 32, y: 17))
    context.addLine(to: CGPoint(x: 48, y: 6))
    context.addQuadCurve(to: CGPoint(x: 52, y: 7), control: CGPoint(x: 51, y: 2))
    context.addLine(to: CGPoint(x: 56, y: 52))
    context.addCurve(to: CGPoint(x: 32, y: 55), control1: CGPoint(x: 48, y: 65), control2: CGPoint(x: 41, y: 49))
    context.addCurve(to: CGPoint(x: 8, y: 52), control1: CGPoint(x: 21, y: 64), control2: CGPoint(x: 15, y: 58))
    context.closePath()
    context.fillPath()
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(
        to: URL(fileURLWithPath: "assets/tray_macos_\(state).png")
    )
}
