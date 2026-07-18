// MARK: - Model install lifecycle wiring

extension AppDelegate: ModelInstallLifecycleHandling {
    var modelRuntimeBundleForInstall: AppModelRuntimeBundle {
        modelRuntimeBundle
    }

    func setModelInstallStatus(_ statusText: String?) {
        runtimeStatusHost.setModelInstallStatus(statusText)
    }

    func refreshModelInstallUI() {
        refreshRuntimeChrome()
    }

    func showModelInstallSettings() {
        showSettings()
    }
}
