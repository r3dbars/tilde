import CoreGraphics
import Foundation
import Testing
@testable import AutocompleteLabApp
@testable import AutocompleteLabCore

@Suite("Trace screenshot capture coordinator")
struct TraceScreenshotCaptureCoordinatorTests {
    @Test("Does not capture without a region")
    func doesNotCaptureWithoutRegion() {
        let captures = CaptureStore()
        let coordinator = makeCoordinator(
            globalScreenshotTracingEnabled: true,
            captures: captures
        )

        let result = coordinator.capture(request(rects: []))

        #expect(result == .none)
        #expect(captures.items.isEmpty)
    }

    @Test("Captures when global tracing is enabled")
    func capturesWhenGlobalTracingEnabled() throws {
        let captures = CaptureStore()
        let coordinator = makeCoordinator(
            globalScreenshotTracingEnabled: true,
            captures: captures
        )

        let result = coordinator.capture(request(
            rects: [CGRect(x: 10.2, y: 20.4, width: 30.1, height: 9.8)],
            suggestionID: "abc123",
            appScreenshotTracingEnabled: false
        ))

        #expect(result.path.hasSuffix("/abc123.png"))
        #expect(result.rectDescription == "x=-14,y=-4,w=79,h=59")
        let capture = try #require(captures.items.first)
        #expect(capture.rect == CGRect(x: -14, y: -4, width: 79, height: 59))
        #expect(capture.screenshotURL.lastPathComponent == "abc123.png")
        #expect(capture.bundleIdentifier == "com.example.Editor")
        #expect(capture.allowsLearningCorrection == false)
    }

    @Test("Captures when app tracing is enabled and allows correction")
    func capturesWhenAppTracingEnabledAndAllowsCorrection() throws {
        let captures = CaptureStore()
        let coordinator = makeCoordinator(
            globalScreenshotTracingEnabled: false,
            captures: captures
        )

        _ = coordinator.capture(request(
            rects: [CGRect(x: 0, y: 0, width: 10, height: 10)],
            appScreenshotTracingEnabled: true
        ))

        let capture = try #require(captures.items.first)
        #expect(capture.allowsLearningCorrection)
    }

    @Test("Does not capture the same suggestion twice")
    func doesNotCaptureSameSuggestionTwice() {
        let captures = CaptureStore()
        let coordinator = makeCoordinator(
            globalScreenshotTracingEnabled: true,
            captures: captures
        )
        let request = request(
            rects: [CGRect(x: 0, y: 0, width: 10, height: 10)],
            suggestionID: "same"
        )

        _ = coordinator.capture(request)
        let second = coordinator.capture(request)

        #expect(captures.items.count == 1)
        #expect(second == .none)
    }

    @Test("Resets dedupe cache at capacity")
    func resetsDedupeCacheAtCapacity() {
        let captures = CaptureStore()
        let coordinator = makeCoordinator(
            globalScreenshotTracingEnabled: true,
            maxScheduledSuggestionIDs: 1,
            captures: captures
        )

        _ = coordinator.capture(request(
            rects: [CGRect(x: 0, y: 0, width: 10, height: 10)],
            suggestionID: "one"
        ))
        _ = coordinator.capture(request(
            rects: [CGRect(x: 0, y: 0, width: 10, height: 10)],
            suggestionID: "two"
        ))
        _ = coordinator.capture(request(
            rects: [CGRect(x: 0, y: 0, width: 10, height: 10)],
            suggestionID: "one"
        ))

        #expect(captures.items.map(\.screenshotURL.lastPathComponent) == [
            "one.png",
            "two.png",
            "one.png"
        ])
    }

    @Test("Builds expected signal rect from panel rect")
    func buildsExpectedSignalRectFromPanelRect() {
        let captures = CaptureStore()
        let coordinator = makeCoordinator(captures: captures)

        let normal = coordinator.expectedSignalRect(
            panelRect: CGRect(x: 20, y: 30, width: 100, height: 18)
        )
        let narrow = coordinator.expectedSignalRect(
            panelRect: CGRect(x: 20, y: 30, width: 4, height: 4)
        )

        #expect(normal == CGRect(x: 20, y: 30, width: 36, height: 18))
        #expect(narrow == CGRect(x: 20, y: 30, width: 4, height: 4))
    }

    private func makeCoordinator(
        globalScreenshotTracingEnabled: Bool = true,
        maxScheduledSuggestionIDs: Int = 256,
        captures: CaptureStore
    ) -> TraceScreenshotCaptureCoordinator {
        TraceScreenshotCaptureCoordinator(
            maxScheduledSuggestionIDs: maxScheduledSuggestionIDs,
            screenshotFolderURL: { URL(fileURLWithPath: "/tmp/screenshots") },
            globalScreenshotTracingEnabled: { globalScreenshotTracingEnabled },
            captureHandler: { rect, screenshotURL, bundleIdentifier, expectedSignalRect, visualTrustContext, allowsLearningCorrection in
                captures.items.append(Capture(
                    rect: rect,
                    screenshotURL: screenshotURL,
                    bundleIdentifier: bundleIdentifier,
                    expectedSignalRect: expectedSignalRect,
                    visualTrustContext: visualTrustContext,
                    allowsLearningCorrection: allowsLearningCorrection
                ))
            }
        )
    }

    private func request(
        rects: [CGRect],
        suggestionID: String = "suggestion",
        appScreenshotTracingEnabled: Bool = false
    ) -> TraceScreenshotCaptureRequest {
        TraceScreenshotCaptureRequest(
            rects: rects,
            expectedSignalRect: CGRect(x: 1, y: 2, width: 3, height: 4),
            suggestionID: suggestionID,
            bundleIdentifier: "com.example.Editor",
            triggerReason: "model-result",
            appScreenshotTracingEnabled: appScreenshotTracingEnabled,
            visualTrustContext: nil
        )
    }
}

private final class CaptureStore {
    var items: [Capture] = []
}

private struct Capture {
    let rect: CGRect
    let screenshotURL: URL
    let bundleIdentifier: String
    let expectedSignalRect: CGRect?
    let visualTrustContext: CompatibilityLearningVisualTrustContext?
    let allowsLearningCorrection: Bool
}
