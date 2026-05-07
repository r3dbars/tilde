public struct RuntimeReadinessGuidance: Equatable, Sendable {
    public let message: String
    public let actionTitle: String
    public let isActionEnabled: Bool

    public init(report: RuntimeReadinessReport) {
        switch report.stage {
        case .downloadNeeded:
            message = "Model missing: install the app-owned MLX model. Suggestions stay off until this finishes."
            actionTitle = report.action == .installModel ? "Install Model" : "Open Model Folder"
            isActionEnabled = report.action != .none
        case .repairNeeded:
            message = "Model repair needed: repair the app-owned MLX model. Suggestions stay off until the folder is valid."
            actionTitle = report.action == .repairModel ? "Repair Model" : "Open Model Folder"
            isActionEnabled = report.action != .none
        case .runtimeUnavailable:
            message = "Runtime unavailable: this build cannot start the preferred local runtime. Suggestions stay off in this build."
            actionTitle = "Unavailable"
            isActionEnabled = false
        case .warming:
            message = "Model warming: keep the app open for a moment. Suggestions turn on automatically when the local model is ready."
            actionTitle = "Warming..."
            isActionEnabled = false
        case .failed:
            message = "Model failed to start: retry the local model. Suggestions stay off until startup succeeds."
            actionTitle = "Retry Model"
            isActionEnabled = true
        case .ready:
            message = "Ready: open TextEdit, type a short sentence, press Tab for one word, or Esc to dismiss."
            actionTitle = "Ready"
            isActionEnabled = false
        }
    }
}
