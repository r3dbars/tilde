import Testing
@testable import AutocompleteLabCore

@Suite("Keyboard capture safety policy")
struct KeyboardCaptureSafetyPolicyTests {
    @Test("Acceptance blocks replay the original captured key")
    func acceptanceBlocksReplayOriginalCapturedKey() {
        let policy = KeyboardCaptureSafetyPolicy()
        let blockReasons: [SuggestionAcceptanceBlockReason] = [
            .appChanged,
            .fieldChanged,
            .selectedTextChanged,
            .textBeforeCursorChanged,
            .textAfterCursorChanged,
            .missingShownSnapshot,
            .missingCurrentSnapshot,
            .currentBecameSecure,
            .promptTargetChanged,
            .targetFingerprintChanged
        ]

        for reason in blockReasons {
            #expect(
                policy.handlingResult(forAcceptanceBlock: reason)
                    == .replayOriginalKey(.acceptanceTargetChanged)
            )
        }
    }

    @Test("Unsafe acceptance failures drop the original captured key")
    func unsafeAcceptanceFailuresDropOriginalCapturedKey() {
        let policy = KeyboardCaptureSafetyPolicy()
        let failureReasons: [KeyboardCaptureDropReason] = [
            .missingAcceptedText,
            .acceptanceProofFailed,
            .insertionFailed,
            .unsafeAcceptedText
        ]

        for reason in failureReasons {
            let result = policy.handlingResult(forAcceptanceFailure: reason)

            #expect(result == .dropOriginalKey(reason))
            #expect(!result.didHandle)
        }
    }

    @Test("Repeated Tab is suppressed only inside the replay guard window")
    func repeatedTabIsSuppressedOnlyInsideReplayGuardWindow() {
        let policy = KeyboardCaptureRepeatSuppressionPolicy(suppressDurationNanos: 100)

        #expect(
            policy.suppressionDeadline(
                shouldConsume: true,
                isAutorepeat: false,
                nowNanos: 1_000
            ) == 1_100
        )
        #expect(
            policy.shouldSuppressAutorepeat(
                key: .tab,
                isAutorepeat: true,
                suppressedUntilNanos: 1_100,
                nowNanos: 1_050
            )
        )
        #expect(
            !policy.shouldSuppressAutorepeat(
                key: .tab,
                isAutorepeat: true,
                suppressedUntilNanos: 1_100,
                nowNanos: 1_100
            )
        )
        #expect(
            !policy.shouldSuppressAutorepeat(
                key: .other,
                isAutorepeat: true,
                suppressedUntilNanos: 1_100,
                nowNanos: 1_050
            )
        )
        #expect(
            policy.suppressionDeadline(
                shouldConsume: true,
                isAutorepeat: true,
                nowNanos: 1_000
            ) == nil
        )
    }

    @Test("Escape dismissal handles the key without inserting suggestion text")
    func escapeDismissalHandlesKeyWithoutInsertingSuggestionText() {
        let router = KeyboardActionRouter()

        #expect(router.action(for: .escape, hasVisibleSuggestion: true) == .dismiss)
        #expect(!KeyboardAction.dismiss.insertsSuggestionText)
        #expect(router.action(for: .escape, hasVisibleSuggestion: false) == .passThrough)
    }

    @Test("Fast typing invalidation passes autocomplete keys through")
    func fastTypingInvalidationPassesAutocompleteKeysThrough() {
        let policy = KeyboardEventTapConsumptionPolicy()

        for (key, shortcut) in [
            (AutocompleteKey.tab, AcceptAllShortcut.backtick),
            (.backtick, .backtick),
            (.optionTab, .optionTab),
            (.escape, .backtick)
        ] {
            #expect(!policy.shouldConsume(KeyboardEventTapConsumptionInput(
                key: key,
                hasVisibleSuggestion: true,
                supportsOneWordAcceptance: true,
                supportsFullAcceptance: true,
                isInvalidatedByUserTyping: true,
                acceptAllShortcut: shortcut
            )))
        }
    }
}
