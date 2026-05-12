public struct RuntimeReadinessGuidance: Equatable, Sendable {
    public let message: String
    public let actionTitle: String
    public let isActionEnabled: Bool

    public init(report: RuntimeReadinessReport) {
        switch report.stage {
        case .downloadNeeded:
            message = "Install the local model here. The download uses one pinned Hugging Face revision, then suggestions run locally. You do not need Ollama or a model server. Suggestions stay off until this finishes."
            actionTitle = report.action == .installModel ? report.action.displayName : RuntimeReadinessAction.revealModelFolder.displayName
            isActionEnabled = report.action != .none
        case .repairNeeded:
            message = "The local model files look incomplete. Repair them here so the app can recheck the files before suggestions turn on."
            actionTitle = report.action == .repairModel ? report.action.displayName : RuntimeReadinessAction.revealModelFolder.displayName
            isActionEnabled = report.action != .none
        case .runtimeUnavailable:
            message = "This build is missing its local model engine. Starting Ollama or another model server will not fix it."
            actionTitle = "Unavailable"
            isActionEnabled = false
        case .warming:
            message = "Model warming: keep the app open for a moment. Suggestions turn on automatically when the local model is ready."
            actionTitle = "Warming..."
            isActionEnabled = false
        case .failed:
            message = "The local model did not start. Retry here. Suggestions stay off until startup succeeds."
            actionTitle = "Retry Model"
            isActionEnabled = true
        case .ready:
            message = "Ready: use Practice to open TextEdit, try Tab for one word, press Esc to dismiss, then pause or delete traces."
            actionTitle = "Ready"
            isActionEnabled = false
        }
    }
}
