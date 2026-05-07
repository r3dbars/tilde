import Testing
@testable import AutocompleteLabCore

@Suite("Keyboard event tap consumption policy")
struct KeyboardEventTapConsumptionPolicyTests {
    private let policy = KeyboardEventTapConsumptionPolicy()

    @Test("Passes through all keys when no suggestion is visible")
    func passesThroughWithoutVisibleSuggestion() {
        for key in [AutocompleteKey.tab, .backtick, .optionTab, .escape, .other] {
            #expect(!policy.shouldConsume(input(
                key: key,
                hasVisibleSuggestion: false,
                supportsOneWordAcceptance: true,
                supportsFullAcceptance: true
            )))
        }
    }

    @Test("Passes through all keys after user typing invalidates the suggestion")
    func passesThroughAfterUserTypingInvalidatesSuggestion() {
        for key in [AutocompleteKey.tab, .backtick, .optionTab, .escape, .other] {
            #expect(!policy.shouldConsume(input(
                key: key,
                supportsOneWordAcceptance: true,
                supportsFullAcceptance: true,
                isInvalidatedByUserTyping: true
            )))
        }
    }

    @Test("Tab is consumed only for one-word capable profiles")
    func tabRequiresOneWordSupport() {
        #expect(policy.shouldConsume(input(key: .tab, supportsOneWordAcceptance: true)))
        #expect(!policy.shouldConsume(input(key: .tab, supportsOneWordAcceptance: false)))
    }

    @Test("Prompt-safe profiles do not consume full accept shortcuts")
    func promptSafeProfilesDoNotConsumeFullAcceptShortcuts() {
        #expect(!policy.shouldConsume(input(
            key: .backtick,
            supportsOneWordAcceptance: true,
            supportsFullAcceptance: false,
            acceptAllShortcut: .backtick
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
            key: .backtick,
            supportsFullAcceptance: true,
            acceptAllShortcut: .backtick
        )))
        #expect(!policy.shouldConsume(input(
            key: .optionTab,
            supportsFullAcceptance: true,
            acceptAllShortcut: .backtick
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

    @Test("Escape consumes only while a current suggestion is active")
    func escapeConsumesForActiveSuggestions() {
        #expect(policy.shouldConsume(input(key: .escape)))
        #expect(!policy.shouldConsume(input(key: .escape, hasVisibleSuggestion: false)))
    }

    @Test("Other keys pass through")
    func otherKeysPassThrough() {
        #expect(!policy.shouldConsume(input(key: .other)))
    }

    private func input(
        key: AutocompleteKey,
        hasVisibleSuggestion: Bool = true,
        supportsOneWordAcceptance: Bool = true,
        supportsFullAcceptance: Bool = false,
        isInvalidatedByUserTyping: Bool = false,
        acceptAllShortcut: AcceptAllShortcut = .backtick
    ) -> KeyboardEventTapConsumptionInput {
        KeyboardEventTapConsumptionInput(
            key: key,
            hasVisibleSuggestion: hasVisibleSuggestion,
            supportsOneWordAcceptance: supportsOneWordAcceptance,
            supportsFullAcceptance: supportsFullAcceptance,
            isInvalidatedByUserTyping: isInvalidatedByUserTyping,
            acceptAllShortcut: acceptAllShortcut
        )
    }
}
