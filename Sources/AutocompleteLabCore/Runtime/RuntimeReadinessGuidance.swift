public struct RuntimeReadinessGuidance: Equatable, Sendable {
    public let message: String
    public let actionTitle: String
    public let isActionEnabled: Bool

    public init(report: RuntimeReadinessReport) {
        switch report.stage {
        case .downloadNeeded:
            message = "Model missing: install the app-owned Qwen3.5 4B MLX model. Do not start Ollama, llama.cpp, or a separate model server. Suggestions stay off until this is ready."
            actionTitle = "Install Model"
            isActionEnabled = true
        case .repairNeeded:
            message = "Model repair needed: replace the incomplete app-owned MLX files from inside Autocomplete Lab. Do not start Ollama, llama.cpp, or a separate model server. Suggestions stay off until the folder is valid."
            actionTitle = "Repair Model"
            isActionEnabled = true
        case .runtimeUnavailable:
            message = "Runtime unavailable: this build cannot start the app-owned MLX runtime. Suggestions stay off in this build."
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
