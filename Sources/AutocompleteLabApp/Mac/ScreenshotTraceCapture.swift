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
        expectedSignalRect: CGRect? = nil,
        visualTrustContext: CompatibilityLearningVisualTrustContext? = nil,
        allowsLearningCorrection: Bool = false
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
                let offsetResult = self.offsetDetectionResult(
                    screenshotURL: screenshotURL,
                    captureRect: rect,
                    expectedSignalRect: expectedSignalRect
                )
                let correctionMetadata = self.offsetCorrectionMetadata(
                    detection: offsetResult.detection,
                    bundleIdentifier: bundleIdentifier,
                    visualTrustContext: visualTrustContext,
                    allowsLearningCorrection: allowsLearningCorrection
                )
                DiagnosticsLog.shared.record(
                    "screenshot-captured",
                    metadata: [
                        "app": bundleIdentifier,
                        "path": screenshotURL.path,
                        "rect": Self.compactRectDescription(rect),
                        "durationMilliseconds": String(Self.milliseconds(from: startedAt, to: Date()))
                    ]
                    .merging(offsetResult.metadata) { current, _ in current }
                    .merging(correctionMetadata) { current, _ in current }
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

    private struct OffsetDetectionResult {
        var metadata: [String: String]
        var detection: ScreenshotPlacementOffsetDetection?
    }

    private func offsetDetectionResult(
        screenshotURL: URL,
        captureRect: CGRect,
        expectedSignalRect: CGRect?
    ) -> OffsetDetectionResult {
        guard let expectedSignalRect else {
            return OffsetDetectionResult(
                metadata: ["screenshotOffsetDetection": "not-requested"],
                detection: nil
            )
        }

        guard let bitmap = pixelBuffer(from: screenshotURL) else {
            return OffsetDetectionResult(
                metadata: ["screenshotOffsetDetection": "image-unreadable"],
                detection: nil
            )
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

        return OffsetDetectionResult(metadata: metadata, detection: detection)
    }

    private func offsetCorrectionMetadata(
        detection: ScreenshotPlacementOffsetDetection?,
        bundleIdentifier: String,
        visualTrustContext: CompatibilityLearningVisualTrustContext?,
        allowsLearningCorrection: Bool
    ) -> [String: String] {
        guard let detection else {
            return [
                "screenshotOffsetCorrection": "not-detected",
                "screenshotOffsetProof": VisualPlacementCorrectionProofOutcome.refused.rawValue,
                "screenshotOffsetProofPrivacy": "geometry-only"
            ]
        }

        guard detection.isDetected else {
            return [
                "screenshotOffsetCorrection": "not-detected",
                "screenshotOffsetProof": VisualPlacementCorrectionProofOutcome.refused.rawValue,
                "screenshotOffsetProofPrivacy": "geometry-only",
                "screenshotOffsetBadDetection": detection.reason.rawValue
            ]
        }

        guard allowsLearningCorrection else {
            let proof = VisualPlacementCorrection(
                dx: 0,
                dy: 0,
                decision: .rejected,
                reason: .insufficientEvidence
            ).proof(measuredDX: detection.dx, measuredDY: detection.dy)
            return [
                "screenshotOffsetCorrection": "diagnostics-only",
                "screenshotOffsetProof": proof.outcome.rawValue,
                "screenshotOffsetBeforeDistance": Self.format(proof.beforeDistance),
                "screenshotOffsetAfterDistance": Self.format(proof.afterDistance),
                "screenshotOffsetImprovement": Self.format(proof.improvement),
                "screenshotOffsetProofPrivacy": proof.privacyBoundary
            ]
        }

        let profile = CompatibilityLearningStore.shared.profile(for: bundleIdentifier)
        let observations = max(profile?.observations ?? 0, 1)
        let correction = VisualPlacementCorrectionPolicy().correction(
            dx: detection.dx,
            dy: detection.dy,
            observations: observations,
            confidence: detection.confidence
        )
        let proof = correction.proof(measuredDX: detection.dx, measuredDY: detection.dy)

        var metadata = [
            "screenshotOffsetCorrection": correction.decision.rawValue,
            "screenshotOffsetCorrectionReason": correction.reason.rawValue,
            "screenshotOffsetCorrectionObservations": String(observations),
            "screenshotOffsetAppliedDX": String(format: "%.1f", Double(correction.dx)),
            "screenshotOffsetAppliedDY": String(format: "%.1f", Double(correction.dy)),
            "screenshotOffsetProof": proof.outcome.rawValue,
            "screenshotOffsetBeforeDistance": Self.format(proof.beforeDistance),
            "screenshotOffsetAfterDistance": Self.format(proof.afterDistance),
            "screenshotOffsetImprovement": Self.format(proof.improvement),
            "screenshotOffsetProofPrivacy": proof.privacyBoundary
        ]

        guard correction.isApplied else {
            return metadata
        }

        let trustedBase = profile?.hasTrustedVisualAdjustment(in: visualTrustContext) == true
            ? profile
            : nil
        let xOffset = Double((trustedBase?.xOffset ?? 0) + correction.dx)
        let yOffset = Double((trustedBase?.yOffset ?? 0) + correction.dy)
        metadata["screenshotOffsetStoredX"] = String(format: "%.1f", xOffset)
        metadata["screenshotOffsetStoredY"] = String(format: "%.1f", yOffset)

        CompatibilityLearningStore.shared.updateOffset(
            x: xOffset,
            y: yOffset,
            for: bundleIdentifier,
            reason: "screenshot-visual-correction",
            visualTrustContext: visualTrustContext,
            confidence: detection.confidence
        )

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

    private static func format(_ value: CGFloat) -> String {
        String(format: "%.1f", Double(value))
    }

    private static func compactRectDescription(_ rect: CGRect) -> String {
        "x=\(Int(rect.origin.x.rounded())),y=\(Int(rect.origin.y.rounded())),w=\(Int(rect.width.rounded())),h=\(Int(rect.height.rounded()))"
    }
}
