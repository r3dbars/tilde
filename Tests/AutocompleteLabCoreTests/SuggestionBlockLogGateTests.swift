import Testing
@testable import AutocompleteLabCore

@Suite("Suggestion block log gate")
struct SuggestionBlockLogGateTests {
    @Test("Suppresses repeated block signatures")
    func suppressesRepeatedBlockSignatures() {
        var gate = SuggestionBlockLogGate()
        let firstRuntimeBlock = gate.shouldRecord(signature: "field:runtime-not-ready")
        let repeatedRuntimeBlock = gate.shouldRecord(signature: "field:runtime-not-ready")
        let newBlockReason = gate.shouldRecord(signature: "field:too-short")

        #expect(firstRuntimeBlock)
        #expect(!repeatedRuntimeBlock)
        #expect(newBlockReason)
    }

    @Test("Reset allows the same signature again")
    func resetAllowsSameSignatureAgain() {
        var gate = SuggestionBlockLogGate()
        let firstRuntimeBlock = gate.shouldRecord(signature: "field:runtime-not-ready")

        gate.reset()
        let afterReset = gate.shouldRecord(signature: "field:runtime-not-ready")

        #expect(firstRuntimeBlock)
        #expect(afterReset)
    }
}
