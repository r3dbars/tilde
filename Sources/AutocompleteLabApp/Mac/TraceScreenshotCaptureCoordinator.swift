import AutocompleteLabCore
import CoreGraphics
import Foundation

struct TraceScreenshotCapture: Equatable {
    let path: String
    let rectDescription: String

    static let none = TraceScreenshotCapture(path: "", rectDescription: "none")
}

struct TraceScreenshotCaptureCoordinator {
    typealias CaptureSink = (_ rect: CGRect, _ url: URL, _ bundleIdentifier: String) -> Void

    var policy: ScreenshotTraceCapturePolicy
    var screenshotFolderURL: () -> URL
    var globalScreenshotTracingEnabled: () -> Bool
    var captureSink: CaptureSink
    var maxScheduledScreenshotSuggestionIDs: Int

    private var scheduledScreenshotSuggestionIDs: Set<String> = []

    init(
        policy: ScreenshotTraceCapturePolicy = ScreenshotTraceCapturePolicy(),
        screenshotFolderURL: @escaping () -> URL = { RawAutocompleteTraceLog.shared.screenshotFolderURL },
        globalScreenshotTracingEnabled: @escaping () -> Bool = {
            RawAutocompleteTraceLog.shared.screenshotTracingEnabled
        },
        captureSink: @escaping CaptureSink = { rect, url, bundleIdentifier in
            ScreenshotTraceCapture.shared.capture(
                rect: rect,
                to: url,
                bundleIdentifier: bundleIdentifier
            )
        },
        maxScheduledScreenshotSuggestionIDs: Int = 256
    ) {
        self.policy = policy
        self.screenshotFolderURL = screenshotFolderURL
        self.globalScreenshotTracingEnabled = globalScreenshotTracingEnabled
        self.captureSink = captureSink
        self.maxScheduledScreenshotSuggestionIDs = max(1, maxScheduledScreenshotSuggestionIDs)
    }

    mutating func capture(
        around rects: [CGRect],
        suggestionID: String,
        bundleIdentifier: String,
        triggerReason: String,
        appScreenshotTracingEnabled: Bool
    ) -> TraceScreenshotCapture {
        guard let captureRect = ScreenshotCaptureRegion.enclosing(rects) else {
            return .none
        }

        if scheduledScreenshotSuggestionIDs.count >= maxScheduledScreenshotSuggestionIDs {
            scheduledScreenshotSuggestionIDs.removeAll(keepingCapacity: true)
        }

        guard policy.shouldCapture(
            triggerReason: triggerReason,
            globalScreenshotTracingEnabled: globalScreenshotTracingEnabled(),
            appScreenshotTracingEnabled: appScreenshotTracingEnabled,
            hasCaptureRegion: true,
            hasAlreadyCapturedSuggestionID: scheduledScreenshotSuggestionIDs.contains(suggestionID)
        ) else {
            return .none
        }

        scheduledScreenshotSuggestionIDs.insert(suggestionID)
        let screenshotURL = screenshotFolderURL().appendingPathComponent("\(suggestionID).png")
        captureSink(captureRect, screenshotURL, bundleIdentifier)

        return TraceScreenshotCapture(
            path: screenshotURL.path,
            rectDescription: Self.compactRectDescription(captureRect)
        )
    }

    private static func compactRectDescription(_ rect: CGRect) -> String {
        "x=\(Int(rect.origin.x.rounded())),y=\(Int(rect.origin.y.rounded())),w=\(Int(rect.width.rounded())),h=\(Int(rect.height.rounded()))"
    }
}
