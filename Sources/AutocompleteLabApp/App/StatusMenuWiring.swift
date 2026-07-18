// MARK: - Status menu wiring

extension AppDelegate: StatusMenuActionHandling {
    func handleStatusMenuAction(_ action: StatusMenuAction) {
        switch action {
        case .suggestNow:
            requestSuggestionNow(source: "menu")
        case .togglePauseSuggestions:
            togglePauseSuggestions()
        case .pauseSuggestionsFor15Minutes:
            pauseSuggestionsFor15Minutes()
        case .pauseSuggestionsFor1Hour:
            pauseSuggestionsFor1Hour()
        case .pauseSuggestionsUntilTomorrow:
            pauseSuggestionsUntilTomorrowFromControl()
        case .toggleCurrentApp:
            toggleCurrentApp()
        case .silenceCurrentField:
            silenceCurrentField()
        case .showSettings:
            showSettings()
        case .openFeedbackForm:
            openFeedbackForm()
        case .showDiagnostics:
            showDiagnostics()
        case .revealModelFolder:
            revealModelFolder()
        case .revealPersonalCaptureFolder:
            revealPersonalCaptureFolder()
        case .nudgeSuggestionUp:
            nudgeCurrentAppSuggestionUp()
        case .nudgeSuggestionDown:
            nudgeCurrentAppSuggestionDown()
        case .nudgeSuggestionLeft:
            nudgeCurrentAppSuggestionLeft()
        case .nudgeSuggestionRight:
            nudgeCurrentAppSuggestionRight()
        case .resetCurrentAppLearning:
            resetCurrentAppLearning()
        case .quit:
            quit()
        }
    }
}
