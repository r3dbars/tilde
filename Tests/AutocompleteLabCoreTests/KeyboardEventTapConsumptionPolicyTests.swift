import Testing
@testable import AutocompleteLabCore

@Suite("Keyboard event tap consumption policy")
struct KeyboardEventTapConsumptionPolicyTests {
    private let policy = KeyboardEventTapConsumptionPolicy()

    @Test("Passes through all keys when no suggestion is visible")
    func passesThroughWithoutVisibleSuggestion() {
        for key in [AutocompleteKey.tab, .shiftTab, .backtick, .optionTab, .escape, .commandZ, .other] {
            #expect(!policy.shouldConsume(input(
                key: key,
                hasVisibleSuggestion: false,
                supportsOneWordAcceptance: true,
                supportsFullAcceptance: true
            )))
        }
    }

    @Test("Control Backtick is consumed for suggest now even without a visible suggestion")
    func controlBacktickConsumesForSuggestNow() {
        #expect(policy.shouldConsume(input(
            key: .controlBacktick,
            hasVisibleSuggestion: false
        )))
        #expect(policy.shouldConsume(input(
            key: .controlBacktick,
            isInvalidatedByUserTyping: true
        )))
    }

    @Test("Passes through all keys after user typing invalidates the suggestion")
    func passesThroughAfterUserTypingInvalidatesSuggestion() {
        for key in [AutocompleteKey.tab, .shiftTab, .backtick, .optionTab, .escape, .commandZ, .other] {
            #expect(!policy.shouldConsume(input(
                key: key,
                supportsOneWordAcceptance: true,
                supportsFullAcceptance: true,
                hasPendingAcceptedInsertionUndo: true,
                isInvalidatedByUserTyping: true
            )))
        }
    }

    @Test("Tab is consumed only for one-word capable profiles")
    func tabRequiresOneWordSupport() {
        #expect(policy.shouldConsume(input(key: .tab, supportsOneWordAcceptance: true)))
        #expect(!policy.shouldConsume(input(key: .tab, supportsOneWordAcceptance: false)))
    }

    @Test("Tab autorepeat does not consume a replacement suggestion")
    func tabAutorepeatDoesNotConsumeReplacementSuggestion() {
        #expect(policy.shouldConsume(input(
            key: .tab,
            isAutorepeat: true,
            visibleSuggestionID: "suggestion-one",
            keyDownSuggestionID: "suggestion-one"
        )))
        #expect(!policy.shouldConsume(input(
            key: .tab,
            isAutorepeat: true,
            visibleSuggestionID: "suggestion-two",
            keyDownSuggestionID: "suggestion-one"
        )))
    }

    @Test("Shift Tab accept-all still consumes the configured shortcut")
    func shiftTabAcceptAllStillConsumesConfiguredShortcut() {
        #expect(policy.shouldConsume(input(
            key: .shiftTab,
            supportsFullAcceptance: true,
            acceptAllShortcut: .shiftTab,
            visibleSuggestionID: "suggestion-one",
            keyDownSuggestionID: "suggestion-one"
        )))
    }

    @Test("Prompt-safe profiles do not consume full accept shortcuts")
    func promptSafeProfilesDoNotConsumeFullAcceptShortcuts() {
        #expect(!policy.shouldConsume(input(
            key: .shiftTab,
            supportsOneWordAcceptance: true,
            supportsFullAcceptance: false,
            acceptAllShortcut: .shiftTab
        )))
        #expect(!policy.shouldConsume(input(
            key: .optionTab,
            supportsOneWordAcceptance: true,
            supportsFullAcceptance: false,
            acceptAllShortcut: .optionTab
        )))
    }

    @Test("Full accept shortcuts consume only the configured shortcut")
    func fullAcceptConsumesOnlyConfiguredShortcut() {
        #expect(policy.shouldConsume(input(
            key: .shiftTab,
            supportsFullAcceptance: true,
            acceptAllShortcut: .shiftTab
        )))
        #expect(!policy.shouldConsume(input(
            key: .optionTab,
            supportsFullAcceptance: true,
            acceptAllShortcut: .shiftTab
        )))
        #expect(!policy.shouldConsume(input(
            key: .backtick,
            supportsFullAcceptance: true,
            acceptAllShortcut: .shiftTab
        )))
        #expect(policy.shouldConsume(input(
            key: .optionTab,
            supportsFullAcceptance: true,
            acceptAllShortcut: .optionTab
        )))
        #expect(!policy.shouldConsume(input(
            key: .backtick,
            supportsFullAcceptance: true,
            acceptAllShortcut: .optionTab
        )))
    }

    @Test("Disabled full accept never consumes full accept keys")
    func disabledFullAcceptNeverConsumesFullAcceptKeys() {
        #expect(!policy.shouldConsume(input(
            key: .shiftTab,
            supportsFullAcceptance: true,
            acceptAllShortcut: .disabled
        )))
        #expect(!policy.shouldConsume(input(
            key: .optionTab,
            supportsFullAcceptance: true,
            acceptAllShortcut: .disabled
        )))
    }

    @Test("Escape consumes only while a current suggestion is active")
    func escapeConsumesForActiveSuggestions() {
        #expect(policy.shouldConsume(input(key: .escape)))
        #expect(!policy.shouldConsume(input(key: .escape, hasVisibleSuggestion: false)))
    }

    @Test("Other keys pass through")
    func otherKeysPassThrough() {
        #expect(!policy.shouldConsume(input(key: .other)))
    }

    @Test("Unhandled consumed accept keys are dropped instead of replayed")
    func unhandledConsumedAcceptKeysAreDropped() {
        #expect(!policy.shouldReplayUnhandledConsumedKey(.tab))
        #expect(!policy.shouldReplayUnhandledConsumedKey(.shiftTab))
        #expect(policy.shouldReplayUnhandledConsumedKey(.backtick))
        #expect(!policy.shouldReplayUnhandledConsumedKey(.controlBacktick))
        #expect(!policy.shouldReplayUnhandledConsumedKey(.optionTab))
        #expect(!policy.shouldReplayUnhandledConsumedKey(.escape))
        #expect(policy.shouldReplayUnhandledConsumedKey(.other))
    }

    @Test("Command Z is consumed only for a pending native undo replay")
    func commandZConsumesOnlyForPendingUndoReplay() {
        #expect(policy.shouldConsume(input(
            key: .commandZ,
            hasVisibleSuggestion: false,
            hasPendingAcceptedInsertionUndo: true
        )))
        #expect(policy.shouldConsume(input(
            key: .commandZ,
            hasVisibleSuggestion: true,
            hasPendingAcceptedInsertionUndo: true
        )))
        #expect(!policy.shouldConsume(input(
            key: .commandZ,
            hasVisibleSuggestion: true,
            hasPendingAcceptedInsertionUndo: false
        )))
    }

    private func input(
        key: AutocompleteKey,
        hasVisibleSuggestion: Bool = true,
        supportsOneWordAcceptance: Bool = true,
        supportsFullAcceptance: Bool = false,
        hasPendingAcceptedInsertionUndo: Bool = false,
        isInvalidatedByUserTyping: Bool = false,
        acceptAllShortcut: AcceptAllShortcut = .shiftTab,
        isAutorepeat: Bool = false,
        visibleSuggestionID: String? = nil,
        keyDownSuggestionID: String? = nil
    ) -> KeyboardEventTapConsumptionInput {
        KeyboardEventTapConsumptionInput(
            key: key,
            hasVisibleSuggestion: hasVisibleSuggestion,
            supportsOneWordAcceptance: supportsOneWordAcceptance,
            supportsFullAcceptance: supportsFullAcceptance,
            isInvalidatedByUserTyping: isInvalidatedByUserTyping,
            hasPendingAcceptedInsertionUndo: hasPendingAcceptedInsertionUndo,
            acceptAllShortcut: acceptAllShortcut,
            isAutorepeat: isAutorepeat,
            visibleSuggestionID: visibleSuggestionID,
            keyDownSuggestionID: keyDownSuggestionID
        )
    }
}
