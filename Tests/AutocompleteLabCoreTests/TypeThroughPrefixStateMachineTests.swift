import Testing
@testable import AutocompleteLabCore

@Suite("Type-through prefix state machine")
struct TypeThroughPrefixStateMachineTests {
    private let machine = TypeThroughPrefixStateMachine()

    @Test("Typed character matching the visible head trims the suggestion")
    func typedCharacterMatchingVisibleHeadTrimsSuggestion() {
        var session = SuggestionSession(
            visibleSuggestion: CompletionSuggestion(text: " to ship quickly", maxVisibleWords: 8)
        )

        let transition = machine.apply(
            to: &session,
            input: input(
                baselineBefore: "We need",
                currentBefore: "We need "
            )
        )

        #expect(transition == .survived(TypeThroughPrefixSurvival(
            typedCharacterCount: 1,
            remainingVisibleCharacterCount: 15,
            consumedFullSuggestion: false
        )))
        #expect(session.visibleSuggestion?.visibleText == "to ship quickly")
    }

    @Test("Typed word and boundary matching the visible head trims whole word")
    func typedWordAndBoundaryMatchingVisibleHeadTrimsWholeWord() {
        var session = SuggestionSession(
            visibleSuggestion: CompletionSuggestion(text: "ship quickly", maxVisibleWords: 8)
        )

        let transition = machine.apply(
            to: &session,
            input: input(
                baselineBefore: "We should ",
                currentBefore: "We should ship "
            )
        )

        #expect(transition == .survived(TypeThroughPrefixSurvival(
            typedCharacterCount: 5,
            remainingVisibleCharacterCount: 7,
            consumedFullSuggestion: false
        )))
        #expect(session.visibleSuggestion?.visibleText == "quickly")
    }

    @Test("Typed word boundary invalidates when the suggestion continues the word")
    func typedWordBoundaryInvalidatesWhenSuggestionContinuesWord() {
        var session = SuggestionSession(
            visibleSuggestion: CompletionSuggestion(text: "shipping quickly", maxVisibleWords: 8)
        )

        let transition = machine.apply(
            to: &session,
            input: input(
                baselineBefore: "We should ",
                currentBefore: "We should ship "
            )
        )

        #expect(transition == .invalidated(.mismatch))
        #expect(session.visibleSuggestion?.visibleText == "shipping quickly")
    }

    @Test("Punctuation prefix trims safely")
    func punctuationPrefixTrimsSafely() {
        var session = SuggestionSession(
            visibleSuggestion: CompletionSuggestion(text: ", and then stop", maxVisibleWords: 8)
        )

        let transition = machine.apply(
            to: &session,
            input: input(
                baselineBefore: "Wait",
                currentBefore: "Wait, "
            )
        )

        #expect(transition == .survived(TypeThroughPrefixSurvival(
            typedCharacterCount: 2,
            remainingVisibleCharacterCount: 13,
            consumedFullSuggestion: false
        )))
        #expect(session.visibleSuggestion?.visibleText == "and then stop")
    }

    @Test("Case and diacritic differences still consume one visible character")
    func caseAndDiacriticDifferencesStillConsumeOneVisibleCharacter() {
        var session = SuggestionSession(
            visibleSuggestion: CompletionSuggestion(text: "Élan matters", maxVisibleWords: 8)
        )

        let transition = machine.apply(
            to: &session,
            input: input(
                baselineBefore: "The ",
                currentBefore: "The e"
            )
        )

        #expect(transition == .survived(TypeThroughPrefixSurvival(
            typedCharacterCount: 1,
            remainingVisibleCharacterCount: 11,
            consumedFullSuggestion: false
        )))
        #expect(session.visibleSuggestion?.visibleText == "lan matters")
    }

    @Test("Typing the full visible suggestion consumes it")
    func typingFullVisibleSuggestionConsumesIt() {
        var session = SuggestionSession(
            visibleSuggestion: CompletionSuggestion(text: "done", maxVisibleWords: 8)
        )

        let transition = machine.apply(
            to: &session,
            input: input(
                baselineBefore: "Ship ",
                currentBefore: "Ship done"
            )
        )

        #expect(transition == .survived(TypeThroughPrefixSurvival(
            typedCharacterCount: 4,
            remainingVisibleCharacterCount: 0,
            consumedFullSuggestion: true
        )))
        #expect(!session.hasVisibleSuggestion)
    }

    @Test("Mismatch invalidates without mutating the visible suggestion")
    func mismatchInvalidatesWithoutMutatingVisibleSuggestion() {
        var session = SuggestionSession(
            visibleSuggestion: CompletionSuggestion(text: "native and fast", maxVisibleWords: 8)
        )

        let transition = machine.apply(
            to: &session,
            input: input(
                baselineBefore: "Make it ",
                currentBefore: "Make it slow"
            )
        )

        #expect(transition == .invalidated(.mismatch))
        #expect(session.visibleSuggestion?.visibleText == "native and fast")
    }

    @Test("Stale field invalidates without mutating the visible suggestion")
    func staleFieldInvalidatesWithoutMutatingVisibleSuggestion() {
        var session = SuggestionSession(
            visibleSuggestion: CompletionSuggestion(text: "finish here", maxVisibleWords: 8)
        )

        let transition = machine.apply(
            to: &session,
            input: input(
                baselineField: field(element: 1),
                currentField: field(element: 2),
                baselineBefore: "Please ",
                currentBefore: "Please f"
            )
        )

        #expect(transition == .invalidated(.staleField))
        #expect(session.visibleSuggestion?.visibleText == "finish here")
    }

    @Test("After-cursor changes invalidate as stale text")
    func afterCursorChangesInvalidateAsStaleText() {
        var session = SuggestionSession(
            visibleSuggestion: CompletionSuggestion(text: "finish here", maxVisibleWords: 8)
        )

        let transition = machine.apply(
            to: &session,
            input: input(
                baselineBefore: "Please ",
                currentBefore: "Please f",
                baselineAfter: "",
                currentAfter: " moved"
            )
        )

        #expect(transition == .invalidated(.textAfterCursorChanged))
        #expect(session.visibleSuggestion?.visibleText == "finish here")
    }

    @Test("Cursor text that no longer extends the baseline invalidates")
    func cursorTextNoLongerExtendsBaselineInvalidates() {
        var session = SuggestionSession(
            visibleSuggestion: CompletionSuggestion(text: "finish here", maxVisibleWords: 8)
        )

        let transition = machine.apply(
            to: &session,
            input: input(
                baselineBefore: "Please finish",
                currentBefore: "Please fin"
            )
        )

        #expect(transition == .invalidated(.baselineChanged))
        #expect(session.visibleSuggestion?.visibleText == "finish here")
    }

    @Test("Unsupported composition suppresses type-through handling")
    func unsupportedCompositionSuppressesTypeThroughHandling() {
        var session = SuggestionSession(
            visibleSuggestion: CompletionSuggestion(text: "finish here", maxVisibleWords: 8)
        )

        let transition = machine.apply(
            to: &session,
            input: input(
                baselineBefore: "Please ",
                currentBefore: "Please f",
                compositionState: .activeUnsupported
            )
        )

        #expect(transition == .suppressed(.unsupportedComposition))
        #expect(session.visibleSuggestion?.visibleText == "finish here")
    }

    @Test("Survival metadata is trace safe")
    func survivalMetadataIsTraceSafe() throws {
        let transition = TypeThroughPrefixTransition.survived(TypeThroughPrefixSurvival(
            typedCharacterCount: 3,
            remainingVisibleCharacterCount: 9,
            consumedFullSuggestion: false
        ))

        #expect(transition.traceMetadata["reason"] == "survived_typethrough")
        #expect(transition.traceMetadata["typeThroughSurvival"] == "true")
        #expect(transition.traceMetadata["typedThroughChars"] == "3")
        #expect(transition.traceMetadata["remainingVisibleChars"] == "9")
        #expect(transition.traceMetadata["typeThroughConsumedFullSuggestion"] == "false")
    }

    private func input(
        baselineField: FocusedFieldIdentity? = nil,
        currentField: FocusedFieldIdentity? = nil,
        baselineBefore: String,
        currentBefore: String,
        baselineAfter: String = "",
        currentAfter: String = "",
        compositionState: TypeThroughCompositionState = .inactive
    ) -> TypeThroughPrefixInput {
        let baselineField = baselineField ?? field()
        return TypeThroughPrefixInput(
            baselineSnapshot: FocusedTextSnapshot(
                fieldIdentity: baselineField,
                textBeforeCursor: baselineBefore,
                textAfterCursor: baselineAfter
            ),
            currentSnapshot: FocusedTextSnapshot(
                fieldIdentity: currentField ?? baselineField,
                textBeforeCursor: currentBefore,
                textAfterCursor: currentAfter
            ),
            compositionState: compositionState
        )
    }

    private func field(element: Int = 1) -> FocusedFieldIdentity {
        FocusedFieldIdentity(
            bundleIdentifier: "com.apple.TextEdit",
            processIdentifier: 42,
            elementIdentifier: element
        )
    }
}
