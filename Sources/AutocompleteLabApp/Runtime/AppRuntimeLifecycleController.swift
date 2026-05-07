import AutocompleteLabCore
import Foundation

struct AppRuntimeStateApplication: Equatable {
    let state: LocalRuntimeState
    let report: RuntimeReadinessReport
    let shouldRearmFocusedText: Bool
    let shouldShowSettings: Bool
    let diagnosticsMetadata: [String: String]
}

@MainActor
final class AppRuntimeLifecycleController {
    private let installer: LocalModelInstaller
    private let makeRuntime: () -> AppModelRuntimeBundle
    private var runtimeBundle: AppModelRuntimeBundle
    private var runtimeWarmTask: Task<Void, Never>?
    private var modelInstallTask: Task<Void, Never>?
    private var modelInstallProgress: LocalModelInstallProgress?
    private var currentRuntimeState: LocalRuntimeState

    private(set) var engine: any CompletionEngine

    init(
        installer: LocalModelInstaller = LocalModelInstaller(),
        runtimeBundle: AppModelRuntimeBundle = AppModelRuntimeFactory.makeRuntime(),
        modelInstallProgress: LocalModelInstallProgress? = nil,
        makeRuntime: @escaping () -> AppModelRuntimeBundle = { AppModelRuntimeFactory.makeRuntime() }
    ) {
        self.installer = installer
        self.runtimeBundle = runtimeBundle
        self.modelInstallProgress = modelInstallProgress
        self.makeRuntime = makeRuntime
        self.currentRuntimeState = .unavailable(reason: "starting")
        self.engine = RuntimeBackedCompletionEngine(runtime: runtimeBundle.runtime)
    }

    var bootstrapMetadata: [String: String] {
        runtimeBundle.diagnosticsMetadata
    }

    var completionLengthConfiguration: CompletionLengthConfiguration {
        runtimeBundle.lengthConfiguration
    }

    var modelDirectoryURL: URL {
        runtimeBundle.modelDirectoryURL
    }

    var modelDirectoryPath: String {
        modelDirectoryURL.path
    }

    var runtimeTargetSummary: String {
        "\(runtimeBundle.bootstrapPlan.preferredAsset.model.rawValue) • \(completionLengthConfiguration.displaySummary)"
    }

    var runtimeMenuTitle: String {
        "Model: \(runtimeBundle.bootstrapPlan.preferredAsset.model.rawValue) • \(readinessReport.summary) • \(completionLengthConfiguration.displaySummary)"
    }

    var readinessReport: RuntimeReadinessReport {
        if let modelInstallProgress {
            return RuntimeReadinessReport(
                stage: .installing,
                summary: "installing \(runtimeBundle.bootstrapPlan.preferredAsset.model.rawValue) \(modelInstallProgress.percentageText)",
                detail: "Downloading to \(modelDirectoryPath)",
                action: .wait
            )
        }

        return runtimeBundle.bootstrapPlan.readinessReport(for: currentRuntimeState)
    }

    func cancel() {
        runtimeWarmTask?.cancel()
        modelInstallTask?.cancel()
        runtimeBundle.runtime.cancel()
    }

    func warmModelRuntime(
        onStateApplied: @escaping @MainActor (AppRuntimeStateApplication) -> Void
    ) {
        let candidate = runtimeBundle.activeCandidate
        let runtime = runtimeBundle.runtime

        onStateApplied(applyRuntimeState(.warming(candidate: candidate)))
        DiagnosticsLog.shared.record(
            "runtime-warm-start",
            metadata: [
                "candidate": candidate.rawValue,
                "modelDirectory": modelDirectoryPath
            ]
        )

        runtimeWarmTask?.cancel()
        runtimeWarmTask = Task { [weak self, runtime, candidate] in
            do {
                try await runtime.warm()
            } catch {
                await MainActor.run {
                    DiagnosticsLog.shared.record(
                        "runtime-warm-failed",
                        metadata: [
                            "candidate": candidate.rawValue,
                            "reason": error.localizedDescription
                        ]
                    )
                    guard let self else {
                        return
                    }

                    onStateApplied(self.applyRuntimeState(.failed(candidate: candidate, reason: error.localizedDescription)))
                }
                return
            }

            let state = await runtime.state
            await MainActor.run {
                DiagnosticsLog.shared.record(
                    "runtime-warm-succeeded",
                    metadata: [
                        "candidate": candidate.rawValue,
                        "state": state.statusSummary
                    ]
                )
                guard let self else {
                    return
                }

                onStateApplied(self.applyRuntimeState(state))
            }
        }
    }

