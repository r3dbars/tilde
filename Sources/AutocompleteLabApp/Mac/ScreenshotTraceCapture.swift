import CoreGraphics
import Foundation
import ImageIO
import AutocompleteLabCore

final class ScreenshotTraceCapture: @unchecked Sendable {
    static let shared = ScreenshotTraceCapture()

    private let queue = DispatchQueue(
        label: "app.transcripted.autocomplete.screenshot-trace-capture",
        qos: .utility
    )
    private let stateLock = NSLock()
    private var pendingCaptureCount = 0
    private let maxPendingCaptures = 2
    private let captureTimeoutSeconds: TimeInterval = 2

    private init() {}

    func capture(
        rect: CGRect,
        to screenshotURL: URL,
        bundleIdentifier: String,
        expectedSignalRect: CGRect? = nil
    ) {
        guard reserveCaptureSlot(bundleIdentifier: bundleIdentifier) else {
            return
        }

        queue.async {
            let startedAt = Date()
            defer {
                self.releaseCaptureSlot()
            }

            guard CGPreflightScreenCaptureAccess() else {
                DiagnosticsLog.shared.record(
                    "screenshot-capture-blocked",
                    metadata: [
                        "app": bundleIdentifier,
                        "reason": "screen-recording-permission"
                    ]
                )
                return
            }

            do {
                try FileManager.default.createDirectory(
                    at: screenshotURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )

                Thread.sleep(forTimeInterval: 0.05)

                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                process.arguments = [
                    "-x",
                    "-R\(Int(rect.origin.x)),\(Int(rect.origin.y)),\(Int(rect.width)),\(Int(rect.height))",
                    screenshotURL.path
                ]
                try process.run()
                let timeout = Date().addingTimeInterval(self.captureTimeoutSeconds)
                while process.isRunning && Date() < timeout {
                    Thread.sleep(forTimeInterval: 0.02)
                }

                if process.isRunning {
                    process.terminate()
                    DiagnosticsLog.shared.record(
                        "screenshot-capture-failed",
                        metadata: [
                            "app": bundleIdentifier,
                            "reason": "timeout",
                            "durationMilliseconds": String(Self.milliseconds(from: startedAt, to: Date()))
                        ]
                    )
                    return
                }

                guard process.terminationStatus == 0,
                      FileManager.default.fileExists(atPath: screenshotURL.path) else {
                    DiagnosticsLog.shared.record(
                        "screenshot-capture-failed",
                        metadata: [
                            "app": bundleIdentifier,
                            "status": String(process.terminationStatus),
                            "durationMilliseconds": String(Self.milliseconds(from: startedAt, to: Date()))
                        ]
                    )
                    return
                }

                CompatibilityLearningStore.shared.recordObservation(
                    for: bundleIdentifier,
                    reason: "screenshot-captured"
                )
                let offsetMetadata = self.offsetDetectionMetadata(
                    screenshotURL: screenshotURL,
                    captureRect: rect,
                    expectedSignalRect: expectedSignalRect
                )
                DiagnosticsLog.shared.record(
                    "screenshot-captured",
                    metadata: [
                        "app": bundleIdentifier,
                        "path": screenshotURL.path,
                        "rect": Self.compactRectDescription(rect),
                        "durationMilliseconds": String(Self.milliseconds(from: startedAt, to: Date()))
                    ].merging(offsetMetadata) { current, _ in current }
                )
            } catch {
                DiagnosticsLog.shared.record(
                    "screenshot-capture-failed",
                    metadata: [
                        "app": bundleIdentifier,
                        "reason": error.localizedDescription
                    ]
                )
            }
        }
    }

    private func offsetDetectionMetadata(
        screenshotURL: URL,
        captureRect: CGRect,
        expectedSignalRect: CGRect?
    ) -> [String: String] {
        guard let expectedSignalRect else {
            return ["screenshotOffsetDetection": "not-requested"]
        }

        guard let bitmap = pixelBuffer(from: screenshotURL) else {
            return ["screenshotOffsetDetection": "image-unreadable"]
        }

        let detection = ScreenshotPlacementOffsetDetector().detection(
            in: bitmap,
            captureRect: captureRect,
            expectedSignalRect: expectedSignalRect
        )
        var metadata = [
            "screenshotOffsetDetection": detection.reason.rawValue,
            "screenshotOffsetConfidence": String(format: "%.2f", detection.confidence),
            "screenshotOffsetPixels": String(detection.signalPixelCount),
            "screenshotOffsetDX": String(format: "%.1f", Double(detection.dx)),
            "screenshotOffsetDY": String(format: "%.1f", Double(detection.dy))
        ]

        if let bounds = detection.signalBounds {
            metadata["screenshotOffsetSignalBounds"] = Self.compactRectDescription(bounds)
        }

        return metadata
    }

    private func pixelBuffer(from screenshotURL: URL) -> ScreenshotPlacementPixelBuffer? {
        guard let source = CGImageSourceCreateWithURL(screenshotURL as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }

        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else {
            return nil
        }

        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue
            | CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var pixels: [ScreenshotPlacementPixel] = []
        pixels.reserveCapacity(width * height)
        for index in stride(from: 0, to: bytes.count, by: 4) {
            pixels.append(
                ScreenshotPlacementPixel(
                    red: bytes[index],
                    green: bytes[index + 1],
                    blue: bytes[index + 2],
                    alpha: bytes[index + 3]
                )
            )
        }

        return ScreenshotPlacementPixelBuffer(width: width, height: height, pixels: pixels)
    }

    private func reserveCaptureSlot(bundleIdentifier: String) -> Bool {
        stateLock.lock()
        if pendingCaptureCount < maxPendingCaptures {
            pendingCaptureCount += 1
            stateLock.unlock()
            return true
        }

        let pending = pendingCaptureCount
        stateLock.unlock()

        DiagnosticsLog.shared.record(
            "screenshot-capture-skipped",
            metadata: [
                "app": bundleIdentifier,
                "reason": "backlog",
                "pending": String(pending)
            ]
        )
        return false
    }

    private func releaseCaptureSlot() {
        stateLock.lock()
        pendingCaptureCount = max(0, pendingCaptureCount - 1)
        stateLock.unlock()
    }

    private static func milliseconds(from start: Date, to end: Date) -> Int {
        max(0, Int(end.timeIntervalSince(start) * 1000))
    }

    private static func compactRectDescription(_ rect: CGRect) -> String {
        "x=\(Int(rect.origin.x.rounded())),y=\(Int(rect.origin.y.rounded())),w=\(Int(rect.width.rounded())),h=\(Int(rect.height.rounded()))"
    }
}
