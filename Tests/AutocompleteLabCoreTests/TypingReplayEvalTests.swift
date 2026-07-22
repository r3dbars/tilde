import Foundation
import Testing
@testable import AutocompleteLabCore

@Suite("Typing replay eval")
struct TypingReplayEvalTests {
    @Test("Extractor is deterministic and samples only word boundaries")
    func extractorIsDeterministic() {
        let entries = [
            entry("one two three four five six seven eight nine ten", day: "2026-07-01"),
            entry("eleven twelve thirteen fourteen fifteen sixteen", day: "2026-07-01")
        ]
        let extractor = TypingReplayCaseExtractor()

        let first = extractor.cases(from: entries, seed: 42, maxCases: 4)
        let repeated = extractor.cases(from: entries, seed: 42, maxCases: 4)
        let different = extractor.cases(from: entries, seed: 7, maxCases: 4)

        #expect(first == repeated)
        #expect(first != different)
        #expect(first.allSatisfy { $0.contextBefore.split(separator: " ").count >= 6 })
        #expect(first.allSatisfy { (1...12).contains($0.actualContinuation.split(separator: " ").count) })
    }

    @Test("Extractor does not cross app field or day streams")
    func extractorKeepsStreamsSeparate() {
        let entries = [
            entry("one two three four five six seven", app: "app.one", day: "2026-07-01"),
            entry("alpha beta gamma delta epsilon zeta eta", app: "app.two", day: "2026-07-01"),
            entry("red orange yellow green blue purple black", app: "app.one", day: "2026-07-02")
        ]

        let cases = TypingReplayCaseExtractor().cases(from: entries, maxCases: 100)

        #expect(cases.count == 3)
        #expect(cases.contains { $0.appBundleIdentifier == "app.one" && $0.dayString == "2026-07-01" && $0.actualContinuation == "seven" })
        #expect(cases.contains { $0.appBundleIdentifier == "app.two" && $0.actualContinuation == "eta" })
        #expect(cases.contains { $0.dayString == "2026-07-02" && $0.actualContinuation == "black" })
    }

    @Test("Scorer saves only complete exact words")
    func scorerRequiresCompleteExactWords() {
        let replayCase = replay(actual: "alpha beta, gamma delta")
        let scorer = TypingReplayScorer()

        let partial = scorer.score(suggestionText: "alpha bet", for: replayCase)
        let punctuation = scorer.score(suggestionText: "alpha beta, gamma", for: replayCase)
        let mismatch = scorer.score(suggestionText: "Alpha beta,", for: replayCase)
        let empty = scorer.score(suggestionText: "  ", for: replayCase)

        #expect(partial.keystrokesSaved == 5)
        #expect(partial.exactWordPrefix(n: 1))
        #expect(!partial.exactWordPrefix(n: 2))
        #expect(punctuation.keystrokesSaved == "alpha beta, gamma".count)
        #expect(punctuation.exactWordPrefix(n: 3))
        #expect(mismatch.keystrokesSaved == 0)
        #expect(mismatch.wrongFirstWord)
        #expect(empty.keystrokesSaved == 0)
        #expect(!empty.madeSuggestion)
    }

    @Test("Scorecard aggregates rates with honest denominators")
    func scorecardAggregates() {
        let scorer = TypingReplayScorer()
        let cases = [replay(id: "a", actual: "alpha beta gamma"), replay(id: "b", actual: "one two three")]
        let scores = [
            scorer.score(suggestionText: "alpha beta", for: cases[0]),
            scorer.score(suggestionText: "wrong word", for: cases[1])
        ]

        let scorecard = TypingReplayScorecard(scores: scores)

        #expect(scorecard.caseCount == 2)
        #expect(scorecard.totalKeystrokesSaved == "alpha beta".count)
        #expect(scorecard.top1WordAccuracy == 0.5)
        #expect(scorecard.wordPrefixAccuracy2 == 0.5)
        #expect(scorecard.shownKeystrokesSavedPerCase == scorecard.keystrokesSavedPerCase)
        #expect(scorecard.missedMagicRate == 0)
        #expect(scorecard.suggestionRate == 1)
        #expect(scorecard.wrongFirstWordRate == 0.5)
        #expect(scorecard.markdown.contains("Wrong first word among suggestions: 50.0%"))
    }

