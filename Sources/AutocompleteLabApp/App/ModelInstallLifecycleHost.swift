import Foundation
import AutocompleteLabCore

@MainActor
protocol ModelInstallLifecycleHandling: AnyObject {
    var modelRuntimeBundleForInstall: AppModelRuntimeBundle { get }
    func setModelInstallStatus(_ statusText: String?)
    func refreshModelInstallUI()
    func showModelInstallSettings()
    func reloadModelRuntimeAfterInstall()
}

/// Owns model-download lifecycle wiring while AppDelegate owns runtime state
/// replacement and readiness decisions after installation.
@MainActor
final class ModelInstallLifecycleHost {
    private let installHost: ModelInstallHost
    private weak var handler: (any ModelInstallLifecycleHandling)?

    init(
        handler: any ModelInstallLifecycleHandling,
        installHost: ModelInstallHost = ModelInstallHost()
    ) {
        self.handler = handler
        self.installHost = installHost
    }

    var isInstalling: Bool {
        installHost.isInstalling
    }

    func start() {
        guard let handler, !installHost.isInstalling else {
            return
        }

        let bundle = handler.modelRuntimeBundleForInstall
        let manifest = bundle.bootstrapPlan.preferredAsset
        let destinationURL = bundle.modelDirectoryURL
        handler.setModelInstallStatus("Model install: preparing download")
        handler.refreshModelInstallUI()
        DiagnosticsLog.shared.record(
            "model-install-start",
            metadata: [
                "model": manifest.model.rawValue,
                "repoID": manifest.source?.repoID ?? "",
                "target": destinationURL.path
            ]
        )

        installHost.start(
            manifest: manifest,
            destinationURL: destinationURL,
            onProgress: { [weak self] statusText in
                guard let handler = self?.handler else {
                    return
                }
                handler.setModelInstallStatus(statusText)
                handler.refreshModelInstallUI()
            },
            onSuccess: { [weak self] installedURL in
                guard let handler = self?.handler else {
                    return
                }
                DiagnosticsLog.shared.record(
                    "model-install-succeeded",
                    metadata: [
                        "model": manifest.model.rawValue,
                        "target": installedURL.path
                    ]
                )
                handler.setModelInstallStatus("Model install: warming local runtime")
                handler.reloadModelRuntimeAfterInstall()
            },
            onCancelled: { [weak self] in
                guard let handler = self?.handler else {
                    return
                }
                DiagnosticsLog.shared.record(
                    "model-install-canceled",
                    metadata: [
                        "model": manifest.model.rawValue
                    ]
                )
                handler.setModelInstallStatus("Model install canceled.")
                handler.refreshModelInstallUI()
                handler.showModelInstallSettings()
            },
            onFailure: { [weak self] reason in
                guard let handler = self?.handler else {
                    return
                }
                DiagnosticsLog.shared.record(
                    "model-install-failed",
                    metadata: [
                        "model": manifest.model.rawValue,
                        "reason": reason
                    ]
                )
                handler.setModelInstallStatus("Model install failed: \(reason)")
                handler.refreshModelInstallUI()
                handler.showModelInstallSettings()
            }
        )
    }

    func cancel() {
        guard installHost.isInstalling else {
            return
        }

        guard let handler else {
            installHost.cancel()
            return
        }
        let model = handler.modelRuntimeBundleForInstall.bootstrapPlan.preferredAsset.model.rawValue
        handler.setModelInstallStatus("Model install: canceling")
        DiagnosticsLog.shared.record(
            "model-install-cancel-requested",
            metadata: ["model": model]
        )
        handler.refreshModelInstallUI()
        installHost.cancel()
    }
}
