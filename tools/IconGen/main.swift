// IconGen — renders the JSONViewer app icon master PNG (1024x1024) with Core Graphics.
// Usage: swiftc tools/IconGen/main.swift -o /tmp/icongen && /tmp/icongen <out.png>
// Then sips/iconutil turn the master into AppIcon.icns (see tools/make_icon.sh).

import AppKit
import CoreGraphics
import Foundation

let size = 1024.0
let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/AppIcon-1024.png"

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
) else { fatalError("rep") }

let ctxNS = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = ctxNS
let ctx = ctxNS.cgContext

func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
    CGColor(red: r/255, green: g/255, blue: b/255, alpha: a)
}

// Transparent canvas (macOS icons keep rounded corners transparent).
ctx.clear(CGRect(x: 0, y: 0, width: size, height: size))

// --- Rounded-rect ("squircle") plate with padding, like a Big Sur icon grid. ---
let margin = 90.0
let plate = CGRect(x: margin, y: margin, width: size - 2*margin, height: size - 2*margin)
let radius = plate.width * 0.225   // ~squircle corner

// Soft drop shadow under the plate.
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 46,
              color: rgb(0, 0, 0, 0.35))
let platePath = CGPath(roundedRect: plate, cornerWidth: radius, cornerHeight: radius, transform: nil)
ctx.addPath(platePath)
ctx.setFillColor(rgb(255, 255, 255))
ctx.fillPath()
ctx.restoreGState()

// Gradient fill (blue -> teal diagonal), clipped to the plate.
ctx.saveGState()
ctx.addPath(platePath)
ctx.clip()
let space = CGColorSpaceCreateDeviceRGB()
let grad = CGGradient(colorsSpace: space,
                      colors: [rgb(45, 108, 246), rgb(34, 184, 196)] as CFArray,
                      locations: [0.0, 1.0])!
ctx.drawLinearGradient(grad,
                       start: CGPoint(x: plate.minX, y: plate.maxY),
                       end: CGPoint(x: plate.maxX, y: plate.minY),
                       options: [])

// Subtle top highlight for depth.
let hl = CGGradient(colorsSpace: space,
                    colors: [rgb(255, 255, 255, 0.22), rgb(255, 255, 255, 0.0)] as CFArray,
                    locations: [0.0, 0.55])!
ctx.drawLinearGradient(hl,
                       start: CGPoint(x: plate.midX, y: plate.maxY),
                       end: CGPoint(x: plate.midX, y: plate.midY),
                       options: [])
ctx.restoreGState()

// --- Content rows between the braces (evoke JSON key/value lines, app colors). ---
// Three rows: a teal "key" pill + a lighter "value" pill each, descending widths.
func roundedBar(_ r: CGRect, _ color: CGColor) {
    let p = CGPath(roundedRect: r, cornerWidth: r.height/2, cornerHeight: r.height/2, transform: nil)
    ctx.addPath(p); ctx.setFillColor(color); ctx.fillPath()
}
let rowH = 64.0
let rowGap = 70.0
let rowsTotal = rowH*3 + rowGap*2
var rowY = size/2 + rowsTotal/2 - rowH      // top row (Core Graphics y is bottom-up)
let keyColor = rgb(255, 255, 255, 0.96)
let valColor = rgb(255, 255, 255, 0.55)
let rowSpecs: [(key: Double, val: Double)] = [(150, 250), (150, 180), (150, 300)]
for spec in rowSpecs {
    let startX = size/2 - 240
    roundedBar(CGRect(x: startX, y: rowY, width: spec.key, height: rowH), keyColor)
    roundedBar(CGRect(x: startX + spec.key + 36, y: rowY, width: spec.val, height: rowH), valColor)
    rowY -= (rowH + rowGap)
}

// --- Curly braces { } framing the content, drawn as bold glyphs. ---
func drawBrace(_ s: String, centerX: Double) {
    let font = NSFont(name: "Menlo-Bold", size: 720) ?? NSFont.boldSystemFont(ofSize: 720)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white,
    ]
    let str = NSAttributedString(string: s, attributes: attrs)
    let bounds = str.size()
    let x = centerX - bounds.width/2
    let y = size/2 - bounds.height/2 - 14
    str.draw(at: NSPoint(x: x, y: y))
}
drawBrace("{", centerX: size*0.215)
drawBrace("}", centerX: size*0.785)

// --- Write PNG. ---
guard let data = rep.representation(using: .png, properties: [:]) else { fatalError("png") }
try! data.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
