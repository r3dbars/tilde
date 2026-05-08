public struct RuntimeReadinessGuidance: Equatable, Sendable {
    public let message: String
    public let actionTitle: String
    public let isActionEnabled: Bool

    public init(report: RuntimeReadinessReport) {
        switch report.stage {
        case .downloadNeeded:
            message = "Install the local model here. The download uses Hugging Face once; suggestions run locally after install. You do not need Ollama or a model server. Suggestions stay off until this finishes."
            actionTitle = report.action == .installModel ? "Install Model" : "Open Model Folder"
            isActionEnabled = report.action != .none
        case .repairNeeded:
            message = "The local model files look incomplete. Repair them here. Suggestions stay off until the files are valid."
            actionTitle = report.action == .repairModel ? "Repair Model" : "Open Model Folder"
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
            message = "Ready: open TextEdit, turn on suggestions for TextEdit, type a short sentence, press Tab for one word, or Esc to dismiss."
            actionTitle = "Ready"
            isActionEnabled = false
        }
    }
}
