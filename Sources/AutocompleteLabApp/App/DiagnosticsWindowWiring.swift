// MARK: - Diagnostics window wiring

extension AppDelegate: DiagnosticsWindowActionHandling {
    func refreshDiagnostics() {
        showDiagnostics()
    }

    func toggleDiagnosticsTracing() {
        toggleTracing()
    }

    func toggleDiagnosticsScreenshotTracing(for bundleIdentifier: String) {
        toggleScreenshotTracing(for: bundleIdentifier)
    }

    func openDiagnosticsTraceFolder() {
        openTraceFolder()
    }

    func exportDiagnosticsTraceReport() {
        exportTraceReport()
    }

    func deleteDiagnosticsTraces() {
        deleteLocalPrivacyLogs(refreshSettings: false)
        showDiagnostics()
    }
}
