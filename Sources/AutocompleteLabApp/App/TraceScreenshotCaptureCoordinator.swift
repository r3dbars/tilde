import CoreGraphics
import Foundation
import AutocompleteLabCore

struct TraceScreenshotCaptureResult: Equatable {
    let path: String
    let rectDescription: String
    let screenshotPathAuthorized: Bool

    init(
        path: String,
        rectDescription: String,
        screenshotPathAuthorized: Bool = false
    ) {
        self.path = path
        self.rectDescription = rectDescription
        self.screenshotPathAuthorized = screenshotPathAuthorized
    }

    static let none = TraceScreenshotCaptureResult(
        path: "",
        rectDescription: "none",
        screenshotPathAuthorized: false
    )
}

struct TraceScreenshotCaptureRequest {
    let rects: [CGRect]
    let expectedSignalRect: CGRect?
    let suggestionID: String
    let bundleIdentifier: String
    let triggerReason: String
    let appScreenshotTracingEnabled: Bool
    let visualTrustContext: CompatibilityLearningVisualTrustContext?
}

final class TraceScreenshotCaptureCoordinator {
    typealias CaptureHandler = (
        _ rect: CGRect,
        _ screenshotURL: URL,
        _ bundleIdentifier: String,
        _ expectedSignalRect: CGRect?,
        _ visualTrustContext: CompatibilityLearningVisualTrustContext?,
        _ allowsLearningCorrection: Bool
    ) -> Void

    private let policy: ScreenshotTraceCapturePolicy
    private let screenshotFolderURL: () -> URL
    private let globalScreenshotTracingEnabled: () -> Bool
    private let captureHandler: CaptureHandler
    private let maxScheduledSuggestionIDs: Int
    private var scheduledSuggestionIDs: Set<String> = []

    init(
        policy: ScreenshotTraceCapturePolicy = ScreenshotTraceCapturePolicy(),
        maxScheduledSuggestionIDs: Int = 256,
        screenshotFolderURL: @escaping () -> URL = {
            RawAutocompleteTraceLog.shared.screenshotFolderURL
        },
        globalScreenshotTracingEnabled: @escaping () -> Bool = {
            RawAutocompleteTraceLog.shared.screenshotTracingEnabled
        },
        captureHandler: @escaping CaptureHandler = { rect, screenshotURL, bundleIdentifier, expectedSignalRect, visualTrustContext, allowsLearningCorrection in
            ScreenshotTraceCapture.shared.capture(
                rect: rect,
                to: screenshotURL,
                bundleIdentifier: bundleIdentifier,
                expectedSignalRect: expectedSignalRect,
                visualTrustContext: visualTrustContext,
                allowsLearningCorrection: allowsLearningCorrection
            )
        }
    ) {
        self.policy = policy
        self.maxScheduledSuggestionIDs = max(1, maxScheduledSuggestionIDs)
        self.screenshotFolderURL = screenshotFolderURL
        self.globalScreenshotTracingEnabled = globalScreenshotTracingEnabled
        self.captureHandler = captureHandler
    }

    func expectedSignalRect(panelRect: CGRect) -> CGRect {
        CGRect(
            x: panelRect.minX,
            y: panelRect.minY,
            width: min(max(panelRect.width, 1), max(12, panelRect.height * 2)),
            height: max(panelRect.height, 1)
        )
    }

    func capture(_ request: TraceScreenshotCaptureRequest) -> TraceScreenshotCaptureResult {
        guard let captureRect = ScreenshotCaptureRegion.enclosing(request.rects) else {
            return .none
        }

        if scheduledSuggestionIDs.count >= maxScheduledSuggestionIDs {
            scheduledSuggestionIDs.removeAll(keepingCapacity: true)
        }

        guard policy.shouldCapture(
            triggerReason: request.triggerReason,
            globalScreenshotTracingEnabled: globalScreenshotTracingEnabled(),
            appScreenshotTracingEnabled: request.appScreenshotTracingEnabled,
            hasCaptureRegion: true,
            hasAlreadyCapturedSuggestionID: scheduledSuggestionIDs.contains(request.suggestionID)
        ) else {
            return .none
        }
        scheduledSuggestionIDs.insert(request.suggestionID)

        let screenshotURL = screenshotFolderURL()
            .appendingPathComponent("\(request.suggestionID).png")
        captureHandler(
            captureRect,
            screenshotURL,
            request.bundleIdentifier,
            request.expectedSignalRect,
            request.visualTrustContext,
            request.appScreenshotTracingEnabled
        )

        return TraceScreenshotCaptureResult(
            path: screenshotURL.path,
            rectDescription: Self.compactRectDescription(captureRect),
            screenshotPathAuthorized: true
        )
    }

    private static func compactRectDescription(_ rect: CGRect) -> String {
        "x=\(Int(rect.origin.x.rounded())),y=\(Int(rect.origin.y.rounded())),w=\(Int(rect.width.rounded())),h=\(Int(rect.height.rounded()))"
    }
}