    func reloadModelRuntime(
        reason: String,
        onBootstrap: @escaping @MainActor ([String: String]) -> Void,
        refreshChrome: @escaping @MainActor () -> Void,
        onStateApplied: @escaping @MainActor (AppRuntimeStateApplication) -> Void
    ) {
        runtimeWarmTask?.cancel()
        runtimeBundle.runtime.cancel()
        runtimeBundle = makeRuntime()
        engine = RuntimeBackedCompletionEngine(runtime: runtimeBundle.runtime)
        currentRuntimeState = .unavailable(reason: reason)

        var metadata = runtimeBundle.diagnosticsMetadata
        metadata["reason"] = reason
        onBootstrap(metadata)
        refreshChrome()
        warmModelRuntime(onStateApplied: onStateApplied)
    }

    func installLocalModel(
        action: RuntimeReadinessAction,
        refreshChrome: @escaping @MainActor () -> Void,
        showSettings: @escaping @MainActor () -> Void,
        onBootstrap: @escaping @MainActor ([String: String]) -> Void,
        onStateApplied: @escaping @MainActor (AppRuntimeStateApplication) -> Void
    ) {
        guard modelInstallTask == nil else {
            return
        }

        let manifest = runtimeBundle.bootstrapPlan.preferredAsset
        let destination = runtimeBundle.modelDirectoryURL
        modelInstallProgress = LocalModelInstallProgress(completedUnitCount: 0, totalUnitCount: 0)
        refreshChrome()
        DiagnosticsLog.shared.record(
            "model-install-start",
            metadata: [
                "action": action.rawValue,
                "model": manifest.model.rawValue,
                "repo": manifest.source?.repoID ?? "",
                "destination": destination.path
            ]
        )

        let installer = installer
        modelInstallTask = Task { [weak self, installer, manifest, destination, action] in
            do {
                _ = try await installer.install(
                    manifest: manifest,
                    to: destination,
                    progressHandler: { [weak self] progress in
                        guard let self else {
                            return
                        }

                        self.modelInstallProgress = progress
                        refreshChrome()
                    }
                )

                await MainActor.run {
                    guard let self else {
                        return
                    }

                    DiagnosticsLog.shared.record(
                        "model-install-complete",
                        metadata: [
                            "action": action.rawValue,
                            "model": manifest.model.rawValue,
                            "destination": destination.path
                        ]
                    )
                    self.modelInstallTask = nil
                    self.modelInstallProgress = nil
                    self.reloadModelRuntime(
                        reason: "model install complete",
                        onBootstrap: onBootstrap,
                        refreshChrome: refreshChrome,
                        onStateApplied: onStateApplied
                    )
                }
            } catch is CancellationError {
                await MainActor.run {
                    guard let self else {
                        return
                    }

                    DiagnosticsLog.shared.record(
                        "model-install-cancelled",
                        metadata: [
                            "action": action.rawValue,
                            "model": manifest.model.rawValue
                        ]
                    )
                    self.modelInstallTask = nil
                    self.modelInstallProgress = nil
                    refreshChrome()
                }
            } catch {
                await MainActor.run {
                    guard let self else {
                        return
                    }

                    DiagnosticsLog.shared.record(
                        "model-install-failed",
                        metadata: [
                            "action": action.rawValue,
                            "model": manifest.model.rawValue,
                            "reason": error.localizedDescription
                        ]
                    )
                    self.modelInstallTask = nil
                    self.modelInstallProgress = nil
                    refreshChrome()
                    showSettings()
                }
            }
        }
    }

    func applyRuntimeState(_ state: LocalRuntimeState) -> AppRuntimeStateApplication {
        let wasReadyForSuggestions = readinessReport.allowsSuggestions
        currentRuntimeState = state
        let report = readinessReport
        return AppRuntimeStateApplication(
            state: state,
            report: report,
            shouldRearmFocusedText: !wasReadyForSuggestions && report.allowsSuggestions,
            shouldShowSettings: report.stage == .failed,
            diagnosticsMetadata: [
                "state": state.statusSummary,
                "completionLength": completionLengthConfiguration.displaySummary,
                "readinessStage": report.stage.rawValue,
                "readinessAction": report.action.rawValue
            ]
        )
    }
}
