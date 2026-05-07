import CoreGraphics
import Foundation

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
        bundleIdentifier: String
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
                DiagnosticsLog.shared.record(
                    "screenshot-captured",
                    metadata: [
                        "app": bundleIdentifier,
                        "path": screenshotURL.path,
                        "rect": Self.compactRectDescription(rect),
                        "durationMilliseconds": String(Self.milliseconds(from: startedAt, to: Date()))
                    ]
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
