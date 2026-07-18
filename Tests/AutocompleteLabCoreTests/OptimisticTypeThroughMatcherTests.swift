import Testing
@testable import AutocompleteLabCore

@Suite("Optimistic type-through matcher")
struct OptimisticTypeThroughMatcherTests {
    private let matcher = OptimisticTypeThroughMatcher()

    @Test("Matching character advances the remaining suggestion")
    func matchingCharacterAdvancesRemainingSuggestion() {
        #expect(matcher.advance(
            typedCharacter: "s",
            remaining: "ship quickly"
        ) == .matched("hip quickly"))
    }

    @Test("Last matching character exhausts the suggestion")
    func lastMatchingCharacterExhaustsSuggestion() {
        #expect(matcher.advance(
            typedCharacter: "!",
            remaining: "!"
        ) == .exhausted)
    }

    @Test("Advance against an already exhausted suggestion stays exhausted")
    func advanceAgainstExhaustedSuggestionStaysExhausted() {
        #expect(matcher.advance(
            typedCharacter: "x",
            remaining: ""
        ) == .exhausted)
    }

    @Test("Mismatch leaves the caller responsible for invalidation")
    func mismatchDoesNotProduceRemainingText() {
        #expect(matcher.advance(
            typedCharacter: "n",
            remaining: "ship quickly"
        ) == .mismatch)
    }

    @Test("Case and diacritic folding matches the authoritative state machine")
    func caseAndDiacriticFoldingMatchesAuthoritativeStateMachine() {
        #expect(matcher.advance(
            typedCharacter: "e",
            remaining: "Élan matters"
        ) == .matched("lan matters"))
    }

    @Test("One typed whitespace consumes a suggestion whitespace run")
    func typedWhitespaceConsumesSuggestionWhitespaceRun() {
        #expect(matcher.advance(
            typedCharacter: " ",
            remaining: "  ship"
        ) == .matched("ship"))
    }

    @Test("Unicode grapheme advances as one character")
    func unicodeGraphemeAdvancesAsOneCharacter() {
        #expect(matcher.advance(
            typedCharacter: "👩‍💻",
            remaining: "👩‍💻 ships"
        ) == .matched(" ships"))
    }

    @Test("Retreat restores the exact original character")
    func retreatRestoresExactOriginalCharacter() {
        #expect(matcher.retreat(
            typedPrefix: "e",
            originalRemaining: "Élan matters"
        ) == .matched("Élan matters"))
    }

    @Test("Retreat recomputes the remainder after several matching keydowns")
    func retreatRecomputesRemainderAfterSeveralKeydowns() {
        #expect(matcher.retreat(
            typedPrefix: "shi",
            originalRemaining: "ship quickly"
        ) == .matched("ip quickly"))
    }

    @Test("Retreat restores an entire collapsed whitespace run")
    func retreatRestoresCollapsedWhitespaceRun() {
        #expect(matcher.retreat(
            typedPrefix: " ",
            originalRemaining: "   ship"
        ) == .matched("   ship"))
    }

    @Test("Retreat rejects an empty or invalid consumed prefix")
    func retreatRejectsInvalidConsumedPrefix() {
        #expect(matcher.retreat(
            typedPrefix: "",
            originalRemaining: "ship"
        ) == .mismatch)
        #expect(matcher.retreat(
            typedPrefix: "slow",
            originalRemaining: "ship"
        ) == .mismatch)
    }
}
