// MARK: - Workspace observer wiring

extension AppDelegate: WorkspaceObserverEventHandling {
    func handleWorkspaceObserverEvent(_ event: WorkspaceObserverEvent) {
        switch event {
        case let .workspaceFocusChanged(reason, kind, bundleIdentifier):
            handleWorkspaceFocusChange(
                reason: reason,
                kind: kind,
                bundleIdentifier: bundleIdentifier
            )
        case let .suggestionInterruption(kind):
            handleSuggestionInterruption(kind)
        case .screenGeometryChanged:
            handleScreenGeometryChange()
        }
    }
}
