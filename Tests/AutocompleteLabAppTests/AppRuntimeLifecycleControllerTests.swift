import Foundation
import Testing
import AutocompleteLabCore
@testable import AutocompleteLabApp

@Suite("App runtime lifecycle controller")
struct AppRuntimeLifecycleControllerTests {
    @Test("Installing progress owns runtime readiness copy")
    @MainActor
    func installingProgressOwnsRuntimeReadinessCopy() {
        let controller = AppRuntimeLifecycleController(
            runtimeBundle: makeBundle(),
            modelInstallProgress: LocalModelInstallProgress(completedUnitCount: 1, totalUnitCount: 4)
        )

        let report = controller.readinessReport

        #expect(report.stage == .installing)
        #expect(report.summary == "installing Qwen3.5 4B 25%")
        #expect(report.detail == "Downloading to /tmp/autocomplete-runtime-test-model")
        #expect(report.action == .wait)
        #expect(controller.runtimeMenuTitle.contains("installing Qwen3.5 4B 25%"))
    }

    @Test("Ready state requests focused text rearm once suggestions become allowed")
    @MainActor
    func readyStateRequestsFocusedTextRearmOnceSuggestionsBecomeAllowed() {
        let controller = AppRuntimeLifecycleController(runtimeBundle: makeBundle())

        let application = controller.applyRuntimeState(.ready(candidate: .mlx))

        #expect(application.report.stage == .ready)
        #expect(application.report.allowsSuggestions)
        #expect(application.shouldRearmFocusedText)
        #expect(!application.shouldShowSettings)
        #expect(application.diagnosticsMetadata["readinessStage"] == "ready")
        #expect(application.diagnosticsMetadata["readinessAction"] == "none")
        #expect(application.diagnosticsMetadata["completionLength"] == CompletionLengthConfiguration.default.displaySummary)
    }

    @Test("Failed state asks the app to show runtime settings")
    @MainActor
    func failedStateAsksTheAppToShowRuntimeSettings() {
        let controller = AppRuntimeLifecycleController(runtimeBundle: makeBundle())

        let application = controller.applyRuntimeState(.failed(candidate: .mlx, reason: "load failed"))

        #expect(application.report.stage == .failed)
        #expect(application.report.action == .retry)
        #expect(!application.report.allowsSuggestions)
        #expect(!application.shouldRearmFocusedText)
        #expect(application.shouldShowSettings)
        #expect(application.diagnosticsMetadata["state"] == "MLX failed: load failed")
    }

    private func makeBundle() -> AppModelRuntimeBundle {
        let modelPath = "/tmp/autocomplete-runtime-test-model"
        let plan = RuntimeBootstrapPlan(
            preferredAsset: .qwen35FourBMLX,
            assetState: .available(path: modelPath),
            nativeRuntimeAvailable: true
        )

        return AppModelRuntimeBundle(
            runtime: MockModelRuntime(candidate: plan.activeCandidate),
            bootstrapPlan: plan,
            modelDirectoryURL: URL(fileURLWithPath: modelPath, isDirectory: true),
            modelOverrideName: nil,
            experimentArm: .length3Word,
            lengthConfiguration: .default
        )
    }
}
