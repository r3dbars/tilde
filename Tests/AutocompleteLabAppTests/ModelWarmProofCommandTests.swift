import Testing
@testable import AutocompleteLabApp

@Suite("Model warm proof command")
struct ModelWarmProofCommandTests {
    @Test("Warm proof requires an explicit command flag")
    func warmProofRequiresExplicitFlag() {
        #expect(ModelWarmProofCommand.isRequested(arguments: ["SteadyType", "--model-warm-proof"]))
        #expect(!ModelWarmProofCommand.isRequested(arguments: ["SteadyType"]))
    }
}
