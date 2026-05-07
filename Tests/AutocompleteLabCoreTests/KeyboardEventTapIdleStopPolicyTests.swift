import Testing
@testable import AutocompleteLabCore

@Suite("Keyboard event tap idle stop policy")
struct KeyboardEventTapIdleStopPolicyTests {
    @Test("Stops only after suggestion UI and undo are both idle")
    func stopsOnlyAfterSuggestionUIAndUndoAreIdle() {
        let policy = KeyboardEventTapIdleStopPolicy()

        #expect(!policy.shouldStopKeyboardCapture(
            hasVisibleSuggestion: true,
            isSuggestionPanelVisible: false,
            hasPendingAcceptedInsertionUndo: false
        ))
        #expect(!policy.shouldStopKeyboardCapture(
            hasVisibleSuggestion: false,
            isSuggestionPanelVisible: true,
            hasPendingAcceptedInsertionUndo: false
        ))
        #expect(!policy.shouldStopKeyboardCapture(
            hasVisibleSuggestion: false,
            isSuggestionPanelVisible: false,
            hasPendingAcceptedInsertionUndo: true
        ))
        #expect(policy.shouldStopKeyboardCapture(
            hasVisibleSuggestion: false,
            isSuggestionPanelVisible: false,
            hasPendingAcceptedInsertionUndo: false
        ))
    }
}
