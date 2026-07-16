import Foundation
import Testing
import AutocompleteLabCore
@testable import AutocompleteLabApp

@Suite("Model warm proof command")
struct ModelWarmProofCommandTests {
    @Test("Warm proof requires an explicit command flag")
    func warmProofRequiresExplicitFlag() {
        #expect(ModelWarmProofCommand.isRequested(arguments: ["SteadyType", "--model-warm-proof"]))
        #expect(!ModelWarmProofCommand.isRequested(arguments: ["SteadyType"]))
    }

    @Test("Warm proof succeeds only when the runtime reaches MLX ready")
    func warmProofRequiresMLXReady() async {
        let readyRuntime = MockModelRuntime(candidate: .mlx)
        let wrongCandidateRuntime = MockModelRuntime(candidate: .mock)

        #expect(await ModelWarmProofCommand.run(
            bundle: bundle(runtime: readyRuntime)
        ) == 0)
        #expect(await ModelWarmProofCommand.run(
            bundle: bundle(runtime: wrongCandidateRuntime)
        ) == 1)
    }

    private func bundle(runtime: any ModelRuntime) -> AppModelRuntimeBundle {
        let manifest = LocalModelAssetManifest.qwen35FourBMLX
        return AppModelRuntimeBundle(
            runtime: runtime,
            bootstrapPlan: RuntimeBootstrapPlan(
                preferredAsset: manifest,
                assetState: .available(path: "/synthetic/model"),
                nativeRuntimeAvailable: true
            ),
            modelDirectoryURL: URL(fileURLWithPath: "/synthetic/model", isDirectory: true),
            modelOverrideName: nil,
            experimentArm: .length3Word,
            lengthConfiguration: .default
        )
    }
}
