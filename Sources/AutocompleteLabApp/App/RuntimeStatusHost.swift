import Foundation
import AutocompleteLabCore

@MainActor
protocol RuntimeStatusHandling: AnyObject {
    var modelRuntimeBundleForStatus: AppModelRuntimeBundle { get }
    var isModelInstallInProgressForStatus: Bool { get }
    var completionLengthDisplaySummaryForStatus: String { get }
    func refreshModelAssetState(for state: LocalRuntimeState) -> LocalRuntimeState
    func refreshRuntimeStatusChrome()
    func rearmFocusedTextAfterRuntimeReadyForStatus()
    func showRuntimeSettings()
}

/// Owns runtime readiness state and the user-facing transitions around warming,
/// repair, and first-run model setup. AppDelegate keeps runtime replacement and
/// model-install mechanics, while this host owns status decisions and one-time
/// Settings guidance.
@MainActor
final class RuntimeStatusHost {
    private weak var handler: (any RuntimeStatusHandling)?

    private(set) var currentRuntimeState: LocalRuntimeState = .unavailable(reason: "starting")
    private(set) var hasSurfacedModelSetupUI = false
    private(set) var modelInstallStatusText: String?

    init(handler: any RuntimeStatusHandling) {
        self.handler = handler
    }

    var runtimeReadinessReport: RuntimeReadinessReport {
        guard let handler else {
            return RuntimeReadinessReport(
                stage: .runtimeUnavailable,
                summary: "Runtime status host unavailable",
                action: .wait
            )
        }
        return handler.modelRuntimeBundleForStatus.bootstrapPlan.readinessReport(for: currentRuntimeState)
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
        guard let handler else {
            return
        }

        let wasReadyForSuggestions = runtimeReadinessReport.allowsSuggestions
        currentRuntimeState = handler.refreshModelAssetState(for: state)
        handler.refreshRuntimeStatusChrome()
        let report = runtimeReadinessReport
        if report.allowsSuggestions,
           !handler.isModelInstallInProgressForStatus,
           modelInstallStatusText != nil {
            modelInstallStatusText = "Model install: ready"
            handler.refreshRuntimeStatusChrome()
        }
        if !wasReadyForSuggestions && report.allowsSuggestions {
            handler.rearmFocusedTextAfterRuntimeReadyForStatus()
        }
        if report.stage == .failed || report.action == .repairModel {
            handler.showRuntimeSettings()
        } else if report.stage == .downloadNeeded, !hasSurfacedModelSetupUI {
            hasSurfacedModelSetupUI = true
            handler.showRuntimeSettings()
        }
        DiagnosticsLog.shared.record(
            "runtime",
            metadata: [
                "state": state.statusSummary,
                "completionLength": handler.completionLengthDisplaySummaryForStatus,
                "readinessStage": report.stage.rawValue,
                "readinessAction": report.action.rawValue
            ]
        )
    }
}
