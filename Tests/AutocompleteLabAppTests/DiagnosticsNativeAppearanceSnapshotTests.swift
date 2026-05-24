import AppKit
import Foundation
import Testing
import AutocompleteLabCore
@testable import AutocompleteLabApp

@Suite("Diagnostics native appearance snapshots")
struct DiagnosticsNativeAppearanceSnapshotTests {
    @MainActor
    @Test("Diagnostics renders under light dark and high contrast appearances")
    func diagnosticsRendersUnderNativeAppearances() throws {
        _ = NSApplication.shared
        let controller = DiagnosticsWindowController()
        controller.show(
            diagnostics: nil,
            profile: CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit"),
            compatibilityStatus: CompatibilityProfileStore.mvp.supportStatus(for: "com.apple.TextEdit"),
            appEnabled: true,
            appTrusted: true,
            lastSuggestionDecision: "Shown",
            runtimeReport: RuntimeReadinessReport(
                stage: .ready,
                summary: "ready",
                action: .none,
                isReady: true
            ),
            runtimeTargetSummary: "Qwen local • short completions • normal",
            modelDirectoryPath: "/Users/example/Library/Application Support/SteadyType/Models",
            recentEvents: [
                "launch accessibility=true",
                "suggestion-panel-frame renderMode=inlineAdjacent",
                "typing-health keyCapture=idle axPolling=healthy"
            ],
            traceSummary: AutocompleteTraceSummary(
                totalEvents: 12,
                presentedCount: 6,
                acceptedCount: 3,
                typedThroughCount: 0,
                typedOverCount: 1,
                ignoredCount: 2,
                insertionFailureCount: 0,
                acceptRate: 0.5,
                usefulRate: 0.25,
                p50LatencyMilliseconds: 45,
                p90LatencyMilliseconds: 70,
                p95LatencyMilliseconds: 76,
                topMisses: []
            ),
            personalCaptureScorecard: nil,
            recentTraceEvents: [],
            tracePath: "/Users/example/Library/Logs/SteadyType/events.jsonl",
            tracingPaused: false,
            screenshotTracingEnabled: false,
            compatibilityLearningPath: "/Users/example/Library/Application Support/SteadyType/learning.json",
            compatibilityLearningProfile: nil,
            refreshAction: {},
            toggleTracingAction: {},
            toggleScreenshotTracingAction: {},
            openTraceFolderAction: {},
            exportReportAction: {},
            deleteTracesAction: {}
        )

        for appearanceName in NativeAppearanceCoverage.lightDarkAndHighContrast.appearanceNames {
            let name = NSAppearance.Name(appearanceName)
            let pngData = try #require(controller.nativeAppearanceSnapshotPNGData(appearanceName: name))
            #expect(pngData.count > 20_000)
            try writeSnapshotIfRequested(pngData, appearanceName: name)
        }
    }

    private func writeSnapshotIfRequested(
        _ pngData: Data,
        appearanceName: NSAppearance.Name
    ) throws {
        guard let outputDirectory = ProcessInfo.processInfo.environment[
            "AUTOCOMPLETE_LAB_NATIVE_VISUAL_QA_OUTPUT_DIR"
        ], !outputDirectory.isEmpty else {
            return
        }

        let directoryURL = URL(fileURLWithPath: outputDirectory, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let fileURL = directoryURL.appendingPathComponent("\(snapshotName(for: appearanceName)).png")
        try pngData.write(to: fileURL)
    }

    private func snapshotName(for appearanceName: NSAppearance.Name) -> String {
        switch appearanceName.rawValue {
        case NSAppearance.Name.aqua.rawValue:
            return "diagnostics-light"
        case NSAppearance.Name.darkAqua.rawValue:
            return "diagnostics-dark"
        case NSAppearance.Name.accessibilityHighContrastAqua.rawValue:
            return "diagnostics-high-contrast-light"
        case NSAppearance.Name.accessibilityHighContrastDarkAqua.rawValue:
            return "diagnostics-high-contrast-dark"
        default:
            return appearanceName.rawValue
                .replacingOccurrences(of: "NSAppearanceName", with: "diagnostics-")
                .lowercased()
        }
    }
}
