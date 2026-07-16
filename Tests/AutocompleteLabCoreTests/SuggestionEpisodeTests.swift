import Foundation
import Testing
import AutocompleteLabCore

@Suite("Suggestion episode")
struct SuggestionEpisodeTests {
    @Test("Records the full suggestion lifecycle")
    func recordsFullSuggestionLifecycle() {
        var record = makeRecord(id: "episode-one", index: 0)

        record.appendAction(
            .accepted,
            timestamp: "2026-05-24T12:00:02Z",
            reason: "tab",
            acceptedText: "send that over"
        )
        record.appendSurvivalCheckpoint(SuggestionEpisodeSurvivalCheckpoint(
            checkpoint: "30s",
            survivalClass: AcceptanceSurvivalClass.exactKept.rawValue,
            tokenRecall: 1,
            normalizedEditDistance: 0,
            timestamp: "2026-05-24T12:00:30Z"
        ))

        #expect(record.outcome == .kept)
        #expect(record.acceptedText == "send that over")
        #expect(record.acceptedAndKeptScore == 3)
        #expect(record.isEvalCandidate)
    }

    @Test("Two-second kept probes do not become eval examples")
    func twoSecondKeptProbesDoNotBecomeEvalExamples() {
        var record = makeRecord(id: "episode-two-second", index: 0)
        record.appendAction(
            .accepted,
            timestamp: "2026-05-24T12:00:02Z",
            reason: "tab",
            acceptedText: "send that over"
        )
        record.appendSurvivalCheckpoint(SuggestionEpisodeSurvivalCheckpoint(
            checkpoint: "2s",
            survivalClass: AcceptanceSurvivalClass.exactKept.rawValue,
            tokenRecall: 1,
            normalizedEditDistance: 0,
            timestamp: "2026-05-24T12:00:02Z"
        ))

        #expect(record.outcome == .accepted)
        #expect(record.acceptedAndKeptScore == 1)
        #expect(!record.isEvalCandidate)
    }

    @Test("Fast-deleted episodes cannot become kept eval examples later")
    func fastDeletedEpisodesCannotBecomeKeptEvalExamplesLater() {
        var record = makeRecord(id: "episode-fast-deleted", index: 0)
        record.appendAction(
            .accepted,
            timestamp: "2026-05-24T12:00:02Z",
            reason: "tab",
            acceptedText: "send that over"
        )
        record.appendSurvivalCheckpoint(SuggestionEpisodeSurvivalCheckpoint(
            checkpoint: "2s",
            survivalClass: AcceptanceSurvivalClass.rejectedAfterAccept.rawValue,
            tokenRecall: 0,
            normalizedEditDistance: 1,
            timestamp: "2026-05-24T12:00:02Z"
        ))
        record.appendSurvivalCheckpoint(SuggestionEpisodeSurvivalCheckpoint(
            checkpoint: "5m",
            survivalClass: AcceptanceSurvivalClass.exactKept.rawValue,
            tokenRecall: 1,
            normalizedEditDistance: 0,
            timestamp: "2026-05-24T12:05:00Z"
        ))

        #expect(record.outcome == .deletedFast)
        #expect(record.acceptedAndKeptScore == 0)
        #expect(!record.isEvalCandidate)
        #expect(SuggestionEpisodeScorecard(records: [record]).kept == 0)
        #expect(SuggestionEpisodeEvalGenerator().cases(from: [record]).isEmpty)
    }

