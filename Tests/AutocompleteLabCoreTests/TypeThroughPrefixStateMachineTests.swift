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

    @Test("Typing next word plus a boundary consumes a one-word suggestion")
    func typingNextWordPlusBoundaryConsumesOneWordSuggestion() {
        var session = SuggestionSession(
            visibleSuggestion: CompletionSuggestion(text: "ship", maxVisibleWords: 8)
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
            remainingVisibleCharacterCount: 0,
            consumedFullSuggestion: true
        )))
        #expect(!session.hasVisibleSuggestion)
    }

    @Test("Double-space word boundary advances without storing text")
    func doubleSpaceWordBoundaryAdvancesWithoutStoringText() {
        var session = SuggestionSession(
            visibleSuggestion: CompletionSuggestion(text: "ship quickly", maxVisibleWords: 8)
        )

        let transition = machine.apply(
            to: &session,
            input: input(
                baselineBefore: "We should ",
                currentBefore: "We should ship  "
            )
        )

        #expect(transition == .survived(TypeThroughPrefixSurvival(
            typedCharacterCount: 6,
            remainingVisibleCharacterCount: 7,
            consumedFullSuggestion: false
        )))
        #expect(session.visibleSuggestion?.visibleText == "quickly")
    }

    @Test("Punctuation then space can consume a punctuation suggestion")
    func punctuationThenSpaceCanConsumePunctuationSuggestion() {
        var session = SuggestionSession(
            visibleSuggestion: CompletionSuggestion(text: ",", maxVisibleWords: 8)
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
            remainingVisibleCharacterCount: 0,
            consumedFullSuggestion: true
        )))
        #expect(!session.hasVisibleSuggestion)
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

    @Test("Advance emits survived-typethrough signal and trims the visible suggestion")
    func advanceEmitsSurvivedTypethroughSignalAndTrimsVisibleSuggestion() {
        // The state machine should ADVANCE/trim the visible suggestion when the user types a
        // matching prefix, emitting the survived-typethrough signal.  This test verifies the
        // signal is present on the read-only `transition()` path AND that the mutating `apply()`
        // path trims the session accordingly — confirming the machine advances rather than
        // cancels when the typed characters match.
        var session = SuggestionSession(
            visibleSuggestion: CompletionSuggestion(text: " validate this path early", maxVisibleWords: 8)
        )
        let inp = input(
            baselineBefore: "we should probably",
            currentBefore: "we should probably validate"
        )

        // Read-only path: the transition is .survived with the correct signal.
        let readOnlyTransition = machine.transition(session: session, input: inp)
        guard case let .survived(survival) = readOnlyTransition else {
            Issue.record("Expected .survived but got \(readOnlyTransition)")
            return
        }
        #expect(survival.traceMetadata["reason"] == "survived_typethrough")
        #expect(survival.traceMetadata["typeThroughSurvival"] == "true")
        #expect(survival.typedCharacterCount == 9)   // " validate" is 9 chars
        #expect(!survival.consumedFullSuggestion)
        // Session must be unchanged after the read-only call.
        #expect(session.visibleSuggestion?.visibleText == " validate this path early")

        // Mutating path: apply() trims the session to the remaining suffix.
        let applyTransition = machine.apply(to: &session, input: inp)
        #expect(applyTransition == readOnlyTransition)
        // The leading space before "this" is part of the remaining text after the typed prefix.
        #expect(session.visibleSuggestion?.visibleText == " this path early")
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
        #expect(transition.traceMetadata["typeThroughConfidenceCredit"] == "true")
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
