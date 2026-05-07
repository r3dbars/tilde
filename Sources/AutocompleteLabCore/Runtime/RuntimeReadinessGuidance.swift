public struct RuntimeReadinessGuidance: Equatable, Sendable {
    public let message: String
    public let actionTitle: String
    public let isActionEnabled: Bool

    public init(report: RuntimeReadinessReport) {
        switch report.stage {
        case .downloadNeeded:
            if report.action == .installLocalModel {
                message = "Model missing: install the app-owned MLX model. Suggestions stay off until the model is valid."
                actionTitle = "Install Local Model"
                isActionEnabled = true
            } else {
                message = "Model missing: open the model folder and add the app-owned MLX model. Suggestions stay off until this is ready."
                actionTitle = "Open Model Folder"
                isActionEnabled = true
            }
        case .repairNeeded:
            if report.action == .repairLocalModel {
                message = "Model repair needed: download the app-owned MLX model again. Suggestions stay off until the folder is valid."
                actionTitle = "Repair Local Model"
                isActionEnabled = true
            } else {
                message = "Model repair needed: open the model folder and replace the incomplete model files. Suggestions stay off until the folder is valid."
                actionTitle = "Open Model Folder"
                isActionEnabled = true
            }
        case .installing:
            message = report.detail ?? "Installing the app-owned MLX model. Keep Autocomplete Lab open."
            actionTitle = "Installing..."
            isActionEnabled = false
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