    @Test("Dashboard counts actions model prompt and latency")
    func dashboardCountsActionsModelPromptAndLatency() {
        var kept = makeRecord(id: "kept", index: 0, latency: 120)
        kept.appendAction(.accepted, timestamp: "2026-05-24T12:00:02Z", acceptedText: "done")
        kept.appendSurvivalCheckpoint(SuggestionEpisodeSurvivalCheckpoint(
            checkpoint: "5m",
            survivalClass: AcceptanceSurvivalClass.exactKept.rawValue,
            timestamp: "2026-05-24T12:05:00Z"
        ))

        var ignored = makeRecord(id: "ignored", index: 1, latency: 300)
        ignored.appendAction(.ignored, timestamp: "2026-05-24T12:01:00Z", reason: "focus-changed")

        var deleted = makeRecord(id: "deleted", index: 2, latency: 180)
        deleted.appendAction(.accepted, timestamp: "2026-05-24T12:02:00Z", acceptedText: "wrong")
        deleted.appendSurvivalCheckpoint(SuggestionEpisodeSurvivalCheckpoint(
            checkpoint: "2s",
            survivalClass: AcceptanceSurvivalClass.rejectedAfterAccept.rawValue,
            timestamp: "2026-05-24T12:02:02Z"
        ))

        let scorecard = SuggestionEpisodeScorecard(records: [kept, ignored, deleted])

        #expect(scorecard.total == 3)
        #expect(scorecard.accepted == 2)
        #expect(scorecard.kept == 1)
        #expect(scorecard.ignored == 1)
        #expect(scorecard.deletedFast == 1)
        #expect(scorecard.averageLatencyMilliseconds == 200)
        #expect(scorecard.modelPromptRows.contains(
            "Gemma 4 E4B IT OptiQ / \(CompletionPromptBuilder.promptStyleIdentifier): shown 3, kept 1"
        ))
        #expect(scorecard.markdown.contains("Score:"))
    }

    @Test("Type-through survival remains a shown episode signal")
    func typeThroughSurvivalRemainsShownEpisodeSignal() {
        var record = makeRecord(id: "type-through", index: 0)

        record.appendAction(
            .shown,
            timestamp: "2026-05-24T12:00:01Z",
            reason: "survived_typethrough",
            metadata: [
                "typeThroughSurvival": "true",
                "typedThroughChars": "4",
                "remainingVisibleChars": "8"
            ]
        )

        let scorecard = SuggestionEpisodeScorecard(records: [record])

        #expect(record.outcome == .shown)
        #expect(record.actions.last?.reason == "survived_typethrough")
        #expect(record.actions.last?.metadata["typeThroughSurvival"] == "true")
        #expect(scorecard.shown == 1)
        #expect(scorecard.typedPast == 0)
        #expect(scorecard.typeThroughSurvivals == 1)
        #expect(scorecard.typeThroughSurvivalRate == 1)
        #expect(scorecard.markdown.contains("Type-through survival rate: 100% (1/1)"))
    }

    @Test("Eval generator uses only accepted and kept local examples")
    func evalGeneratorUsesOnlyAcceptedAndKeptLocalExamples() {
        var kept = makeRecord(id: "kept", index: 0)
        kept.appendAction(.accepted, timestamp: "2026-05-24T12:00:02Z", acceptedText: "that over")
        kept.appendSurvivalCheckpoint(SuggestionEpisodeSurvivalCheckpoint(
            checkpoint: "1m",
            survivalClass: AcceptanceSurvivalClass.lightlyEditedKept.rawValue,
            timestamp: "2026-05-24T12:01:00Z"
        ))

        var acceptedOnly = makeRecord(id: "accepted", index: 1)
        acceptedOnly.appendAction(.accepted, timestamp: "2026-05-24T12:02:00Z", acceptedText: "maybe")

        let cases = SuggestionEpisodeEvalGenerator().cases(from: [acceptedOnly, kept])

        #expect(cases.map(\.id) == ["kept"])
        #expect(cases[0].context.contains("Reply context 0"))
        #expect(cases[0].expectedContinuation == "that over")
        #expect(cases[0].acceptedAndKeptScore == 4)
    }

    @Test("Reply context persists only focused OCR regions")
    func replyContextPersistsOnlyFocusedOCRRegions() throws {
        let focused = try #require(VisiblePageContext(
            captureScope: .focusedRegion,
            activeApplicationName: "TextEdit",
            text: "focused reply"
        ))
        let visibleScreen = try #require(VisiblePageContext(
            captureScope: .visibleScreen,
            activeApplicationName: "TextEdit",
            text: "unrelated screen text"
        ))

        #expect(SuggestionEpisodeReplyContext(visiblePageContext: focused)?.text == "focused reply")
        #expect(SuggestionEpisodeReplyContext(visiblePageContext: visibleScreen) == nil)
    }

    @Test("One hundred weird episode cases stay scoreable")
    func oneHundredWeirdEpisodeCasesStayScoreable() {
        let records = (0..<100).map { index in
            var record = makeRecord(
                id: "episode-\(index)",
                index: index,
                latency: 60 + index,
                appBundleIdentifier: appBundleIdentifiers[index % appBundleIdentifiers.count],
                requestMode: requestModes[index % requestModes.count]
            )

            switch index % 5 {
            case 0:
                record.appendAction(.accepted, timestamp: "2026-05-24T12:00:\(twoDigits(index % 60))Z", acceptedText: "kept phrase \(index)")
                record.appendSurvivalCheckpoint(SuggestionEpisodeSurvivalCheckpoint(
                    checkpoint: index.isMultiple(of: 10) ? "5m" : "30s",
                    survivalClass: AcceptanceSurvivalClass.exactKept.rawValue,
                    tokenRecall: 1,
                    normalizedEditDistance: 0,
                    timestamp: "2026-05-24T12:05:\(twoDigits(index % 60))Z"
                ))
            case 1:
                record.appendAction(.ignored, timestamp: "2026-05-24T12:01:\(twoDigits(index % 60))Z", reason: "focus-changed")
            case 2:
                record.appendAction(.dismissed, timestamp: "2026-05-24T12:02:\(twoDigits(index % 60))Z", reason: "escape")
            case 3:
                record.appendAction(.typedPast, timestamp: "2026-05-24T12:03:\(twoDigits(index % 60))Z", reason: "typed-against-visible-suggestion")
            default:
                record.appendAction(.accepted, timestamp: "2026-05-24T12:04:\(twoDigits(index % 60))Z", acceptedText: "bad phrase \(index)")
                record.appendSurvivalCheckpoint(SuggestionEpisodeSurvivalCheckpoint(
                    checkpoint: "2s",
                    survivalClass: AcceptanceSurvivalClass.rejectedAfterAccept.rawValue,
                    tokenRecall: 0,
                    normalizedEditDistance: 1,
                    timestamp: "2026-05-24T12:04:\(twoDigits(index % 60))Z"
                ))
            }

            return record
        }

        let scorecard = SuggestionEpisodeScorecard(records: records)
        let evalCases = SuggestionEpisodeEvalGenerator().cases(from: records)

        #expect(scorecard.total == 100)
        #expect(scorecard.shown == 100)
        #expect(scorecard.kept == 20)
        #expect(scorecard.ignored == 20)
        #expect(scorecard.dismissed == 20)
        #expect(scorecard.typedPast == 20)
        #expect(scorecard.deletedFast == 20)
        #expect(evalCases.count == 20)
        #expect(scorecard.score > 0)
    }

    private func makeRecord(
        id: String,
        index: Int,
        latency: Int = 120,
        appBundleIdentifier: String = "com.apple.TextEdit",
        requestMode: String = CompletionRequestMode.phraseContinuation.rawValue
    ) -> SuggestionEpisodeRecord {
        SuggestionEpisodeRecord(
            id: id,
            createdAt: "2026-05-24T12:00:00Z",
            appDisplayName: appBundleIdentifier.components(separatedBy: ".").last ?? appBundleIdentifier,
            appBundleIdentifier: appBundleIdentifier,
            fieldIdentity: "\(appBundleIdentifier)|pid:\(index)|element:\(index + 1)",
            fieldKind: AXFieldKind.multilineCompose.rawValue,
            fieldKindReason: "test-\(index)",
            requestMode: requestMode,
            userTypedContext: "I should send the update \(index)",
            replyContext: SuggestionEpisodeReplyContext(
                source: VisiblePageContextSource.screenOCR.rawValue,
                captureScope: VisiblePageContextCaptureScope.focusedRegion.rawValue,
                text: "Reply context \(index)"
            ),
            suggestedText: "over today",
            model: SuggestionEpisodeModelContext(
                modelName: CompletionModelPolicy.mvp.model.rawValue,
                runtime: "mlx",
                asset: "gemma-4-e4b-it-OptiQ-4bit",
                promptVersion: CompletionPromptBuilder.promptStyleIdentifier,
                experimentArm: AutocompleteExperimentArm.length3Word.rawValue,
                triggerReason: "model-result",
                candidateSource: "app-model-result",
                latencyMilliseconds: latency,
                firstTokenLatencyMilliseconds: max(1, latency / 2)
            ),
            placement: SuggestionEpisodePlacementContext(
                renderMode: SuggestionRenderMode.inlineAdjacent.rawValue,
                anchorRect: "x=1,y=2,w=3,h=4",
                textLineRect: "x=1,y=2,w=30,h=14",
                panelRect: "x=1,y=18,w=80,h=24",
                confidenceBand: "green"
            )
        )
    }

    private var appBundleIdentifiers: [String] {
        [
            "com.apple.TextEdit",
            "com.apple.Notes",
            "md.obsidian",
            "com.openai.codex",
            "com.google.Chrome"
        ]
    }

    private var requestModes: [String] {
        [
            CompletionRequestMode.wordCompletion.rawValue,
            CompletionRequestMode.phraseContinuation.rawValue,
            CompletionRequestMode.sentenceContinuation.rawValue
        ]
    }

    private func twoDigits(_ value: Int) -> String {
        String(format: "%02d", value)
    }
}
