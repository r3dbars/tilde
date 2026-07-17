import AppKit
import AutocompleteLabCore
import Testing
@testable import AutocompleteLabApp

@Suite("Current suggestion state")
struct CurrentSuggestionStateTests {
    @Test("Optimistic type-through advances the acceptance text revision")
    func optimisticTypeThroughAdvancesAcceptanceRevision() throws {
        let identity = FocusedFieldIdentity(
            bundleIdentifier: "com.apple.TextEdit",
            processIdentifier: 42,
            elementIdentifier: 7
        )
        let targetFingerprint = FocusedTargetFingerprint(
            role: "AXTextArea",
            subrole: nil,
            elementFingerprint: FocusedElementFingerprint(identifier: "editor"),
            windowIdentifier: 1,
            elementBounds: nil,
            windowBounds: nil,
            caretBounds: nil,
            surroundingTextRevision: FocusedTextRevision(
                textBeforeCursor: "This is ",
                textAfterCursor: ""
            )
        )
        let shown = SuggestionAcceptanceSnapshot(
            fieldIdentity: identity,
            targetFingerprint: targetFingerprint,
            textBeforeCursor: "This is ",
            textAfterCursor: "",
            selectedTextLength: 0
        )
        var state = CurrentSuggestionState(
            fieldIdentity: identity,
            textBeforeCursor: "This is ",
            acceptanceSnapshot: shown,
            displayedText: "difficult"
        )

        let applied = state.applyOptimisticTypeThrough(
            KeyboardOptimisticTypeThroughTransition.matched(
                typedCharacter: "d",
                typedPrefix: "d",
                remainingText: "ifficult"
            )
        )
        #expect(applied)
        let advanced = try #require(state.acceptanceSnapshot)
        let current = shown.advancingTextRevision(
            textBeforeCursor: "This is d",
            textAfterCursor: "",
            selectedTextLength: 0
        )

        #expect(advanced == current)
        #expect(SuggestionAcceptanceGuard().decision(shown: advanced, current: current) == .allow)
    }
}
