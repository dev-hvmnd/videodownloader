import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Foundation

// Draws a 1024×1024 app icon (gradient squircle + white download arrow into a tray).
// Usage: swift make-icon.swift <output.png>

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
let size = 1024
let s = CGFloat(size)

let space = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("CGContext") }

// Background: rounded rectangle with a diagonal gradient (indigo → fuchsia)
let margin: CGFloat = 96
let rect = CGRect(x: margin, y: margin, width: s - 2 * margin, height: s - 2 * margin)
let bg = CGPath(roundedRect: rect, cornerWidth: 200, cornerHeight: 200, transform: nil)
ctx.saveGState()
ctx.addPath(bg)
ctx.clip()
let colors = [
    CGColor(red: 0.36, green: 0.31, blue: 0.90, alpha: 1),
    CGColor(red: 0.76, green: 0.15, blue: 0.83, alpha: 1),
] as CFArray
let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1])!
ctx.drawLinearGradient(gradient,
                       start: CGPoint(x: rect.minX, y: rect.maxY),
                       end: CGPoint(x: rect.maxX, y: rect.minY),
                       options: [])
ctx.restoreGState()

// White download arrow
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
let cx = s / 2

let shaftW: CGFloat = 96
ctx.addPath(CGPath(roundedRect: CGRect(x: cx - shaftW / 2, y: 470, width: shaftW, height: 200),
                   cornerWidth: shaftW / 2, cornerHeight: shaftW / 2, transform: nil))
ctx.fillPath()

let headW: CGFloat = 250
let head = CGMutablePath()
head.move(to: CGPoint(x: cx - headW / 2, y: 510))
head.addLine(to: CGPoint(x: cx + headW / 2, y: 510))
head.addLine(to: CGPoint(x: cx, y: 350))
head.closeSubpath()
ctx.addPath(head)
ctx.fillPath()

// Tray (container open at the top)
let lineW: CGFloat = 72
let left: CGFloat = 318
let right: CGFloat = 706
let bottomY: CGFloat = 300
let sideTopY: CGFloat = 440
ctx.addPath(CGPath(roundedRect: CGRect(x: left, y: bottomY, width: right - left, height: lineW),
                   cornerWidth: 28, cornerHeight: 28, transform: nil))
ctx.addPath(CGPath(roundedRect: CGRect(x: left, y: bottomY, width: lineW, height: sideTopY - bottomY),
                   cornerWidth: 28, cornerHeight: 28, transform: nil))
ctx.addPath(CGPath(roundedRect: CGRect(x: right - lineW, y: bottomY, width: lineW, height: sideTopY - bottomY),
                   cornerWidth: 28, cornerHeight: 28, transform: nil))
ctx.fillPath()

guard let image = ctx.makeImage() else { fatalError("makeImage") }
let url = URL(fileURLWithPath: outPath)
guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fatalError("dest")
}
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("finalize") }
print("Icon written: \(outPath)")
