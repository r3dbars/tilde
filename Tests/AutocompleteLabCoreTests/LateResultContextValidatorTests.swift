import Testing
@testable import AutocompleteLabCore

@Suite("Late result context validator")
struct LateResultContextValidatorTests {
    private let validator = LateResultContextValidator()

    @Test("Unchanged context remains valid with an empty typed delta")
    func unchangedContextRemainsValid() {
        let request = snapshot(before: "Please hel")

        #expect(validator.validate(requestSnapshot: request, currentSnapshot: request) ==
            .stillValid(typedSinceRequest: ""))
    }

    @Test("Text appended while the model runs remains valid")
    func appendedTextRemainsValid() {
        let request = snapshot(before: "Please hel")
        let current = snapshot(before: "Please hello")

        #expect(validator.validate(requestSnapshot: request, currentSnapshot: current) ==
            .stillValid(typedSinceRequest: "lo"))
    }

    @Test("A result past the maximum age is invalid even when text still matches")
    func overAgeResultInvalidates() {
        let request = snapshot(before: "Please hel")
        let current = snapshot(before: "Please hello")

        #expect(validator.validate(
            requestSnapshot: request,
            currentSnapshot: current,
            latencyMilliseconds: 1_501
        ) == .invalid(.tooLate))
    }

    @Test("A result at the maximum age remains eligible for context validation")
    func maximumAgeRemainsEligible() {
        let request = snapshot(before: "Please hel")
        let current = snapshot(before: "Please hello")

        #expect(validator.validate(
            requestSnapshot: request,
            currentSnapshot: current,
            latencyMilliseconds: validator.maximumResultAgeMilliseconds
        ) == .stillValid(typedSinceRequest: "lo"))
    }

    @Test("A different focused field invalidates the result")
    func changedFieldInvalidates() {
        let request = snapshot(before: "Please hel")
        let current = snapshot(elementIdentifier: 2, before: "Please hello")

        #expect(validator.validate(requestSnapshot: request, currentSnapshot: current) ==
            .invalid(.fieldChanged))
    }

    @Test("Editing or deleting the request prefix invalidates the result")
    func changedBaselineInvalidates() {
        let request = snapshot(before: "Please hello")
        let current = snapshot(before: "Please hel")

        #expect(validator.validate(requestSnapshot: request, currentSnapshot: current) ==
            .invalid(.baselineChanged))
    }

    @Test("After-cursor changes invalidate an otherwise extending prefix")
    func afterCursorChangesInvalidate() {
        let request = snapshot(before: "Please hel", after: " world")
        let current = snapshot(before: "Please hello", after: "!")

        #expect(validator.validate(requestSnapshot: request, currentSnapshot: current) ==
            .invalid(.suffixChanged))
    }

    @Test("Typed delta is removed from a late suggestion")
    func trimsTypedDeltaFromSuggestion() {
        let suggestion = CompletionSuggestion(text: "lo there", maxVisibleWords: 8)

        let trimmed = validator.trimmedSuggestion(suggestion, typedSinceRequest: "lo ")

        #expect(trimmed?.text == "there")
        #expect(trimmed?.maxVisibleWords == 8)
        #expect(trimmed?.maxVisibleCharacters == suggestion.maxVisibleCharacters)
    }

    @Test("Type-through normalization is shared with visible suggestions")
    func trimmingUsesSharedTypeThroughNormalization() {
        let suggestion = CompletionSuggestion(text: "Élan arrives", maxVisibleWords: 8)

        let trimmed = validator.trimmedSuggestion(suggestion, typedSinceRequest: "e")

        #expect(trimmed?.text == "lan arrives")
    }

    @Test("A conflicting typed delta discards the late suggestion")
    func conflictingDeltaDiscardsSuggestion() {
        let suggestion = CompletionSuggestion(text: "lo there", maxVisibleWords: 8)

        #expect(validator.trimmedSuggestion(suggestion, typedSinceRequest: "p") == nil)
    }

    @Test("A fully typed suggestion leaves nothing to display")
    func fullyTypedSuggestionLeavesNothingToDisplay() {
        let suggestion = CompletionSuggestion(text: "lo", maxVisibleWords: 8)

        #expect(validator.trimmedSuggestion(suggestion, typedSinceRequest: "lo") == nil)
    }

    private func snapshot(
        elementIdentifier: Int = 1,
        before: String,
        after: String = ""
    ) -> FocusedTextSnapshot {
        FocusedTextSnapshot(
            fieldIdentity: FocusedFieldIdentity(
                bundleIdentifier: "com.apple.TextEdit",
                processIdentifier: 42,
                elementIdentifier: elementIdentifier
            ),
            textBeforeCursor: before,
            textAfterCursor: after
        )
    }
}
