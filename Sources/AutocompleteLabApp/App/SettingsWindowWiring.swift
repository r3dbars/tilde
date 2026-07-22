// MARK: - Settings window wiring

extension AppDelegate: SettingsWindowActionHandling {
    func handleSettingsWindowAction(_ action: SettingsWindowAction) {
        switch action {
        case .requestPermission:
            requestAccessibilityPermission()
        case .openAccessibilitySettings:
            openAccessibilitySettings()
        case .toggleSuggestionsPaused:
            togglePauseSuggestions()
        case .pauseSuggestionsFor15Minutes:
            pauseSuggestionsFor15Minutes()
        case .pauseSuggestionsFor1Hour:
            pauseSuggestionsFor1Hour()
        case .pauseSuggestionsUntilTomorrow:
            pauseSuggestionsUntilTomorrowFromControl()
        case .silenceCurrentField:
            silenceCurrentField()
        case let .performRuntimeAction(action):
            performRuntimeAction(action)
        case .toggleCurrentApp:
            toggleCurrentApp()
        case .toggleCurrentAppMirrorMode:
            toggleCurrentAppMirrorMode()
        case .startCurrentAppProof:
            startCurrentAppProof()
        case .startTextEditPractice:
            startTextEditPractice()
        case .enableAllApps:
            enableAllDisabledApps()
        case .toggleTracingPaused:
            toggleSettingsTracingPaused()
        case .toggleRawContentTracing:
            toggleRawContentTracing()
        case .toggleScreenshotTracing:
            toggleGlobalScreenshotTracing()
        case .toggleVisiblePageContext:
            toggleVisiblePageContext()
        case .deleteLocalLogs:
            deleteLocalPrivacyLogs()
        case .clearLearningData:
            clearLearningData()
        case .exportPrivacyBundle:
            exportTraceReport()
        case .cycleAcceptAllShortcut:
            cycleAcceptAllShortcut()
        case let .setAcceptAllShortcut(shortcut):
            setAcceptAllShortcut(shortcut)
        case let .setSuggestionAggressivenessLevel(level):
            setSuggestionAggressivenessLevel(level)
        case let .setSuggestionMaxVisibleWords(words):
            setSuggestionMaxVisibleWords(words)
        case let .setSuggestionWordStartCharacters(characters):
            setSuggestionWordStartCharacters(characters)
        case let .setSuggestionPhraseStartWords(words):
            setSuggestionPhraseStartWords(words)
        case let .setSuggestionResponseSpeedLevel(level):
            setSuggestionResponseSpeedLevel(level)
        case let .setSuggestionConfidenceLevel(level):
            setSuggestionConfidenceLevel(level)
        case let .setSuggestionLearningRestraintLevel(level):
            setSuggestionLearningRestraintLevel(level)
        case .resetSuggestionTuning:
            resetSuggestionTuning()
        }
    }
}
