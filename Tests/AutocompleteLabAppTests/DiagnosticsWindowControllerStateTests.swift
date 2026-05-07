import Foundation
import Testing
import AutocompleteLabCore
@testable import AutocompleteLabApp

@Suite("Diagnostics window state")
struct DiagnosticsWindowControllerStateTests {
    @Test("Learning diagnostics expose kept annoyance and miss state")
    func learningDiagnosticsExposeKeptAnnoyanceAndMissState() {
        let diagnostics = SuggestionLearningDiagnostics(
            summary: AutocompleteTraceSummary(
                totalEvents: 8,
                presentedCount: 4,
                acceptedCount: 2,
                typedThroughCount: 0,
                typedOverCount: 1,
                ignoredCount: 1,
                insertionFailureCount: 0,
                acceptedAndKeptCount: 1,
                acceptedAndKeptRateAccepted: 0.5,
                acceptedAndKeptRateShown: 0.25,
                annoyanceScore: 0.33,
                annoyanceSignalCounts: ["rapidEscDismissal": 1, "typedOverWithinOneSecond": 2],
                acceptRate: 0.5,
                usefulRate: 0.25,
                p50LatencyMilliseconds: nil,
                p90LatencyMilliseconds: nil,
                p95LatencyMilliseconds: nil,
                acceptedAndKeptRateByApp: ["com.apple.TextEdit": 1.0],
                acceptedAndKeptRateByRequestMode: ["phraseContinuation": 0.5],
                topMisses: []
            ),
            recentEvents: [
                event(metadata: [
                    "displayScoreAcceptedAndKeptProbability": "0.82",
                    "displayScoreAcceptedAndKeptSamples": "7",
                    "displayScoreAcceptedAndKeptThreshold": "0.60"
                ]),
                event(metadata: [
                    "repetitionMissKind": "ignored",
                    "repetitionMissTotal": "1.25",
                    "repetitionMissThreshold": "2.00",
                    "repetitionMissSuppressed": "false",
                    "repetitionMissLifetimeMs": "840"
                ]),
                event(metadata: [
                    "prefixCooldownReason": "escapeDismissal",
                    "prefixCooldownDurationMilliseconds": "60000",
                    "prefixFamilyTokenCount": "3",
                    "prefixCooldownEscalated": "true"
                ]),
                event(metadata: [
                    "styleSketchSamples": "4",
                    "styleSketchAverageWords": "2.50",
                    "styleSketchTerminalPunctuationRate": "0.75",
                    "styleSketchLowercaseStartRate": "0.25",
                    "styleSketchQuestionEndingRate": "0.00"
                ])
            ]
        )

        #expect(diagnostics.text.contains("accepted-kept 1 (50% of accepted, 25% of shown)"))
        #expect(diagnostics.text.contains("com.apple.TextEdit: 100%"))
        #expect(diagnostics.text.contains("phraseContinuation: 50%"))
        #expect(diagnostics.text.contains("typedOverWithinOneSecond: 2"))
        #expect(diagnostics.text.contains("probability=0.82, samples=7, threshold=0.60"))
        #expect(diagnostics.text.contains("score=1.25/2.00, suppressed=false, lifetime=840ms"))
        #expect(diagnostics.text.contains("duration=60000ms, familyTokens=3, escalated=true"))
        #expect(diagnostics.text.contains("samples=4, avgWords=2.50"))
    }

    @Test("Learning diagnostics stay useful before learning data exists")
    func learningDiagnosticsStayUsefulBeforeLearningDataExists() {
        let diagnostics = SuggestionLearningDiagnostics(
            summary: AutocompleteTraceSummary(
                totalEvents: 0,
                presentedCount: 0,
                acceptedCount: 0,
                typedThroughCount: 0,
                typedOverCount: 0,
                ignoredCount: 0,
                insertionFailureCount: 0,
                acceptRate: 0,
                usefulRate: 0,
                p50LatencyMilliseconds: nil,
                p90LatencyMilliseconds: nil,
                p95LatencyMilliseconds: nil,
                topMisses: []
            ),
            recentEvents: []
        )

        #expect(diagnostics.text.contains("Accepted-kept by app: none yet"))
        #expect(diagnostics.text.contains("Annoyance signals: none yet"))
        #expect(diagnostics.text.contains("Repeated miss state: no recent miss-score metadata"))
        #expect(diagnostics.text.contains("Prefix cooldown: no recent cooldown metadata"))
        #expect(diagnostics.text.contains("Style sketch: no recent aggregate style metadata"))
    }

    private func event(metadata: [String: String]) -> AutocompleteTraceEvent {
        AutocompleteTraceEvent(
            timestamp: "2026-05-07T00:00:00Z",
            sessionID: "session",
            suggestionID: UUID().uuidString,
            type: .suggestionSuppressed,
            metadata: metadata
        )
    }
}
