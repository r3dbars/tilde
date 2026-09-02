import Foundation
import Testing
@testable import TildeCore

/// The streaming gate: personalization must not cost the word-by-word ghost,
/// and a prefix already on screen must never be rewritten underneath it.
@Suite("Personal streaming gate policy")
struct PersonalStreamGatePolicyTests {
    private let replacement = PersonalNextWordPrediction(word: "tomorrow", support: 4, total: 4)
    private let unsupported = PersonalNextWordPrediction(word: "tomorrow", support: 1, total: 4)

    @Test("An unresolved lookup holds, whatever the generator has produced")
    func unresolvedHolds() {
        #expect(PersonalSuggestionPolicy.streamDecision(
            basePrefix: nil, personalPrediction: nil, personalResolved: false
        ) == .hold)
        #expect(PersonalSuggestionPolicy.streamDecision(
            basePrefix: "meet you", personalPrediction: nil, personalResolved: false
        ) == .hold)
    }

    @Test("A lookup that answers with nothing streams immediately")
    func resolvedEmptyStreams() {
        #expect(PersonalSuggestionPolicy.streamDecision(
            basePrefix: nil, personalPrediction: nil, personalResolved: true
        ) == .stream)
        #expect(PersonalSuggestionPolicy.streamDecision(
            basePrefix: "meet you", personalPrediction: nil, personalResolved: true
        ) == .stream)
    }

    @Test("An answer under the arbiter's evidence bar can never win, so it stops holding")
    func underEvidenceBarStreamsBeforeTheBaseTextExists() {
        #expect(!PersonalSuggestionPolicy.couldReplaceAnyBase(unsupported))
        #expect(!PersonalSuggestionPolicy.couldReplaceAnyBase(nil))
        #expect(PersonalSuggestionPolicy.couldReplaceAnyBase(replacement))
        #expect(PersonalSuggestionPolicy.streamDecision(
            basePrefix: nil, personalPrediction: unsupported, personalResolved: true
        ) == .stream)
        // A candidate that could still displace some ghost keeps holding
        // until the generator gives the gate something to compare it with.
        #expect(PersonalSuggestionPolicy.streamDecision(
            basePrefix: nil, personalPrediction: replacement, personalResolved: true
        ) == .hold)
    }

    @Test("Agreement on the first word streams; disagreement with evidence goes final-only")
    func decidesOnTheFirstStablePrefix() {
        #expect(PersonalSuggestionPolicy.streamDecision(
            basePrefix: "Tomorrow works", personalPrediction: replacement, personalResolved: true
        ) == .stream)
        #expect(PersonalSuggestionPolicy.streamDecision(
            basePrefix: "afternoon works", personalPrediction: replacement, personalResolved: true
        ) == .finalOnly)
        // Disagreement the arbiter would not act on still streams.
        #expect(PersonalSuggestionPolicy.streamDecision(
            basePrefix: "afternoon works", personalPrediction: unsupported, personalResolved: true
        ) == .stream)
    }

    @Test("A prefix already shown is never rewritten: the final honours the base ghost")
    func shownPrefixSurvivesALatePersonalAnswer() {
        let streamed = PersonalSuggestionPolicy.finalSuggestion(
            baseGhost: "afternoon works great",
            personalPrediction: replacement,
            streamedPrefix: true
        )
        #expect(streamed.text == "afternoon works great")
        #expect(streamed.source == .base)

        let unstreamed = PersonalSuggestionPolicy.finalSuggestion(
            baseGhost: "afternoon works great",
            personalPrediction: replacement,
            streamedPrefix: false
        )
        #expect(unstreamed.text == "tomorrow")
        #expect(unstreamed.source == .personal)
    }

    @Test("Streaming changes nothing when the personal layer did not replace the ghost")
    func streamingDoesNotDisturbAgreementOrBase() {
        for streamed in [true, false] {
            let agreed = PersonalSuggestionPolicy.finalSuggestion(
                baseGhost: "Tomorrow works great",
                personalPrediction: replacement,
                streamedPrefix: streamed
            )
            #expect(agreed.text == "Tomorrow works great")
            #expect(agreed.source == .agreed)

            let base = PersonalSuggestionPolicy.finalSuggestion(
                baseGhost: "afternoon works great",
                personalPrediction: nil,
                streamedPrefix: streamed
            )
            #expect(base.text == "afternoon works great")
            #expect(base.source == .base)

            let silent = PersonalSuggestionPolicy.finalSuggestion(
                baseGhost: "",
                personalPrediction: replacement,
                streamedPrefix: streamed
            )
            #expect(silent.text.isEmpty)
            #expect(silent.source == .base)
        }
    }
}
