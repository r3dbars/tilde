import CoreGraphics
import Foundation

final class ScreenshotTraceCapture: @unchecked Sendable {
    static let shared = ScreenshotTraceCapture()

    private let queue = DispatchQueue(
        label: "app.transcripted.autocomplete.screenshot-trace-capture",
        qos: .utility
    )

    private init() {}

    func capture(
        rect: CGRect,
        to screenshotURL: URL,
        bundleIdentifier: String
    ) {
        queue.async {
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
                process.waitUntilExit()

                guard process.terminationStatus == 0,
                      FileManager.default.fileExists(atPath: screenshotURL.path) else {
                    DiagnosticsLog.shared.record(
                        "screenshot-capture-failed",
                        metadata: [
                            "app": bundleIdentifier,
                            "status": String(process.terminationStatus)
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
                        "rect": Self.compactRectDescription(rect)
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

    private static func compactRectDescription(_ rect: CGRect) -> String {
        "x=\(Int(rect.origin.x.rounded())),y=\(Int(rect.origin.y.rounded())),w=\(Int(rect.width.rounded())),h=\(Int(rect.height.rounded()))"
    }
}
