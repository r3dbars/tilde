import Testing
import ApplicationServices
import AutocompleteLabCore
import Carbon.HIToolbox
@testable import AutocompleteLabApp

@Suite("Keyboard event tap key codes")
struct KeyboardEventTapKeyCodeTests {
    @Test("Mac virtual key codes map to autocomplete physical keys")
    func mapsMacVirtualKeyCodes() {
        #expect(autocompletePhysicalKey(forMacVirtualKeyCode: 6) == .z)
        #expect(autocompletePhysicalKey(forMacVirtualKeyCode: 48) == .tab)
        #expect(autocompletePhysicalKey(forMacVirtualKeyCode: 50) == .backtick)
        #expect(autocompletePhysicalKey(forMacVirtualKeyCode: 53) == .escape)
        #expect(autocompletePhysicalKey(forMacVirtualKeyCode: 999) == .other)
    }

    @Test("Pure modifier key downs do not count as typing before Option Tab")
    func modifierOnlyKeyDownsDoNotCountAsTyping() {
        #expect(isModifierOnlyMacVirtualKeyCode(58))
        #expect(isModifierOnlyMacVirtualKeyCode(61))
        #expect(isModifierOnlyMacVirtualKeyCode(55))
        #expect(!isModifierOnlyMacVirtualKeyCode(48))
        #expect(!isModifierOnlyMacVirtualKeyCode(6))
    }

    @Test("Forward Delete does not rewind optimistic type-through")
    func forwardDeleteDoesNotRewindOptimisticTypeThrough() {
        #expect(isBackspaceMacVirtualKeyCode(51))
        #expect(!isBackspaceMacVirtualKeyCode(117))
    }

