import Testing
@testable import AutocompleteLabCore

@Suite("Autocomplete trace replay")
struct AutocompleteTraceReplayTests {
    @Test("Complete replay proof covers trigger display survival latency and annoyance")
    func completeReplayProofPasses() {
        let events = [
            event(
                .suggestionRequested,
                suggestionID: "one",
                requestMode: CompletionRequestMode.phraseContinuation.rawValue,
                metadata: ["delayMilliseconds": "180"]
            ),
            event(
                .modelResult,
                suggestionID: "one",
                requestMode: CompletionRequestMode.phraseContinuation.rawValue,
                metadata: candidateSelectionMetadata()
            ),
            event(
                .suggestionPresented,
                suggestionID: "one",
                requestMode: CompletionRequestMode.phraseContinuation.rawValue,
                latencyMilliseconds: 220,
                metadata: displayMetadata(decision: "display")
            ),
            event(
                .suggestionAccepted,
                suggestionID: "one",
                requestMode: CompletionRequestMode.phraseContinuation.rawValue,
                outcome: "acceptNextWord",
                metadata: ["acceptanceID": "accept-one", "acceptMode": "tab"]
            ),
            event(
                .acceptedTextEdited,
                suggestionID: "one",
                requestMode: CompletionRequestMode.phraseContinuation.rawValue,
                metadata: [
                    "acceptanceID": "accept-one",
                    "checkpoint": AcceptanceSurvivalCheckpoint.thirtySeconds.rawValue,
                    "survivalClass": AcceptanceSurvivalClass.exactKept.rawValue,
                    "finishReason": "thirty-second-finalized"
                ]
            ),
            event(
                .suggestionHidden,
                suggestionID: "one",
                requestMode: CompletionRequestMode.phraseContinuation.rawValue,
                outcome: "ignored",
                reason: "escape",
                metadata: ["lifetimeMs": "90"]
            )
        ]

        let report = AutocompleteTraceReplay().report(for: events)

        #expect(report.passesReplayProofGate)
        #expect(report.triggerDelayCoverageRate == 1)
        #expect(report.displayScoreCoverageRate == 1)
        #expect(report.candidateSelectionCoverageRate == 1)
        #expect(report.proofFingerprintCoverageRate == 1)
        #expect(report.placementCoverageRate == 1)
        #expect(report.trustedPlacementCount == 1)
        #expect(report.keptFinalHorizonEventCount == 1)
        #expect(report.latencyByApp.first?.p50Milliseconds == 220)
        #expect(report.latencyByMode.first?.key == CompletionRequestMode.phraseContinuation.rawValue)
        #expect(report.annoyanceSignalCounts["rapidEscDismissal"] == 1)
        #expect(report.markdown.contains("trigger delay coverage: 100%"))
    }

