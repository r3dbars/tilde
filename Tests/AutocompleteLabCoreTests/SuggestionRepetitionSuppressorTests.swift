import Foundation
import Testing
@testable import AutocompleteLabCore

@Suite("Suggestion repetition suppressor")
struct SuggestionRepetitionSuppressorTests {
    @Test("suppresses repeated phrase misses")
    func suppressesRepeatedPhraseMisses() {
        var suppressor = SuggestionRepetitionSuppressor(missThreshold: 2)

        #expect(!suppressor.shouldSuppress(" What kind of laptop", mode: .phraseContinuation))
        suppressor.recordMiss("what kind of laptop", mode: .phraseContinuation)
        #expect(!suppressor.shouldSuppress("What kind of laptop?", mode: .phraseContinuation))
        suppressor.recordMiss("What kind of laptop?", mode: .phraseContinuation)
        #expect(suppressor.shouldSuppress(" what kind of laptop", mode: .phraseContinuation))
    }

    @Test("normalizes spacing in repeated phrase misses")
    func normalizesSpacingInRepeatedPhraseMisses() {
        var suppressor = SuggestionRepetitionSuppressor(missThreshold: 1)

        suppressor.recordMiss("what   kind\nof laptop", mode: .phraseContinuation)

        #expect(suppressor.shouldSuppress("What kind of laptop?", mode: .phraseContinuation))
    }

    @Test("suppresses tiny repeated word-completion misses")
    func suppressesTinyRepeatedWordCompletionMisses() {
        var suppressor = SuggestionRepetitionSuppressor(missThreshold: 1)

        suppressor.recordMiss("ng", mode: .wordCompletion)

        #expect(suppressor.shouldSuppress("ng", mode: .wordCompletion))
    }

    @Test("suppresses repeated substantial word completion misses")
    func suppressesRepeatedSubstantialWordCompletionMisses() {
        var suppressor = SuggestionRepetitionSuppressor(missThreshold: 1)

        suppressor.recordMiss("tation", mode: .wordCompletion)

        #expect(suppressor.shouldSuppress("tation", mode: .wordCompletion))
    }

    @Test("suppresses repeated word completion misses across short intervals")
    func suppressesRepeatedWordCompletionMissesAcrossShortIntervals() {
        let start = Date(timeIntervalSince1970: 1_000)
        var suppressor = SuggestionRepetitionSuppressor(
            missThreshold: 2,
            missHalfLifeSeconds: 600
        )

        suppressor.recordMiss("umentary", mode: .wordCompletion, now: start)
        suppressor.recordMiss(
            "umentary",
            mode: .wordCompletion,
            now: start.addingTimeInterval(1)
        )

        #expect(suppressor.shouldSuppress(
            "umentary",
            mode: .wordCompletion,
            now: start.addingTimeInterval(1)
        ))
    }

    @Test("does not suppress invalid word completion text")
    func doesNotSuppressInvalidWordCompletionText() {
        var suppressor = SuggestionRepetitionSuppressor(missThreshold: 1)

        suppressor.recordMiss("two words", mode: .wordCompletion)
        suppressor.recordMiss("ing.", mode: .wordCompletion)

        #expect(!suppressor.shouldSuppress("two words", mode: .wordCompletion))
        #expect(!suppressor.shouldSuppress("ing.", mode: .wordCompletion))
    }

    @Test("acceptance clears repeated phrase misses")
    func acceptanceClearsMisses() {
        var suppressor = SuggestionRepetitionSuppressor(missThreshold: 1)

        suppressor.recordMiss("keep going", mode: .phraseContinuation)
        #expect(suppressor.shouldSuppress("keep going", mode: .phraseContinuation))
        suppressor.recordAcceptance("keep going", mode: .phraseContinuation)
        #expect(!suppressor.shouldSuppress("keep going", mode: .phraseContinuation))
    }

    @Test("miss scores decay by half life")
    func missScoresDecayByHalfLife() {
        let start = Date(timeIntervalSince1970: 1_000)
        var suppressor = SuggestionRepetitionSuppressor(
            missThreshold: 1,
            missHalfLifeSeconds: 60
        )

        suppressor.recordMiss("keep going", mode: .phraseContinuation, now: start)

        #expect(suppressor.shouldSuppress("keep going", mode: .phraseContinuation, now: start))
        #expect(!suppressor.shouldSuppress(
            "keep going",
            mode: .phraseContinuation,
            now: start.addingTimeInterval(61)
        ))
    }

    @Test("miss suppression is scoped by app")
    func missSuppressionIsScopedByApp() {
        var suppressor = SuggestionRepetitionSuppressor(missThreshold: 1)

        suppressor.recordMiss("is", mode: .wordCompletion, scope: "com.openai.codex")

        #expect(suppressor.shouldSuppress("is", mode: .wordCompletion, scope: "com.openai.codex"))
        #expect(!suppressor.shouldSuppress("is", mode: .wordCompletion, scope: "com.apple.TextEdit"))

        suppressor.recordAcceptance("is", mode: .wordCompletion, scope: "com.apple.TextEdit")

        #expect(suppressor.shouldSuppress("is", mode: .wordCompletion, scope: "com.openai.codex"))
    }

    @Test("ignored hides are weak and lifetime aware")
    func ignoredHidesAreWeakAndLifetimeAware() {
        var suppressor = SuggestionRepetitionSuppressor(missThreshold: 1)

        for _ in 0..<10 {
            suppressor.recordIgnored(
                "maybe later",
                mode: .phraseContinuation,
                lifetimeMilliseconds: 90
            )
        }

        #expect(!suppressor.shouldSuppress("maybe later", mode: .phraseContinuation))

        suppressor.recordIgnored(
            "maybe later",
            mode: .phraseContinuation,
            lifetimeMilliseconds: 6_000
        )

        #expect(suppressor.shouldSuppress("maybe later", mode: .phraseContinuation))
    }

    @Test("ignored miss metadata is trace safe")
    func ignoredMissMetadataIsTraceSafe() throws {
        var suppressor = SuggestionRepetitionSuppressor(missThreshold: 2)

        let maybeRecord = suppressor.recordIgnored(
            "Follow up tomorrow",
            mode: .phraseContinuation,
            lifetimeMilliseconds: 2_000
        )
        let record = try #require(maybeRecord)
        let metadata = record.traceMetadata

        #expect(metadata["repetitionMissKind"] == "ignored")
        #expect(metadata["repetitionMissWeight"] == "0.35")
        #expect(metadata["repetitionMissTotal"] == "0.35")
        #expect(metadata["repetitionMissThreshold"] == "2.00")
        #expect(metadata["repetitionMissSuppressed"] == "false")
        #expect(metadata["repetitionMissLifetimeMs"] == "2000")
        #expect(!metadata.values.joined(separator: " ").contains("Follow"))
    }
}
