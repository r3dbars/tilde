// MARK: - Runtime status wiring

extension AppDelegate: RuntimeStatusHandling {
    var modelRuntimeBundleForStatus: AppModelRuntimeBundle {
        modelRuntimeBundle
    }

    var isModelInstallInProgressForStatus: Bool {
        modelInstallLifecycleHost.isInstalling
    }

    var completionLengthDisplaySummaryForStatus: String {
        completionLengthConfiguration.displaySummary
    }

    func refreshRuntimeStatusChrome() {
        refreshRuntimeChrome()
    }

    func rearmFocusedTextAfterRuntimeReadyForStatus() {
        rearmFocusedTextAfterRuntimeReady()
    }

    func showRuntimeSettings() {
        showSettings()
    }
}
