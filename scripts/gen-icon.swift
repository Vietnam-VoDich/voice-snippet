#!/usr/bin/env swift
// Generate AppIcon.icns for Voice Snippet.
// Usage: swift scripts/gen-icon.swift <output.icns>

import AppKit

let outPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "AppIcon.icns"

let sizes: [(name: String, px: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

func draw(_ size: Int) -> Data {
    let s = CGFloat(size)
    let image = NSImage(size: NSSize(width: s, height: s))
    image.lockFocus()

    // Rounded-square background with a blue gradient
    let inset = s * 0.06
    let radius = s * 0.225
    let rect = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let bgPath = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

    NSGraphicsContext.saveGraphicsState()
    bgPath.addClip()
    let top = NSColor(red: 0.38, green: 0.58, blue: 1.00, alpha: 1.0)
    let bot = NSColor(red: 0.14, green: 0.28, blue: 0.80, alpha: 1.0)
    let gradient = NSGradient(starting: top, ending: bot)!
    gradient.draw(in: rect, angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    NSColor.white.setFill()
    NSColor.white.setStroke()

    // Microphone capsule
    let micW = s * 0.26
    let micH = s * 0.40
    let micX = (s - micW) / 2
    let micY = s * 0.38
    let mic = NSBezierPath(roundedRect: NSRect(x: micX, y: micY, width: micW, height: micH),
                           xRadius: micW / 2, yRadius: micW / 2)
    mic.fill()

    // U-shaped stand under the capsule
    let cx = s / 2
    let cy = micY + s * 0.02
    let r = s * 0.22
    let stand = NSBezierPath()
    stand.appendArc(withCenter: NSPoint(x: cx, y: cy),
                    radius: r,
                    startAngle: 200, endAngle: 340)
    stand.lineWidth = s * 0.04
    stand.lineCapStyle = .round
    stand.stroke()

    // Stem + base plate
    let stemW = s * 0.035
    let stemH = s * 0.09
    let stemY = cy - r - stemH * 0.5
    let stem = NSBezierPath(rect: NSRect(x: cx - stemW / 2, y: stemY, width: stemW, height: stemH))
    stem.fill()
    let baseW = s * 0.18
    let baseH = s * 0.035
    let base = NSBezierPath(roundedRect: NSRect(x: cx - baseW / 2, y: stemY - baseH,
                                                 width: baseW, height: baseH),
                            xRadius: baseH / 2, yRadius: baseH / 2)
    base.fill()

    image.unlockFocus()

    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        fatalError("Could not render PNG at size \(size)")
    }
    return png
}

let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("VoiceSnippet-\(UUID().uuidString).iconset")
try! FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)

for (name, px) in sizes {
    let data = draw(px)
    try! data.write(to: tmp.appendingPathComponent(name))
}

let process = Process()
process.launchPath = "/usr/bin/iconutil"
process.arguments = ["-c", "icns", tmp.path, "-o", outPath]
process.launch()
process.waitUntilExit()

try? FileManager.default.removeItem(at: tmp)

if process.terminationStatus == 0 {
    print("wrote \(outPath)")
} else {
    fatalError("iconutil failed with status \(process.terminationStatus)")
}
