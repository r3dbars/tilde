import Foundation
import Testing
import AutocompleteLabCore
@testable import AutocompleteLabApp

@Suite("Diagnostics window state")
struct DiagnosticsWindowControllerStateTests {
    @Test("Overview renders short inspector rows without suggestion text")
    func overviewRendersShortInspectorRowsWithoutSuggestionText() {
        let overview = DiagnosticsOverviewState(
            appTrusted: true,
            appEnabled: false,
            lastSuggestionDecision: "Shown: private phrase should never appear",
            runtimeReport: RuntimeReadinessReport(
                stage: .ready,
                summary: "ready",
                action: .none,
                isReady: true
            ),
            runtimeTargetSummary: "MLX local model",
            pauseControl: ControlPauseState(isPaused: false, pausedUntil: nil),
            compatibilityStatus: .unsupported,
            diagnostics: nil,
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
                p50LatencyMilliseconds: nil,
                p90LatencyMilliseconds: nil,
                p95LatencyMilliseconds: nil,
                topMisses: []
            ),
            tracingPaused: false,
            screenshotTracingEnabled: true
        )

        let lines = overview.text.split(separator: "\n").map(String.init)
        #expect(lines.count == 9)
        #expect(overview.text.contains("Status"))
        #expect(overview.text.contains("Suggestions: shown"))
        #expect(overview.text.contains("Why now: Shown"))
        #expect(overview.text.contains("Next action: Open TextEdit or another supported writing app"))
        #expect(overview.text.contains("Accessibility: On"))
        #expect(overview.text.contains("Suggestion pause: off"))
        #expect(overview.text.contains("Local model: ready"))
        #expect(overview.text.contains("Current app: No focused app | unsupported: no compatibility profile | disabled"))
        #expect(overview.text.contains("Local recording: recording on | placement screenshots on | events 12 | accept 50% | useful 25%"))
        #expect(!overview.text.contains("private phrase"))
        #expect(lines.allSatisfy { $0.count <= 160 })
    }

    @Test("Personal Capture loop diagnostics expose score without raw text")
    func personalCaptureLoopDiagnosticsExposeScoreWithoutRawText() {
        var record = SuggestionEpisodeRecord(
            id: "episode-1",
            createdAt: "2026-05-24T12:00:00Z",
            appDisplayName: "TextEdit",
            appBundleIdentifier: "com.apple.TextEdit",
            fieldIdentity: "field",
            fieldKind: "plain",
            fieldKindReason: "safe",
            requestMode: "wordCompletion",
            userTypedContext: "private before text",
            suggestedText: "private suggestion",
            acceptedText: "private accepted text",
            model: SuggestionEpisodeModelContext(
                modelName: "local-test",
                runtime: "mlx",
                asset: "asset",
                promptVersion: "prompt-v1",
                experimentArm: "arm-a",
                triggerReason: "typing",
                candidateSource: "model",
                latencyMilliseconds: 120
            ),
            placement: SuggestionEpisodePlacementContext(renderMode: "inlineAdjacent")
        )
        record.appendAction(.accepted, timestamp: "2026-05-24T12:00:01Z")
        record.appendSurvivalCheckpoint(SuggestionEpisodeSurvivalCheckpoint(
            checkpoint: "30s",
            survivalClass: AcceptanceSurvivalClass.exactKept.rawValue,
            timestamp: "2026-05-24T12:00:30Z"
        ))

        let diagnostics = PersonalCaptureLoopDiagnostics(
            scorecard: SuggestionEpisodeScorecard(records: [record])
        )

        #expect(diagnostics.text.contains("Personal Capture loop:"))
        #expect(diagnostics.text.contains("score:"))
        #expect(diagnostics.text.contains("episodes: 1"))
        #expect(diagnostics.text.contains("accepted: 1"))
        #expect(diagnostics.text.contains("kept: 1"))
        #expect(diagnostics.text.contains("eval cases: 1"))
        #expect(diagnostics.text.contains("average latency: 120ms"))
        #expect(diagnostics.text.contains("local-test / prompt-v1"))
        #expect(!diagnostics.text.contains("private before text"))
        #expect(!diagnostics.text.contains("private suggestion"))
        #expect(!diagnostics.text.contains("private accepted text"))
    }

    @Test("Placement diagnostics expose confidence without suggestion text")
    func placementDiagnosticsExposeConfidenceWithoutSuggestionText() {
        let diagnostics = PlacementDiagnostics(
            summary: AutocompleteTraceSummary(
                totalEvents: 8,
                presentedCount: 3,
                acceptedCount: 1,
                typedThroughCount: 0,
                typedOverCount: 0,
                ignoredCount: 0,
                insertionFailureCount: 0,
                caretGeometryFailureCount: 2,
                caretGeometryFailureRate: 0.4,
                caretGeometryFailuresByApp: ["com.apple.TextEdit": 1, "md.obsidian": 1],
                caretGeometryFailureRateByApp: ["com.apple.TextEdit": 0.25, "md.obsidian": 0.5],
                caretGeometryFailuresByRenderMode: ["inlineAdjacent": 2],
                caretGeometryFailureRateByRenderMode: ["inlineAdjacent": 0.67],
                acceptRate: 0.33,
                usefulRate: 0.33,
                p50LatencyMilliseconds: nil,
                p90LatencyMilliseconds: nil,
                p95LatencyMilliseconds: nil,
                anchorQualityByApp: [
                    "com.apple.TextEdit": ["valid": 3, "invalid": 1],
                    "md.obsidian": ["synthetic": 2]
                ],
                topMisses: []
            ),
            recentEvents: [
                event(
                    metadata: [
                        "placementRequestedRenderMode": "inlineAdjacent",
                        "placementEffectiveRenderMode": "inlineAdjacent",
                        "placementAnchorSource": "caret",
                        "placementHealthReason": "healthy",
                        "placementSelfHealingApplied": "false",
                        "placementSelfHealingAction": "none",
                        "placementConfidenceScore": "1.00",
                        "placementConfidenceBand": "high",
                        "clippingRect": "x=10,y=20,w=300,h=40",
                        "screenshotCaptured": "true"
                    ],
                    type: .suggestionPresented,
                    appBundleIdentifier: "com.apple.TextEdit",
                    displayedText: "private words"
                ),
                event(
                    metadata: [
                        "placementRequestedRenderMode": "inlineAdjacent",
                        "placementEffectiveRenderMode": "floatingMirror",
                        "placementAnchorSource": "synthetic-caret",
                        "placementHealthReason": "missing-caret",
                        "placementSelfHealingApplied": "true",
                        "placementSelfHealingAction": "fallback-floating-mirror",
                        "placementConfidenceScore": "0.40",
                        "placementConfidenceBand": "low",
                        "clippingRect": "x=10,y=20,w=300,h=40",
                        "screenshotCaptured": "true"
                    ],
                    type: .suggestionPresented,
                    appBundleIdentifier: "md.obsidian",
                    displayedText: "more private words"
                ),
                event(
                    metadata: [
                        "placementRequestedRenderMode": "inlineAdjacent",
                        "placementSelfHealingAction": "suppress",
                        "placementConfidenceScore": "0.00",
                        "placementConfidenceBand": "none",
                        "placementClipped": "false"
                    ],
                    type: .suggestionSuppressed,
                    appBundleIdentifier: "md.obsidian",
                    displayedText: "suppressed private words"
                )
            ]
        )

        #expect(diagnostics.text.contains("Placement diagnostics: caret failures 2 (40%), recent placement events 3"))
        #expect(diagnostics.text.contains("confidence=0.00 (none)"))
        #expect(diagnostics.text.contains("render=inlineAdjacent->unknown"))
        #expect(diagnostics.text.contains("selfHealing=unknown/suppress"))
        #expect(diagnostics.text.contains("clipping=false"))
        #expect(diagnostics.text.contains("screenshot=false"))
        #expect(diagnostics.text.contains("Recent confidence bands:"))
        #expect(diagnostics.text.contains("low: 1"))
        #expect(diagnostics.text.contains("none: 1"))
        #expect(diagnostics.text.contains("Placement self-healing actions:"))
        #expect(diagnostics.text.contains("fallback-floating-mirror: 1"))
        #expect(diagnostics.text.contains("suppress: 1"))
        #expect(diagnostics.text.contains("inlineAdjacent->floatingMirror: 1"))
        #expect(diagnostics.text.contains("com.apple.TextEdit: valid=3, invalid=1"))
        #expect(diagnostics.text.contains("com.apple.TextEdit: 1 (25%)"))
        #expect(diagnostics.text.contains("inlineAdjacent: 2 (67%)"))
        #expect(!diagnostics.text.contains("private words"))
    }

    @Test("Placement diagnostics stay useful before placement data exists")
    func placementDiagnosticsStayUsefulBeforePlacementDataExists() {
        let diagnostics = PlacementDiagnostics(
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

        #expect(diagnostics.text.contains("Placement diagnostics: caret failures 0 (0%), recent placement events 0"))
        #expect(diagnostics.text.contains("Current placement: no recent placement metadata"))
        #expect(diagnostics.text.contains("Recent confidence bands: none yet"))
        #expect(diagnostics.text.contains("Placement self-healing actions: none yet"))
        #expect(diagnostics.text.contains("Render mode transitions: none yet"))
        #expect(diagnostics.text.contains("Anchor quality by app: none yet"))
        #expect(diagnostics.text.contains("Caret failures by app: none yet"))
    }

    @Test("Prompt context diagnostics expose shape without raw text")
    func promptContextDiagnosticsExposeShapeWithoutRawText() {
        let diagnostics = PromptContextDiagnostics(
            recentEvents: [
                event(metadata: [
                    "documentTitleWordCount": "3",
                    "documentTitleLengthBucket": "short",
                    "documentTitleExtension": "md",
                    "documentTitleIsUntitled": "false",
                    "documentTitleHasUnsavedMarker": "true"
                ]),
                event(metadata: [
                    "partialWordCharacters": "9",
                    "partialWordLetters": "9",
                    "partialWordDigits": "0",
                    "partialWordCasing": "titlecase",
                    "partialWordHasHyphen": "false",
                    "partialWordHasApostrophe": "false"
                ]),
                event(
                    metadata: [
                        "currentLineStructure": "checklist_unchecked",
                        "currentLineMarkerStyle": "dash",
                        "currentLineIndentationColumns": "2",
                        "currentLineContentWords": "4"
                    ],
                    displayedText: "Launch Plan"
                ),
                event(
                    metadata: [
                        "visiblePageContextActiveLineFiltered": "true"
                    ],
                    displayedText: "Launch Plan"
                )
            ]
        )

        #expect(diagnostics.text.contains("Prompt context diagnostics: recent shape events 3"))
        #expect(diagnostics.text.contains("Document title shape: length=short, words=3, extension=md, untitled=false, unsaved=true"))
        #expect(diagnostics.text.contains("Partial word shape: chars=9, letters=9, digits=0, casing=titlecase, hyphen=false, apostrophe=false"))
        #expect(diagnostics.text.contains("Current line shape: kind=checklist_unchecked, marker=dash, indent=2, contentWords=4"))
        #expect(diagnostics.text.contains("Screen context active-line filter: removed active typed line"))
        #expect(!diagnostics.text.contains("Launch"))
        #expect(!diagnostics.text.contains("Plan"))
    }

    @Test("Prompt context diagnostics report no OCR active line filtering without raw text")
    func promptContextDiagnosticsReportNoOCRActiveLineFilteringWithoutRawText() {
        let diagnostics = PromptContextDiagnostics(
            recentEvents: [
                event(
                    metadata: [
                        "visiblePageContextActiveLineFiltered": "false"
                    ],
                    displayedText: "Private draft sentence"
                )
            ]
        )

        #expect(diagnostics.text.contains("Screen context active-line filter: no active line removed"))
        #expect(!diagnostics.text.contains("Private"))
        #expect(!diagnostics.text.contains("draft"))
        #expect(!diagnostics.text.contains("sentence"))
    }

    @Test("Prompt context diagnostics stay useful before shape data exists")
    func promptContextDiagnosticsStayUsefulBeforeShapeDataExists() {
        let diagnostics = PromptContextDiagnostics(recentEvents: [])

        #expect(diagnostics.text.contains("Prompt context diagnostics: recent shape events 0"))
        #expect(diagnostics.text.contains("Document title shape: no recent title-shape metadata"))
        #expect(diagnostics.text.contains("Partial word shape: no recent partial-word metadata"))
        #expect(diagnostics.text.contains("Current line shape: no recent line-shape metadata"))
        #expect(diagnostics.text.contains("Screen context active-line filter: no recent OCR context metadata"))
    }

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
                    "prefixCooldownEscalated": "true",
                    "prefixFamilyHMACToken": "abc123def456abc123def456"
                ]),
                event(metadata: [
                    "quietMode": "field",
                    "annoyanceSignal": "caretGeometryFailed",
                    "quietReason": "caretGeometryFailed",
                    "quietScore": "0.600",
                    "quietUntil": "2026-05-07T00:15:00Z"
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
        #expect(diagnostics.text.contains("scope=field, signal=caretGeometryFailed, reason=caretGeometryFailed, score=0.600, until=2026-05-07T00:15:00Z"))
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
        #expect(diagnostics.text.contains("Quiet mode: no recent quiet-mode metadata"))
        #expect(diagnostics.text.contains("Repeated miss state: no recent miss-score metadata"))
        #expect(diagnostics.text.contains("Prefix cooldown: no recent cooldown metadata"))
        #expect(diagnostics.text.contains("Style sketch: no recent aggregate style metadata"))
    }

    private func event(
        metadata: [String: String],
        type: AutocompleteTraceEventType = .suggestionSuppressed,
        appBundleIdentifier: String = "",
        displayedText: String = ""
    ) -> AutocompleteTraceEvent {
        AutocompleteTraceEvent(
            timestamp: "2026-05-07T00:00:00Z",
            sessionID: "session",
            suggestionID: UUID().uuidString,
            type: type,
            appBundleIdentifier: appBundleIdentifier,
            displayedText: displayedText,
            metadata: metadata
        )
    }
}
