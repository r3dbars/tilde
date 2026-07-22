import Foundation
import AutocompleteLabCore

/// Owns runtime readiness state and the user-facing transitions around warming,
/// repair, and first-run model setup. AppDelegate keeps runtime replacement and
/// model-install mechanics, while this host owns status decisions and one-time
/// Settings guidance.
@MainActor
final class RuntimeStatusHost {
    private weak var appDelegate: AppDelegate?

    private(set) var currentRuntimeState: LocalRuntimeState = .unavailable(reason: "starting")
    private(set) var hasSurfacedModelSetupUI = false
    private(set) var modelInstallStatusText: String?

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
    }

    var runtimeReadinessReport: RuntimeReadinessReport {
        guard let appDelegate else {
            return RuntimeReadinessReport(
                stage: .runtimeUnavailable,
                summary: "Runtime status host unavailable",
                action: .wait
            )
        }
        return appDelegate.modelRuntimeBundle.bootstrapPlan.readinessReport(for: currentRuntimeState)
    }

    var modelInstallStatus: String? {
        modelInstallStatusText
    }

    func setModelInstallStatus(_ statusText: String?) {
        modelInstallStatusText = statusText
    }

    func markRuntimeUnavailable(reason: String) {
        currentRuntimeState = .unavailable(reason: reason)
    }

    func apply(_ state: LocalRuntimeState) {
        guard let appDelegate else {
            return
        }

        let wasReadyForSuggestions = runtimeReadinessReport.allowsSuggestions
        currentRuntimeState = appDelegate.refreshModelAssetState(for: state)
        appDelegate.refreshRuntimeChrome()
        let report = runtimeReadinessReport
        if report.allowsSuggestions,
           !appDelegate.modelInstallLifecycleHost.isInstalling,
           modelInstallStatusText != nil {
            modelInstallStatusText = "Model install: ready"
            appDelegate.refreshRuntimeChrome()
        }
        if !wasReadyForSuggestions && report.allowsSuggestions {
            appDelegate.rearmFocusedTextAfterRuntimeReady()
        }
        if report.stage == .failed || report.action == .repairModel {
            appDelegate.showSettings()
        } else if report.stage == .downloadNeeded, !hasSurfacedModelSetupUI {
            hasSurfacedModelSetupUI = true
            appDelegate.showSettings()
        }
        DiagnosticsLog.shared.record(
            "runtime",
            metadata: [
                "state": state.statusSummary,
                "completionLength": appDelegate.completionLengthConfiguration.displaySummary,
                "readinessStage": report.stage.rawValue,
                "readinessAction": report.action.rawValue
            ]
        )
    }
}
