// Generates Harbor's original vector icon; no external assets.
import AppKit
let size = 256
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: size * 4, bitsPerPixel: 32)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSColor(red: 0.065, green: 0.105, blue: 0.12, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()
for index in 0..<3 {
    let y = CGFloat(72 + index * 47)
    let path = NSBezierPath()
    path.move(to: NSPoint(x: 49, y: y))
    path.curve(to: NSPoint(x: 207, y: y), controlPoint1: NSPoint(x: 97, y: y + 38), controlPoint2: NSPoint(x: 159, y: y - 38))
    path.lineWidth = 13
    path.lineCapStyle = .round
    NSColor(red: 0.64, green: 0.91, blue: 0.84, alpha: CGFloat(0.6 + Double(index) * 0.2)).setStroke()
    path.stroke()
}
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
