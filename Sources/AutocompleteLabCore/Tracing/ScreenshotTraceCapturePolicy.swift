import Foundation

public struct ScreenshotTraceCapturePolicy: Equatable, Sendable {
    public init() {}

    public func shouldCapture(
        triggerReason _: String,
        globalScreenshotTracingEnabled: Bool,
        appScreenshotTracingEnabled: Bool,
        hasCaptureRegion: Bool,
        hasAlreadyCapturedSuggestionID: Bool
    ) -> Bool {
        guard globalScreenshotTracingEnabled || appScreenshotTracingEnabled else {
            return false
        }

        guard hasCaptureRegion else {
            return false
        }

        return !hasAlreadyCapturedSuggestionID
    }
}
