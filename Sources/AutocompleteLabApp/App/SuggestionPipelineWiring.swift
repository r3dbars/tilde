import AutocompleteLabCore

// MARK: - Suggestion pipeline wiring

extension AppDelegate: SuggestionPipelineHost {
    /// App-computed cadence inputs for the polling driver (relocated from the former
    /// `shouldRunFocusedTextPoll`); the pure cadence policy lives in `SuggestionPipelineController`.
    func focusedTextPollCadenceSignals() -> FocusPollingCadenceSignals {
        let activeApp = accessibilityClient.frontmostApplication()
        let hasSupportedProfile = activeApp.flatMap { app -> Bool? in
            guard let profile = effectiveProfile(for: app) else {
                return false
            }

            return profile.canPresentSuggestions
                && !profile.isSensitive
                && isSuggestionEnabled(for: app, profile: profile)
        } ?? false
        return FocusPollingCadenceSignals(
            isTrustedForAccessibility: accessibilityClient.isTrusted,
            hasSupportedProfile: hasSupportedProfile,
            hasVisibleSuggestion: suggestionSession.hasVisibleSuggestion,
            lastFocusedTextChangeAt: lastFocusedTextChangeAt
        )
    }

    /// Run one focused-text poll (Accessibility read + dispatch). Returns whether the read
    /// completes asynchronously, in which case the controller defers `finishPoll` to the
    /// async completion handler (`completeFocusedTextPoll`).
    func executeFocusedTextPoll(startedAt: UInt64) -> Bool {
        var completesAsync = false
        pollFocusedText(startedAt: startedAt, completesAsync: &completesAsync)
        return completesAsync
    }

    func applyFocusedTextPollingThrottle(_ recommendation: FocusedTextPollingThrottleRecommendation) {
        applyFocusedTextPollingThrottleIfNeeded(recommendation)
    }
}
