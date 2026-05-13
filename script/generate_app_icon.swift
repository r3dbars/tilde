#!/usr/bin/env swift

import AppKit
import Foundation

let outputPath = CommandLine.arguments.dropFirst().first ?? "dist/SteadyType.app/Contents/Resources/AppIcon.icns"
let sourcePath = CommandLine.arguments.dropFirst(2).first ?? "Assets/AppIcon/steadytype-icon.png"
let outputURL = URL(fileURLWithPath: outputPath)
let sourceURL = URL(fileURLWithPath: sourcePath)
let fileManager = FileManager.default
let iconsetURL = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("SteadyType-\(UUID().uuidString).iconset", isDirectory: true)
let temporaryOutputURL = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("SteadyType-\(UUID().uuidString).icns")

guard let sourceImage = NSImage(contentsOf: sourceURL) else {
    throw NSError(
        domain: "SteadyTypeIcon",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Could not load icon source at \(sourcePath)"]
    )
}

try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
defer { try? fileManager.removeItem(at: iconsetURL) }
defer { try? fileManager.removeItem(at: temporaryOutputURL) }

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

func scaledIcon(pixels: CGFloat) -> NSImage {
    let size = NSSize(width: pixels, height: pixels)
    let image = NSImage(size: size)
    image.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    sourceImage.draw(
        in: NSRect(origin: .zero, size: size),
        from: NSRect(origin: .zero, size: sourceImage.size),
        operation: .copy,
        fraction: 1
    )
    image.unlockFocus()
    return image
}

func writePNG(named name: String, pixels: CGFloat) throws {
    let image = scaledIcon(pixels: pixels)
    guard
        let tiffData = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiffData),
        let pngData = bitmap.representation(using: .png, properties: [:])
    else {
        throw NSError(
            domain: "SteadyTypeIcon",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Could not render \(name)"]
        )
    }

    try pngData.write(to: iconsetURL.appendingPathComponent(name))
}

for file in iconFiles {
    try writePNG(named: file.name, pixels: file.points * file.scale)
}

try fileManager.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetURL.path, "-o", temporaryOutputURL.path]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    throw NSError(
        domain: "SteadyTypeIcon",
        code: Int(process.terminationStatus),
        userInfo: [NSLocalizedDescriptionKey: "iconutil failed"]
    )
}

try? fileManager.removeItem(at: outputURL)
try fileManager.moveItem(at: temporaryOutputURL, to: outputURL)
