import Foundation
import Testing
import AutocompleteLabCore
@testable import AutocompleteLabApp

@Suite("App model runtime factory")
struct AppModelRuntimeFactoryTests {
    @Test("Migrates old one-word experiment assignment to the longer default")
    func migratesOneWordExperimentAssignment() {
        let defaults = temporaryDefaults()
        defaults.set("length_1_word", forKey: AppModelRuntimeFactory.experimentArmDefaultsKey)

        let bundle = AppModelRuntimeFactory.makeRuntime(environment: [:], defaults: defaults)

        #expect(bundle.experimentArm == .length3Word)
        #expect(bundle.lengthConfiguration.maxVisibleWords == 5)
        #expect(bundle.lengthConfiguration.maxGeneratedTokens == 11)
        #expect(defaults.string(forKey: AppModelRuntimeFactory.experimentArmDefaultsKey) == "length_3_word")
    }

    @Test("Keeps explicit one-word environment override")
    func keepsExplicitOneWordEnvironmentOverride() {
        let defaults = temporaryDefaults()

        let bundle = AppModelRuntimeFactory.makeRuntime(
            environment: ["AUTOCOMPLETE_LAB_EXPERIMENT_ARM": "length_1_word"],
            defaults: defaults
        )

        #expect(bundle.experimentArm == .length1Word)
        #expect(bundle.lengthConfiguration.maxVisibleWords == 1)
        #expect(bundle.lengthConfiguration.maxGeneratedTokens == 4)
        #expect(defaults.string(forKey: AppModelRuntimeFactory.experimentArmDefaultsKey) == "length_1_word")
    }

    @Test("Uses SteadyType model root override and unavailable runtime for missing model")
    func usesModelRootOverrideAndUnavailableRuntimeForMissingModel() async {
        let defaults = temporaryDefaults()
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("steadytype-model-root-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let bundle = AppModelRuntimeFactory.makeRuntime(
            environment: ["AUTOCOMPLETE_LAB_MODEL_ROOT": rootURL.path],
            defaults: defaults
        )

        #expect(bundle.modelDirectoryURL.path.contains("/Models/Qwen35FourB/MLX/Qwen3.5-4B-4bit"))
        #expect(bundle.bootstrapPlan.activeCandidate == .unavailable)
        #expect(bundle.bootstrapPlan.assetState.statusSummary.contains("missing model asset"))
        #expect(await bundle.runtime.state == .unavailable(reason: bundle.bootstrapPlan.unavailableReason ?? ""))
    }

    private func temporaryDefaults() -> UserDefaults {
        let suiteName = "autocomplete-app-model-runtime-factory-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