    @Test("Missing display score metadata fails replay proof")
    func missingDisplayScoreFailsReplayProof() {
        let events = [
            event(
                .suggestionRequested,
                suggestionID: "one",
                metadata: ["delayMilliseconds": "180"]
            ),
            event(
                .suggestionPresented,
                suggestionID: "one",
                latencyMilliseconds: 180
            ),
            event(
                .acceptedTextEdited,
                suggestionID: "one",
                metadata: [
                    "checkpoint": AcceptanceSurvivalCheckpoint.fieldBlur.rawValue,
                    "survivalClass": AcceptanceSurvivalClass.exactKept.rawValue
                ]
            )
        ]

        let report = AutocompleteTraceReplay().report(for: events)

        #expect(!report.passesReplayProofGate)
        #expect(report.displayScoreCoverageRate == 0)
        #expect(report.requirements.contains {
            $0.name == "display scoring replay" && !$0.passed
        })
    }

    @Test("Replay proof supports redacted text traces")
    func replayProofSupportsRedactedTextTraces() {
        let events = [
            event(
                .suggestionRequested,
                suggestionID: "one",
                requestMode: CompletionRequestMode.wordCompletion.rawValue,
                textBeforeCursor: "[redacted length=42]",
                metadata: ["delayMilliseconds": "120"]
            ),
            event(
                .modelResult,
                suggestionID: "one",
                requestMode: CompletionRequestMode.wordCompletion.rawValue,
                textBeforeCursor: "[redacted length=42]",
                metadata: candidateSelectionMetadata(
                    cleanedCandidateCount: "1",
                    topScore: "0.950",
                    scoreMargin: "none",
                    suppressionReason: "none"
                )
            ),
            event(
                .suggestionPresented,
                suggestionID: "one",
                requestMode: CompletionRequestMode.wordCompletion.rawValue,
                textBeforeCursor: "[redacted length=42]",
                latencyMilliseconds: 90,
                metadata: displayMetadata(decision: "display")
            ),
            event(
                .acceptedTextEdited,
                suggestionID: "one",
                requestMode: CompletionRequestMode.wordCompletion.rawValue,
                metadata: [
                    "checkpoint": AcceptanceSurvivalCheckpoint.fieldSend.rawValue,
                    "survivalClass": AcceptanceSurvivalClass.lightlyEditedKept.rawValue
                ]
            )
        ]

        let report = AutocompleteTraceReplay().report(for: events)

        #expect(report.passesReplayProofGate)
        #expect(report.requirements.contains {
            $0.name == "redacted trace compatible" && $0.passed
        })
    }

    @Test("Missing candidate selection metadata fails replay proof")
    func missingCandidateSelectionMetadataFailsReplayProof() {
        let events = [
            event(
                .suggestionRequested,
                suggestionID: "one",
                metadata: ["delayMilliseconds": "180"]
            ),
            event(
                .modelResult,
                suggestionID: "one",
                metadata: ["cleanedCandidateCount": "2"]
            ),
            event(
                .suggestionPresented,
                suggestionID: "one",
                latencyMilliseconds: 180,
                metadata: displayMetadata(decision: "display")
            ),
            event(
                .acceptedTextEdited,
                suggestionID: "one",
                metadata: [
                    "checkpoint": AcceptanceSurvivalCheckpoint.thirtySeconds.rawValue,
                    "survivalClass": AcceptanceSurvivalClass.exactKept.rawValue
                ]
            )
        ]

        let report = AutocompleteTraceReplay().report(for: events)

        #expect(!report.passesReplayProofGate)
        #expect(report.candidateSelectionCoverageRate == 0)
        #expect(report.requirements.contains {
            $0.name == "candidate selection replay" && !$0.passed
        })
    }

    @Test("Missing proof fingerprint metadata fails replay proof")
    func missingProofFingerprintMetadataFailsReplayProof() {
        let events = [
            event(
                .suggestionRequested,
                suggestionID: "one",
                metadata: ["delayMilliseconds": "180"],
                includeProofMetadata: false
            ),
            event(
                .modelResult,
                suggestionID: "one",
                metadata: candidateSelectionMetadata(),
                includeProofMetadata: false
            ),
            event(
                .suggestionPresented,
                suggestionID: "one",
                latencyMilliseconds: 180,
                metadata: displayMetadata(decision: "display"),
                includeProofMetadata: false
            ),
            event(
                .acceptedTextEdited,
                suggestionID: "one",
                metadata: [
                    "checkpoint": AcceptanceSurvivalCheckpoint.thirtySeconds.rawValue,
                    "survivalClass": AcceptanceSurvivalClass.exactKept.rawValue
                ],
                includeProofMetadata: false
            )
        ]

        let report = AutocompleteTraceReplay().report(for: events)

        #expect(!report.passesReplayProofGate)
        #expect(report.proofFingerprintCoverageRate == 0)
        #expect(report.requirements.contains {
            $0.name == "proof fingerprint freshness" && !$0.passed
        })
    }

    @Test("Stale proof fingerprint metadata fails replay proof")
    func staleProofFingerprintMetadataFailsReplayProof() {
        let events = [
            event(
                .suggestionRequested,
                suggestionID: "one",
                metadata: ["delayMilliseconds": "180"]
                    .merging(staleProofMetadata()) { current, _ in current },
                includeProofMetadata: false
            ),
            event(
                .modelResult,
                suggestionID: "one",
                metadata: candidateSelectionMetadata()
                    .merging(staleProofMetadata()) { current, _ in current },
                includeProofMetadata: false
            ),
            event(
                .suggestionPresented,
                suggestionID: "one",
                latencyMilliseconds: 180,
                metadata: displayMetadata(decision: "display")
                    .merging(staleProofMetadata()) { current, _ in current },
                includeProofMetadata: false
            ),
            event(
                .acceptedTextEdited,
                suggestionID: "one",
                metadata: [
                    "checkpoint": AcceptanceSurvivalCheckpoint.thirtySeconds.rawValue,
                    "survivalClass": AcceptanceSurvivalClass.exactKept.rawValue
                ].merging(staleProofMetadata()) { current, _ in current },
                includeProofMetadata: false
            )
        ]

        let report = AutocompleteTraceReplay().report(for: events)

        #expect(!report.passesReplayProofGate)
        #expect(report.proofFingerprintCoverageRate == 0)
    }

    @Test("Missing placement metadata fails replay proof")
    func missingPlacementMetadataFailsReplayProof() {
        let events = [
            event(
                .suggestionRequested,
                suggestionID: "one",
                metadata: ["delayMilliseconds": "180"]
            ),
            event(
                .modelResult,
                suggestionID: "one",
                metadata: candidateSelectionMetadata()
            ),
            event(
                .suggestionPresented,
                suggestionID: "one",
                latencyMilliseconds: 180,
                metadata: displayMetadata(decision: "display"),
                includePlacementMetadata: false
            ),
            event(
                .acceptedTextEdited,
                suggestionID: "one",
                metadata: [
                    "checkpoint": AcceptanceSurvivalCheckpoint.thirtySeconds.rawValue,
                    "survivalClass": AcceptanceSurvivalClass.exactKept.rawValue
                ]
            )
        ]

        let report = AutocompleteTraceReplay().report(for: events)

        #expect(!report.passesReplayProofGate)
        #expect(report.placementCoverageRate == 0)
        #expect(report.requirements.contains {
            $0.name == "placement replay" && !$0.passed
        })
    }



    private func event(
        _ type: AutocompleteTraceEventType,
        suggestionID: String,
        requestMode: String = CompletionRequestMode.phraseContinuation.rawValue,
        textBeforeCursor: String = "",
        latencyMilliseconds: Int? = nil,
        outcome: String = "",
        reason: String = "",
        metadata: [String: String] = [:],
        includeProofMetadata: Bool = true,
        includePlacementMetadata: Bool = true
    ) -> AutocompleteTraceEvent {
        var traceMetadata = metadata
        if includePlacementMetadata, type == .suggestionPresented {
            traceMetadata = traceMetadata.merging(placementMetadata()) { _, current in current }
        }
        if includeProofMetadata {
            traceMetadata = traceMetadata.merging(AutocompleteTraceProofMetadata.current) { _, current in current }
        }

        return AutocompleteTraceEvent(
            timestamp: "2026-05-07T12:00:00Z",
            sessionID: "session-one",
            suggestionID: suggestionID,
            type: type,
            appBundleIdentifier: "com.apple.TextEdit",
            fieldIdentity: "com.apple.TextEdit|pid:42|element:7",
            requestMode: requestMode,
            textBeforeCursor: textBeforeCursor,
            latencyMilliseconds: latencyMilliseconds,
            outcome: outcome,
            reason: reason,
            metadata: traceMetadata
        )
    }

    private func displayMetadata(decision: String) -> [String: String] {
        [
            "displayScoreDecision": decision,
            "displayScoreUtility": "0.70",
            "displayScoreStyleFit": "0.40",
            "displayScoreContextFit": "0.50",
            "displayScoreUserAffinity": "0.20",
            "displayScoreRisk": "0.05",
            "displayScoreRepetition": "0.05",
            "displayScoreInstability": "0.05",
            "displayScoreFinal": "1.65",
            "displayScoreAcceptedAndKeptProbability": "0.340",
            "displayScoreAcceptedAndKeptSamples": "0"
        ]
    }

    private func candidateSelectionMetadata(
        cleanedCandidateCount: String = "2",
        topScore: String = "0.950",
        scoreMargin: String = "0.090",
        suppressionReason: String = "none"
    ) -> [String: String] {
        [
            "cleanedCandidateCount": cleanedCandidateCount,
            "candidateTopScore": topScore,
            "candidateScoreMargin": scoreMargin,
            "candidateSuppressionReason": suppressionReason
        ]
    }

    private func staleProofMetadata() -> [String: String] {
        var metadata = AutocompleteTraceProofMetadata.current
        metadata["placementProofVersion"] = "placement-old"
        return metadata
    }

    private func placementMetadata(
        anchor: String = "caret",
        confidence: String = "high",
        hasCaretRect: String = "true"
    ) -> [String: String] {
        [
            "placementAnchorSource": anchor,
            "placementConfidenceBand": confidence,
            "hasCaretRect": hasCaretRect
        ]
    }
}
