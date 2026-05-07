import Testing
@testable import AutocompleteLabCore

@Suite("Screenshot trace capture policy")
struct ScreenshotTraceCapturePolicyTests {
    @Test("Allows first model stream capture when screenshot tracing is explicit")
    func allowsFirstModelStreamCaptureWhenExplicitlyEnabled() {
        let policy = ScreenshotTraceCapturePolicy()

        #expect(policy.shouldCapture(
            triggerReason: "model-stream",
            globalScreenshotTracingEnabled: true,
            appScreenshotTracingEnabled: false,
            hasCaptureRegion: true,
            hasAlreadyCapturedSuggestionID: false
        ))
        #expect(policy.shouldCapture(
            triggerReason: "model-stream",
            globalScreenshotTracingEnabled: false,
            appScreenshotTracingEnabled: true,
            hasCaptureRegion: true,
            hasAlreadyCapturedSuggestionID: false
        ))
    }

    @Test("Blocks screenshots without opt-in, region, or first suggestion presentation")
    func blocksMissingOptInRegionOrFirstPresentation() {
        let policy = ScreenshotTraceCapturePolicy()

        #expect(!policy.shouldCapture(
            triggerReason: "model-stream",
            globalScreenshotTracingEnabled: false,
            appScreenshotTracingEnabled: false,
            hasCaptureRegion: true,
            hasAlreadyCapturedSuggestionID: false
        ))
        #expect(!policy.shouldCapture(
            triggerReason: "model-stream",
            globalScreenshotTracingEnabled: true,
            appScreenshotTracingEnabled: false,
            hasCaptureRegion: false,
            hasAlreadyCapturedSuggestionID: false
        ))
        #expect(!policy.shouldCapture(
            triggerReason: "model-result",
            globalScreenshotTracingEnabled: true,
            appScreenshotTracingEnabled: false,
            hasCaptureRegion: true,
            hasAlreadyCapturedSuggestionID: true
        ))
    }
}
