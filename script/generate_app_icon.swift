#!/usr/bin/env swift

import AppKit
import Foundation

let outputPath = CommandLine.arguments.dropFirst().first ?? "dist/AutocompleteLab.app/Contents/Resources/AppIcon.icns"
let outputURL = URL(fileURLWithPath: outputPath)
let fileManager = FileManager.default
let iconsetURL = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("AutocompleteLab-\(UUID().uuidString).iconset", isDirectory: true)

try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
defer { try? fileManager.removeItem(at: iconsetURL) }

let iconFiles: [(name: String, points: CGFloat, scale: CGFloat)] = [
    ("icon_16x16.png", 16, 1),
    ("icon_16x16@2x.png", 16, 2),
    ("icon_32x32.png", 32, 1),
    ("icon_32x32@2x.png", 32, 2),
    ("icon_128x128.png", 128, 1),
    ("icon_128x128@2x.png", 128, 2),
    ("icon_256x256.png", 256, 1),
    ("icon_256x256@2x.png", 256, 2),
    ("icon_512x512.png", 512, 1),
    ("icon_512x512@2x.png", 512, 2)
]

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    rect.fill()

    let inset = size * 0.078
    let baseRect = rect.insetBy(dx: inset, dy: inset)
    let radius = size * 0.18
    let basePath = NSBezierPath(roundedRect: baseRect, xRadius: radius, yRadius: radius)

    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.08, green: 0.10, blue: 0.13, alpha: 1),
        NSColor(calibratedRed: 0.16, green: 0.18, blue: 0.23, alpha: 1)
    ])
    gradient?.draw(in: basePath, angle: 90)

    NSColor(calibratedWhite: 1, alpha: 0.10).setStroke()
    basePath.lineWidth = max(1, size * 0.012)
    basePath.stroke()

    let left = size * 0.26
    let midY = size * 0.52
    let lineHeight = max(3, size * 0.052)
    let primaryWidth = size * 0.27
    let ghostWidth = size * 0.34
    let gap = size * 0.035

    let primaryPath = NSBezierPath(
        roundedRect: NSRect(x: left, y: midY, width: primaryWidth, height: lineHeight),
        xRadius: lineHeight / 2,
        yRadius: lineHeight / 2
    )
    NSColor(calibratedWhite: 0.96, alpha: 1).setFill()
    primaryPath.fill()

    let cursorWidth = max(3, size * 0.026)
    let cursorRect = NSRect(
        x: left + primaryWidth + gap,
        y: midY - size * 0.09,
        width: cursorWidth,
        height: size * 0.25
    )
    let cursorPath = NSBezierPath(roundedRect: cursorRect, xRadius: cursorWidth / 2, yRadius: cursorWidth / 2)
    NSColor(calibratedRed: 0.18, green: 0.55, blue: 1.0, alpha: 1).setFill()
    cursorPath.fill()

    let ghostPath = NSBezierPath(
        roundedRect: NSRect(x: cursorRect.maxX + gap, y: midY, width: ghostWidth, height: lineHeight),
        xRadius: lineHeight / 2,
        yRadius: lineHeight / 2
    )
    NSColor(calibratedWhite: 0.78, alpha: 0.46).setFill()
    ghostPath.fill()

    let smallPath = NSBezierPath(
        roundedRect: NSRect(x: left, y: midY - size * 0.17, width: size * 0.44, height: lineHeight * 0.72),
        xRadius: lineHeight / 3,
        yRadius: lineHeight / 3
    )
    NSColor(calibratedWhite: 0.82, alpha: 0.34).setFill()
    smallPath.fill()

    image.unlockFocus()
    return image
}

func writePNG(named name: String, pixels: CGFloat) throws {
    let image = drawIcon(size: pixels)
    guard
        let tiffData = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiffData),
        let pngData = bitmap.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "AutocompleteLabIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not render \(name)"])
    }

    try pngData.write(to: iconsetURL.appendingPathComponent(name))
}

for file in iconFiles {
    try writePNG(named: file.name, pixels: file.points * file.scale)
}

try fileManager.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetURL.path, "-o", outputURL.path]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    throw NSError(domain: "AutocompleteLabIcon", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "iconutil failed"])
}
