import Foundation
import AutocompleteLabCore

/// Owns model-download lifecycle wiring while AppDelegate owns runtime state
/// replacement and readiness decisions after installation.
@MainActor
final class ModelInstallLifecycleHost {
    private let installHost: ModelInstallHost
    private weak var appDelegate: AppDelegate?

    init(
        appDelegate: AppDelegate,
        installHost: ModelInstallHost = ModelInstallHost()
    ) {
        self.appDelegate = appDelegate
        self.installHost = installHost
    }

    var isInstalling: Bool {
        installHost.isInstalling
    }

    func start() {
        guard let appDelegate, !installHost.isInstalling else {
            return
        }

        let bundle = appDelegate.modelRuntimeBundle
        let manifest = bundle.bootstrapPlan.preferredAsset
        let destinationURL = bundle.modelDirectoryURL
        appDelegate.runtimeStatusHost.setModelInstallStatus("Model install: preparing download")
        appDelegate.refreshRuntimeChrome()
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
                guard let appDelegate = self?.appDelegate else {
                    return
                }
                appDelegate.runtimeStatusHost.setModelInstallStatus(statusText)
                appDelegate.refreshRuntimeChrome()
            },
            onSuccess: { [weak self] installedURL in
                guard let appDelegate = self?.appDelegate else {
                    return
                }
                DiagnosticsLog.shared.record(
                    "model-install-succeeded",
                    metadata: [
                        "model": manifest.model.rawValue,
                        "target": installedURL.path
                    ]
                )
                appDelegate.runtimeStatusHost.setModelInstallStatus("Model install: warming local runtime")
                appDelegate.reloadModelRuntimeAfterInstall()
            },
            onCancelled: { [weak self] in
                guard let appDelegate = self?.appDelegate else {
                    return
                }
                DiagnosticsLog.shared.record(
                    "model-install-canceled",
                    metadata: [
                        "model": manifest.model.rawValue
                    ]
                )
                appDelegate.runtimeStatusHost.setModelInstallStatus("Model install canceled.")
                appDelegate.refreshRuntimeChrome()
                appDelegate.showSettings()
            },
            onFailure: { [weak self] reason in
                guard let appDelegate = self?.appDelegate else {
                    return
                }
                DiagnosticsLog.shared.record(
                    "model-install-failed",
                    metadata: [
                        "model": manifest.model.rawValue,
                        "reason": reason
                    ]
                )
                appDelegate.runtimeStatusHost.setModelInstallStatus("Model install failed: \(reason)")
                appDelegate.refreshRuntimeChrome()
                appDelegate.showSettings()
            }
        )
    }

    func cancel() {
        guard installHost.isInstalling else {
            return
        }

        guard let appDelegate else {
            installHost.cancel()
            return
        }
        let model = appDelegate.modelRuntimeBundle.bootstrapPlan.preferredAsset.model.rawValue
        appDelegate.runtimeStatusHost.setModelInstallStatus("Model install: canceling")
        DiagnosticsLog.shared.record(
            "model-install-cancel-requested",
            metadata: ["model": model]
        )
        appDelegate.refreshRuntimeChrome()
        installHost.cancel()
    }
}
