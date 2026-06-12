// Renders the app icon: a purple-blue gradient rounded square with a sparkles
// symbol, in the style of macOS Big Sur+ icons. Run: swift Scripts/make-icon.swift <out.png>
import AppKit

let size: CGFloat = 1024
let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"

let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

// macOS icon grid: the squircle occupies ~824pt of a 1024pt canvas.
let inset: CGFloat = size * 0.098
let rect = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
let squircle = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.225, yRadius: rect.width * 0.225)

let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.55, green: 0.27, blue: 0.97, alpha: 1),
    NSColor(calibratedRed: 0.20, green: 0.45, blue: 0.98, alpha: 1),
])!
gradient.draw(in: squircle, angle: -60)

let config = NSImage.SymbolConfiguration(pointSize: size * 0.42, weight: .medium)
if let symbol = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)?
    .withSymbolConfiguration(config) {
    let tinted = NSImage(size: symbol.size)
    tinted.lockFocus()
    symbol.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1)
    NSColor.white.set()
    NSRect(origin: .zero, size: symbol.size).fill(using: .sourceAtop)
    tinted.unlockFocus()

    let symbolRect = NSRect(
        x: (size - tinted.size.width) / 2,
        y: (size - tinted.size.height) / 2,
        width: tinted.size.width,
        height: tinted.size.height
    )
    tinted.draw(in: symbolRect)
}

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not render icon")
}
try png.write(to: URL(fileURLWithPath: outPath))
print("Wrote \(outPath)")
