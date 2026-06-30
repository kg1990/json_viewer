// OGGen — renders the 1200x630 Open Graph image for the JSONViewer landing page.
// Usage: swiftc tools/OGGen/main.swift -o /tmp/oggen && /tmp/oggen <icon.png> <out.png>

import AppKit
import CoreGraphics
import Foundation

let W = 1200.0
let H = 630.0
let iconPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "docs/assets/icon.png"
let outPath  = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "docs/assets/og-image.png"

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
) else { fatalError("rep") }

let ctxNS = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = ctxNS
let ctx = ctxNS.cgContext

func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
    CGColor(red: r/255, green: g/255, blue: b/255, alpha: a)
}

// Brand gradient background #2D6CF6 -> #22B8C4 (diagonal).
let cs = CGColorSpaceCreateDeviceRGB()
let grad = CGGradient(colorsSpace: cs,
    colors: [rgb(45, 108, 246), rgb(34, 184, 196)] as CFArray,
    locations: [0, 1])!
ctx.drawLinearGradient(grad,
    start: CGPoint(x: 0, y: H),
    end: CGPoint(x: W, y: 0),
    options: [])

// Subtle darkening vignette at bottom for text contrast.
let vg = CGGradient(colorsSpace: cs,
    colors: [rgb(0, 0, 0, 0.0), rgb(0, 0, 0, 0.18)] as CFArray,
    locations: [0, 1])!
ctx.drawLinearGradient(vg, start: CGPoint(x: 0, y: H), end: CGPoint(x: 0, y: 0), options: [])

// Faint code specimen watermark (monospaced) in the lower right.
let wmStr = "{ \"$\": [*].id }"
let wmAttr: [NSAttributedString.Key: Any] = [
    .font: NSFont.monospacedSystemFont(ofSize: 34, weight: .medium),
    .foregroundColor: NSColor(cgColor: rgb(255,255,255,0.16))!
]
NSString(string: wmStr).draw(at: NSPoint(x: 720, y: 70), withAttributes: wmAttr)

// App icon on the left, with soft shadow.
let iconSize = 300.0
let iconX = 96.0
let iconY = (H - iconSize) / 2
if let img = NSImage(contentsOfFile: iconPath) {
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 30, color: rgb(0,0,0,0.30))
    img.draw(in: NSRect(x: iconX, y: iconY, width: iconSize, height: iconSize))
    ctx.restoreGState()
}

let textX = iconX + iconSize + 64
// Title "JSONViewer".
let titleAttr: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 96, weight: .bold),
    .foregroundColor: NSColor.white
]
NSString(string: "JSONViewer").draw(at: NSPoint(x: textX, y: 360), withAttributes: titleAttr)

// Tagline.
let tagAttr: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 38, weight: .medium),
    .foregroundColor: NSColor(cgColor: rgb(255,255,255,0.92))!
]
NSString(string: "Free, native JSON tool for macOS").draw(at: NSPoint(x: textX, y: 296), withAttributes: tagAttr)

// Feature line.
let subAttr: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 28, weight: .regular),
    .foregroundColor: NSColor(cgColor: rgb(255,255,255,0.82))!
]
NSString(string: "Format · Validate · Tree · JSONPath · 9 transforms").draw(at: NSPoint(x: textX, y: 236), withAttributes: subAttr)

// Pill "Open source · Offline · Apple Silicon".
let pillStr = "Open source  ·  Offline  ·  Apple Silicon"
let pillFont = NSFont.systemFont(ofSize: 24, weight: .semibold)
let pillTextW = NSString(string: pillStr).size(withAttributes: [.font: pillFont]).width
let pillW = pillTextW + 56
let pillRect = CGRect(x: textX, y: 150, width: pillW, height: 56)
let pillPath = CGPath(roundedRect: pillRect, cornerWidth: 28, cornerHeight: 28, transform: nil)
ctx.addPath(pillPath)
ctx.setFillColor(rgb(255,255,255,0.18))
ctx.fillPath()
let pillAttr: [NSAttributedString.Key: Any] = [
    .font: pillFont,
    .foregroundColor: NSColor.white
]
NSString(string: pillStr).draw(at: NSPoint(x: textX + 28, y: 164), withAttributes: pillAttr)

guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("png") }
try! png.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
