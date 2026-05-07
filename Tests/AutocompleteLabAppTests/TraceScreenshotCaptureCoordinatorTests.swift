import CoreGraphics
import Foundation
import Testing
@testable import AutocompleteLabApp
@testable import AutocompleteLabCore

@Suite("Trace screenshot capture coordinator")
struct TraceScreenshotCaptureCoordinatorTests {
    @Test("Captures an enclosing region when tracing is enabled")
    func capturesEnclosingRegionWhenTracingIsEnabled() {
        var captured: [(CGRect, URL, String)] = []
        var coordinator = TraceScreenshotCaptureCoordinator(
            screenshotFolderURL: { URL(fileURLWithPath: "/tmp/autocomplete-screens") },
            globalScreenshotTracingEnabled: { true },
            captureSink: { rect, url, bundleIdentifier in
                captured.append((rect, url, bundleIdentifier))
            }
        )

        let result = coordinator.capture(
            around: [
                CGRect(x: 10.2, y: 20.4, width: 30, height: 10),
                CGRect(x: 40, y: 12, width: 5, height: 18)
            ],
            suggestionID: "abc123",
            bundleIdentifier: "com.apple.TextEdit",
            triggerReason: "model-result",
            appScreenshotTracingEnabled: false
        )

        #expect(captured.count == 1)
        #expect(captured.first?.0 == CGRect(x: -14, y: -12, width: 83, height: 67))
        #expect(captured.first?.1.path == "/tmp/autocomplete-screens/abc123.png")
        #expect(captured.first?.2 == "com.apple.TextEdit")
        #expect(result.path == "/tmp/autocomplete-screens/abc123.png")
        #expect(result.rectDescription == "x=-14,y=-12,w=83,h=67")
    }

    @Test("Blocks missing opt in, empty region, and duplicate suggestion captures")
    func blocksMissingOptInEmptyRegionAndDuplicateSuggestionCaptures() {
        var capturedCount = 0
        var coordinator = TraceScreenshotCaptureCoordinator(
            screenshotFolderURL: { URL(fileURLWithPath: "/tmp/autocomplete-screens") },
            globalScreenshotTracingEnabled: { false },
            captureSink: { _, _, _ in capturedCount += 1 }
        )

        #expect(coordinator.capture(
            around: [CGRect(x: 1, y: 2, width: 3, height: 4)],
            suggestionID: "not-enabled",
            bundleIdentifier: "com.apple.TextEdit",
            triggerReason: "model-result",
            appScreenshotTracingEnabled: false
        ) == .none)
        #expect(coordinator.capture(
            around: [],
            suggestionID: "empty",
            bundleIdentifier: "com.apple.TextEdit",
            triggerReason: "model-result",
            appScreenshotTracingEnabled: true
        ) == .none)

        let first = coordinator.capture(
            around: [CGRect(x: 1, y: 2, width: 3, height: 4)],
            suggestionID: "same",
            bundleIdentifier: "com.apple.TextEdit",
            triggerReason: "model-result",
            appScreenshotTracingEnabled: true
        )
        let second = coordinator.capture(
            around: [CGRect(x: 1, y: 2, width: 3, height: 4)],
            suggestionID: "same",
            bundleIdentifier: "com.apple.TextEdit",
            triggerReason: "model-result",
            appScreenshotTracingEnabled: true
        )

        #expect(first != .none)
        #expect(second == .none)
        #expect(capturedCount == 1)
    }

    @Test("Resets duplicate guard when the scheduled set reaches its cap")
    func resetsDuplicateGuardWhenScheduledSetReachesCap() {
        var capturedIDs: [String] = []
        var coordinator = TraceScreenshotCaptureCoordinator(
            screenshotFolderURL: { URL(fileURLWithPath: "/tmp/autocomplete-screens") },
            globalScreenshotTracingEnabled: { true },
            captureSink: { _, url, _ in capturedIDs.append(url.deletingPathExtension().lastPathComponent) },
            maxScheduledScreenshotSuggestionIDs: 2
        )

        _ = coordinator.capture(
            around: [CGRect(x: 0, y: 0, width: 1, height: 1)],
            suggestionID: "one",
            bundleIdentifier: "com.apple.TextEdit",
            triggerReason: "model-result",
            appScreenshotTracingEnabled: false
        )
        _ = coordinator.capture(
            around: [CGRect(x: 0, y: 0, width: 1, height: 1)],
            suggestionID: "two",
            bundleIdentifier: "com.apple.TextEdit",
            triggerReason: "model-result",
            appScreenshotTracingEnabled: false
        )
        let repeatedAfterReset = coordinator.capture(
            around: [CGRect(x: 0, y: 0, width: 1, height: 1)],
            suggestionID: "one",
            bundleIdentifier: "com.apple.TextEdit",
            triggerReason: "model-result",
            appScreenshotTracingEnabled: false
        )

        #expect(repeatedAfterReset != .none)
        #expect(capturedIDs == ["one", "two", "one"])
    }
}