    @Test("Trend encoding is aggregate-only")
    func trendEncodingHasNoTextFields() throws {
        let score = TypingReplayScorer().score(suggestionText: "alpha beta", for: replay(actual: "alpha beta gamma"))
        let row = TypingReplayScorecard(scores: [score]).trendRow(
            dateISO: "2026-07-15T12:00:00Z",
            gitSHA: "abc123",
            engine: "mock",
            model: "mock",
            promptFormat: "chat-instruct",
            variant: "baseline",
            corpusKind: "fixture",
            promptContextCharacters: 480,
            suffixEnabled: true,
            fewShotSource: "none",
            decodingVariant: "tokens-24-temp-0.2-top-p-0.9-repeat-1.05"
        )
        let object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(row)) as? [String: Any])
        let allowedKeys: Set<String> = [
            "dateISO", "gitSHA", "engine", "model", "variant", "corpusKind", "caseCount",
            "promptFormat", "keystrokesSavedPerCase", "shownKeystrokesSavedPerCase", "missedMagicRate",
            "top1WordAccuracy", "wordPrefixAccuracy2",
            "wordPrefixAccuracy3", "wordPrefixAccuracy4", "suggestionRate",
            "wrongFirstWordRate", "endToEndP95LatencyMs", "acceptedAndKeptRate", "acceptRate",
            "promptContextCharacters", "suffixEnabled", "fewShotSource", "decodingVariant"
        ]

        #expect(Set(object.keys).isSubset(of: allowedKeys))
        #expect(object["dateISO"] as? String == "2026-07-15T12:00:00Z")
        #expect(object["promptContextCharacters"] as? Int == 480)
        #expect(object["suffixEnabled"] as? Bool == true)
        #expect(object["fewShotSource"] as? String == "none")
        #expect(object["decodingVariant"] as? String == "tokens-24-temp-0.2-top-p-0.9-repeat-1.05")
    }

    @Test("Replay fixtures remain compatible when suffix context is absent")
    func replayCaseDecodesWithoutSuffixContext() throws {
        let data = Data("""
        {"id":"legacy","contextBefore":"one two three four five six","actualContinuation":"seven","appBundleIdentifier":"app.one","fieldKind":"multilineCompose","dayString":"2026-07-02"}
        """.utf8)

        let replayCase = try JSONDecoder().decode(TypingReplayCase.self, from: data)

        #expect(replayCase.contextAfter.isEmpty)
    }

    @Test("Two-stage scoring exposes correct suggestions hidden by gating")
    func scorerTracksMissedMagic() {
        let replayCase = replay(actual: "alpha beta gamma")
        let score = TypingReplayScorer().score(
            rawSuggestionText: "alpha beta",
            gatedSuggestionText: nil,
            for: replayCase
        )
        let scorecard = TypingReplayScorecard(scores: [score])

        #expect(score.keystrokesSaved == "alpha beta".count)
        #expect(score.shownKeystrokesSaved == 0)
        #expect(score.missedMagic)
        #expect(scorecard.missedMagicRate == 1)
        #expect(scorecard.shownKeystrokesSavedPerCase == 0)
    }

    @Test("Replay gate uses the production confidence and display policies without vetoing short nubs")
    func replayGateUsesCorePolicies() {
        let replayCase = replay(actual: "alpha beta gamma")
        let gate = TypingReplayGateEvaluator()

        #expect(gate.shouldDisplay(suggestionText: "alpha beta gamma", replayCase: replayCase))
        // #180 softens short-phrase penalties: a clean one-word continuation can display
        // when the rest of the confidence and display gates are healthy.
        #expect(gate.shouldDisplay(suggestionText: "alpha", replayCase: replayCase))
        #expect(!gate.shouldDisplay(
            suggestionText: "alpha beta gamma",
            replayCase: replayCase,
            latencyMilliseconds: 1_500
        ))
    }

    @Test("Live trend rows carry accepted-and-kept and acceptance rates")
    func liveTrendRowCarriesRates() {
        var kept = episode(id: "kept")
        kept.appendAction(.accepted, timestamp: "2026-07-15T12:00:01Z", acceptedText: "ship it")
        kept.appendSurvivalCheckpoint(SuggestionEpisodeSurvivalCheckpoint(
            checkpoint: AcceptanceSurvivalCheckpoint.thirtySeconds.rawValue,
            survivalClass: AcceptanceSurvivalClass.exactKept.rawValue,
            timestamp: "2026-07-15T12:00:30Z"
        ))
        let row = TypingReplayTrendRow.live(
            dateISO: "2026-07-15T12:01:00Z",
            gitSHA: "abc123",
            model: "mock",
            corpusKind: "personal",
            scorecard: SuggestionEpisodeScorecard(records: [kept, episode(id: "shown")])
        )

        #expect(row.engine == "live")
        #expect(row.promptFormat == "live")
        #expect(row.variant == "live")
        #expect(row.acceptRate == 0.5)
        #expect(row.acceptedAndKeptRate == 1)
    }

    @Test("Mock engine can drive a synthetic replay case")
    func mockEngineDrivesReplay() async throws {
        let replayCase = replay(context: "I think", actual: "we should ship this today")
        let suggestion = try await MockCompletionEngine().suggestion(for: CompletionRequest(
            textBeforeCursor: replayCase.contextBefore,
            maxVisibleWords: 4,
            suggestionID: replayCase.id
        ))

        let score = TypingReplayScorer().score(suggestionText: suggestion?.visibleText, for: replayCase)

        #expect(score.exactWordPrefix(n: 4))
        #expect(score.keystrokesSaved == "we should ship this".count)
    }

    private func entry(
        _ text: String,
        app: String = "app.one",
        field: AXFieldKind = .multilineCompose,
        day: String
    ) -> PersonalCaptureJournalEntry {
        PersonalCaptureJournalEntry(
            kind: .typed,
            timeString: "12:00:00",
            appBundleIdentifier: app,
            fieldKind: field,
            text: text,
            dayString: day
        )
    }

    private func replay(
        id: String = "case",
        context: String = "one two three four five six",
        actual: String
    ) -> TypingReplayCase {
        TypingReplayCase(
            id: id,
            contextBefore: context,
            actualContinuation: actual,
            appBundleIdentifier: "app.one",
            fieldKind: AXFieldKind.multilineCompose.rawValue,
            dayString: "2026-07-02"
        )
    }

    private func episode(id: String) -> SuggestionEpisodeRecord {
        SuggestionEpisodeRecord(
            id: id,
            createdAt: "2026-07-15T12:00:00Z",
            appDisplayName: "TextEdit",
            appBundleIdentifier: "com.apple.TextEdit",
            fieldIdentity: "field",
            fieldKind: AXFieldKind.multilineCompose.rawValue,
            fieldKindReason: "test",
            requestMode: CompletionRequestMode.phraseContinuation.rawValue,
            userTypedContext: "we should",
            suggestedText: "ship it",
            model: SuggestionEpisodeModelContext(
                modelName: "mock",
                runtime: "mock",
                asset: "mock",
                promptVersion: CompletionPromptBuilder.promptStyleIdentifier,
                experimentArm: "test",
                triggerReason: "test",
                candidateSource: "test"
            ),
            placement: SuggestionEpisodePlacementContext(renderMode: SuggestionRenderMode.inlineAdjacent.rawValue)
        )
    }
}