    @Test("Stale passthrough observations only block genuinely invalidated suggestions")
    func stalePassthroughObservationsOnlyBlockInvalidatedSuggestions() {
        #expect(!shouldPassThroughAutocompleteKeyAfterPassthroughObservation(
            snapshot: KeyboardEventTapSnapshot(
                hasVisibleSuggestion: true,
                supportsOneWordAcceptance: true,
                supportsFullAcceptance: true,
                isInvalidatedByUserTyping: false,
                acceptAllShortcut: .optionTab
            )
        ))

        #expect(shouldPassThroughAutocompleteKeyAfterPassthroughObservation(
            snapshot: KeyboardEventTapSnapshot(
                hasVisibleSuggestion: true,
                supportsOneWordAcceptance: true,
                supportsFullAcceptance: true,
                isInvalidatedByUserTyping: true,
                acceptAllShortcut: .optionTab
            )
        ))

        #expect(!shouldPassThroughAutocompleteKeyAfterPassthroughObservation(
            snapshot: KeyboardEventTapSnapshot(
                hasVisibleSuggestion: true,
                supportsOneWordAcceptance: true,
                supportsFullAcceptance: true,
                isInvalidatedByUserTyping: true,
                allowsAutocompleteKeyAfterPassthroughObservation: true,
                acceptAllShortcut: .optionTab
            )
        ))

        #expect(!shouldPassThroughAutocompleteKeyAfterPassthroughObservation(
            snapshot: KeyboardEventTapSnapshot(
                hasVisibleSuggestion: true,
                supportsOneWordAcceptance: true,
                supportsFullAcceptance: true,
                isInvalidatedByUserTyping: true,
                acceptAllShortcut: .optionTab
            ),
            passthroughObservationAllowsAutocompleteKey: true
        ))
    }

    @Test("Shortcut chords do not count as text typing passthrough")
    func shortcutChordsDoNotCountAsTextTypingPassthrough() {
        #expect(!shouldTreatOtherKeyAsTypingPassthrough(
            physicalKey: .tab,
            modifiers: [.option]
        ))
        #expect(!shouldTreatOtherKeyAsTypingPassthrough(
            physicalKey: .tab,
            modifiers: [.option, .function]
        ))
        #expect(!shouldTreatOtherKeyAsTypingPassthrough(
            physicalKey: .tab,
            modifiers: [.option, .shift]
        ))
        #expect(!shouldTreatOtherKeyAsTypingPassthrough(
            physicalKey: .z,
            modifiers: [.command, .shift]
        ))
        #expect(shouldTreatOtherKeyAsTypingPassthrough(
            physicalKey: .other,
            modifiers: []
        ))
        #expect(shouldTreatOtherKeyAsTypingPassthrough(
            physicalKey: .other,
            modifiers: [.shift]
        ))
    }

    @Test("Command Z can reach accepted insertion undo routing")
    func commandZReachesUndoRouting() {
        let physicalKey = autocompletePhysicalKey(forMacVirtualKeyCode: 6)
        let mappedKey = AutocompleteKeyMapper().key(
            physicalKey: physicalKey,
            modifiers: [.command]
        )

        let action = KeyboardActionRouter().action(
            for: mappedKey,
            hasVisibleSuggestion: false,
            hasPendingAcceptedInsertionUndo: true
        )

        #expect(mappedKey == .commandZ)
        #expect(action == .undoAcceptedInsertion)
    }

    @Test("Control Backtick can route suggest now while the key tap is active")
    func controlBacktickCanRouteSuggestNowWhileKeyTapIsActive() {
        let physicalKey = autocompletePhysicalKey(forMacVirtualKeyCode: 50)
        let mappedKey = AutocompleteKeyMapper().key(
            physicalKey: physicalKey,
            modifiers: [.control]
        )

        let action = KeyboardActionRouter().action(
            for: mappedKey,
            hasVisibleSuggestion: true
        )

        #expect(mappedKey == .controlBacktick)
        #expect(action == .requestSuggestionNow)
    }

    @Test("Event tap diagnostics include source and target process ids")
    func eventTapDiagnosticsIncludeProcessIDs() throws {
        let event = try #require(CGEvent(
            keyboardEventSource: nil,
            virtualKey: 48,
            keyDown: true
        ))
        event.setIntegerValueField(.eventSourceUnixProcessID, value: 1234)
        event.setIntegerValueField(.eventTargetUnixProcessID, value: 5678)

        let metadata = keyboardEventTapDiagnosticMetadata(event: event)

        #expect(metadata["eventSourcePID"] == "1234")
        #expect(metadata["eventTargetPID"] == "5678")
    }

    @Test("Event tap placement defaults to session and accepts proof HID override")
    func eventTapPlacementUsesProofOverride() {
        let key = KeyboardEventTapPlacement.environmentKey

        #expect(KeyboardEventTapPlacement.fromEnvironment([:]) == .session)
        #expect(KeyboardEventTapPlacement.fromEnvironment([key: "session"]) == .session)
        #expect(KeyboardEventTapPlacement.fromEnvironment([key: "cgSessionEventTap"]) == .session)
        #expect(KeyboardEventTapPlacement.fromEnvironment([key: "hid"]) == .hid)
        #expect(KeyboardEventTapPlacement.fromEnvironment([key: "cgHIDEventTap"]) == .hid)
        #expect(KeyboardEventTapPlacement.fromEnvironment([key: "bogus"]) == .session)
    }

    @Test("Matching keydown bursts shrink without invalidating the event tap snapshot")
    func matchingKeydownBurstShrinksWithoutInvalidation() {
        var snapshot = KeyboardEventTapSnapshot(
            hasVisibleSuggestion: true,
            isInvalidatedByUserTyping: false,
            visibleSuggestionID: "suggestion",
            visibleSuggestionRemainingText: "difficulty"
        )

        #expect(snapshot.advanceOptimisticTypeThrough(typedCharacter: "d")?.remainingText == "ifficulty")
        #expect(snapshot.advanceOptimisticTypeThrough(typedCharacter: "i")?.remainingText == "fficulty")
        #expect(snapshot.advanceOptimisticTypeThrough(typedCharacter: "f")?.remainingText == "ficulty")
        #expect(snapshot.advanceOptimisticTypeThrough(typedCharacter: "f")?.remainingText == "iculty")
        #expect(!snapshot.isInvalidatedByUserTyping)
        #expect(snapshot.optimisticTypedPrefix == "diff")
    }

    @Test("Backspace restores the optimistically consumed suggestion prefix")
    func backspaceRestoresOptimisticPrefix() {
        var snapshot = KeyboardEventTapSnapshot(
            hasVisibleSuggestion: true,
            visibleSuggestionID: "suggestion",
            visibleSuggestionRemainingText: "difficulty"
        )
        _ = snapshot.advanceOptimisticTypeThrough(typedCharacter: "d")
        _ = snapshot.advanceOptimisticTypeThrough(typedCharacter: "i")

        let transition = snapshot.retreatOptimisticTypeThrough()

        #expect(transition?.remainingText == "ifficulty")
        #expect(snapshot.optimisticTypedPrefix == "d")
    }

    @Test("Type-through lifecycle reasons do not count as ignored suggestions")
    func typeThroughReasonsDoNotCountAsIgnored() {
        #expect(suggestionHiddenOutcome(for: "type-through-baselineChanged") == "typed-through")
        #expect(suggestionHiddenOutcome(for: "type-through-textAfterCursorChanged") == "typed-through")
        #expect(suggestionHiddenOutcome(for: "type-through-staleField") == "typed-through")
        #expect(suggestionHiddenOutcome(for: "optimistic-type-through-mismatch") == "typed-through")
        #expect(suggestionHiddenOutcome(for: "hidden") == "ignored")
    }

    @Test("Input methods fail closed while direct keyboard layouts can match optimistically")
    func inputMethodsFailClosedForOptimisticMatching() {
        #expect(keyboardInputSourceTypeAllowsOptimisticTypeThrough(kTISTypeKeyboardLayout as String))
        #expect(!keyboardInputSourceTypeAllowsOptimisticTypeThrough(kTISTypeKeyboardInputMode as String))
        #expect(!keyboardInputSourceTypeAllowsOptimisticTypeThrough(kTISTypeKeyboardInputMethodWithoutModes as String))
    }

    @Test("Matching keydown burst posts shrink callbacks without invalidation")
    func matchingKeydownBurstUsesOptimisticObserver() async throws {
        let observations = EventTapObserverState()
        let eventTap = KeyboardEventTap(
            handler: { _, _, _ in .replayOriginalKey(.noVisibleSuggestion) },
            passthroughKeyDownObserver: {
                observations.recordInvalidation()
            },
            passthroughTypingMatchObserver: { transition in
                observations.recordMatch(remainingText: transition.remainingText)
            }
        )
        eventTap.updateSnapshot(KeyboardEventTapSnapshot(
            hasVisibleSuggestion: true,
            visibleSuggestionID: "suggestion",
            visibleSuggestionRemainingText: "difficulty"
        ))

        for (keyCode, character) in [(2, "d"), (34, "i"), (3, "f"), (3, "f")] {
            let event = try #require(CGEvent(
                keyboardEventSource: nil,
                virtualKey: CGKeyCode(keyCode),
                keyDown: true
            ))
            var utf16 = Array(character.utf16)
            event.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
            _ = eventTap.handle(type: .keyDown, event: event)
        }
        try await waitForEventTapObservation {
            observations.matchCount == 4
                && observations.invalidationCount == 0
                && observations.lastRemainingText == "iculty"
        }

        #expect(observations.matchCount == 4)
        #expect(observations.invalidationCount == 0)
        #expect(observations.lastRemainingText == "iculty")
    }

    @Test("Input-method snapshot disables optimistic matching")
    func inputMethodSnapshotDisablesOptimisticMatching() async throws {
        let observations = EventTapObserverState()
        let eventTap = KeyboardEventTap(
            handler: { _, _, _ in .replayOriginalKey(.noVisibleSuggestion) },
            passthroughKeyDownObserver: { observations.recordInvalidation() },
            passthroughTypingMatchObserver: { transition in
                observations.recordMatch(remainingText: transition.remainingText)
            }
        )
        eventTap.updateSnapshot(KeyboardEventTapSnapshot(
            hasVisibleSuggestion: true,
            visibleSuggestionID: "suggestion",
            visibleSuggestionRemainingText: "difficulty",
            allowsOptimisticTypeThrough: false
        ))
        let event = try #require(CGEvent(
            keyboardEventSource: nil,
            virtualKey: 2,
            keyDown: true
        ))
        var utf16 = Array("d".utf16)
        event.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)

        _ = eventTap.handle(type: .keyDown, event: event)
        try await waitForEventTapObservation {
            observations.invalidationCount == 1
        }

        #expect(observations.matchCount == 0)
        #expect(observations.invalidationCount == 1)
    }
}

private func waitForEventTapObservation(
    _ condition: @escaping @Sendable () -> Bool
) async throws {
    for _ in 0..<500 {
        if condition() {
            return
        }
        try await Task.sleep(for: .milliseconds(10))
    }
}

private final class EventTapObserverState: @unchecked Sendable {
    private let lock = NSLock()
    private var matches = 0
    private var invalidations = 0
    private var remainingText: String?

    var matchCount: Int { withLock { matches } }
    var invalidationCount: Int { withLock { invalidations } }
    var lastRemainingText: String? { withLock { remainingText } }

    func recordMatch(remainingText: String) {
        lock.lock()
        matches += 1
        self.remainingText = remainingText
        lock.unlock()
    }

    func recordInvalidation() {
        lock.lock()
        invalidations += 1
        lock.unlock()
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}
