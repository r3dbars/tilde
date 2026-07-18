import AutocompleteLabCore

/// Owns settings-driven suggestion tuning mutations and their local side effects.
/// AppDelegate provides the native callbacks; this host keeps persistence, cancellation,
/// visible-suggestion cleanup, and tuning metadata in one tested boundary.
@MainActor
final class SuggestionTuningHost {
    private let currentTuning: () -> SuggestionTuning
    private let updateTuning: (SuggestionTuning) -> Void
    private let persistTuning: () -> Void
    private let clearPendingRequest: () -> Void
    private let hasVisibleSuggestion: () -> Bool
    private let hideSuggestion: (String) -> Void
    private let setSuggestionDecision: (String) -> Void
    private let refreshRuntimeChrome: () -> Void

    init(
        currentTuning: @escaping () -> SuggestionTuning,
        updateTuning: @escaping (SuggestionTuning) -> Void,
        persistTuning: @escaping () -> Void,
        clearPendingRequest: @escaping () -> Void,
        hasVisibleSuggestion: @escaping () -> Bool,
        hideSuggestion: @escaping (String) -> Void,
        setSuggestionDecision: @escaping (String) -> Void,
        refreshRuntimeChrome: @escaping () -> Void
    ) {
        self.currentTuning = currentTuning
        self.updateTuning = updateTuning
        self.persistTuning = persistTuning
        self.clearPendingRequest = clearPendingRequest
        self.hasVisibleSuggestion = hasVisibleSuggestion
        self.hideSuggestion = hideSuggestion
        self.setSuggestionDecision = setSuggestionDecision
        self.refreshRuntimeChrome = refreshRuntimeChrome
    }

    func setAggressivenessLevel(_ level: Int) {
        set(updatedTuning(aggressivenessLevel: level), reason: "aggressiveness-changed")
    }

    func setMaxVisibleWords(_ words: Int) {
        set(updatedTuning(maxVisibleWords: words), reason: "max-visible-words-changed")
    }

    func setWordStartCharacters(_ characters: Int) {
        set(updatedTuning(wordStartCharacters: characters), reason: "word-start-characters-changed")
    }

    func setPhraseStartWords(_ words: Int) {
        set(updatedTuning(phraseStartWords: words), reason: "phrase-start-words-changed")
    }

    func setResponseSpeedLevel(_ level: Int) {
        set(updatedTuning(responseSpeedLevel: level), reason: "response-speed-changed")
    }

    func setConfidenceLevel(_ level: Int) {
        set(updatedTuning(confidenceLevel: level), reason: "confidence-changed")
    }

    func setLearningRestraintLevel(_ level: Int) {
        set(updatedTuning(learningRestraintLevel: level), reason: "learning-restraint-changed")
    }

    func reset() {
        set(SuggestionTuning(), reason: "reset-tuning")
    }

    private func updatedTuning(
        aggressivenessLevel: Int? = nil,
        maxVisibleWords: Int? = nil,
        wordStartCharacters: Int? = nil,
        phraseStartWords: Int? = nil,
        responseSpeedLevel: Int? = nil,
        confidenceLevel: Int? = nil,
        learningRestraintLevel: Int? = nil
    ) -> SuggestionTuning {
        let current = currentTuning()
        return SuggestionTuning(
            aggressivenessLevel: aggressivenessLevel ?? current.aggressivenessLevel,
            maxVisibleWords: maxVisibleWords ?? current.maxVisibleWords,
            wordStartCharacters: wordStartCharacters ?? current.wordStartCharacters,
            phraseStartWords: phraseStartWords ?? current.phraseStartWords,
            responseSpeedLevel: responseSpeedLevel ?? current.responseSpeedLevel,
            confidenceLevel: confidenceLevel ?? current.confidenceLevel,
            learningRestraintLevel: learningRestraintLevel ?? current.learningRestraintLevel
        )
    }

    private func set(_ next: SuggestionTuning, reason: String) {
        let current = currentTuning()
        guard next != current else {
            refreshRuntimeChrome()
            return
        }

        updateTuning(next)
        persistTuning()
        clearPendingRequest()
        if hasVisibleSuggestion() {
            hideSuggestion(reason)
        }
        setSuggestionDecision("Ready: \(next.displayName.lowercased()) suggestions")
        DiagnosticsLog.shared.record(
            "suggestion-tuning-control",
            metadata: [
                "surface": "settings",
                "suggestionAggressivenessLevel": String(next.aggressivenessLevel),
                "suggestionAggressiveness": next.legacyAggressiveness.rawValue,
                "suggestionMaxVisibleWords": String(next.maxVisibleWords),
                "suggestionWordStartCharacters": String(next.wordStartCharacters),
                "suggestionPhraseStartWords": String(next.phraseStartWords),
                "suggestionResponseSpeedLevel": String(next.responseSpeedLevel),
                "suggestionConfidenceLevel": String(next.confidenceLevel),
                "suggestionLearningRestraintLevel": String(next.learningRestraintLevel),
                "reason": reason
            ]
        )
        refreshRuntimeChrome()
    }
}
