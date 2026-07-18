// MARK: - Application lifecycle wiring

extension AppDelegate: AppLifecycleHandling {
    func prepareForLaunch() {
        prepareForAppLaunch()
    }

    func startStatusMenu() {
        statusMenuHost.start(pauseSuggestionsTitle: pauseSuggestionsTitle)
    }

    func recordLaunchDiagnostics() {
        recordAppLaunchDiagnostics()
    }

    func requestAccessibilityPermissionIfNeeded() {
        requestAccessibilityPermissionIfNeededAtLaunch()
    }

    func showSettingsIfNeeded() {
        showSettingsIfNeededAtLaunch()
    }

    func startWorkspaceObserver() {
        workspaceObserverHost.start()
    }

    func startSuggestionPipeline() {
        suggestionPipeline.startPolling()
    }

    func startResourceDiagnostics() {
        resourceDiagnosticsHost.start()
    }

    func stopForTermination() {
        stopForAppTermination()
    }
}
