import Testing
@testable import AutocompleteLabApp

@Suite("Proof-only accept command")
struct ProofOnlyAcceptCommandTests {
    @Test("Accept command is opt-in and argument scoped")
    func acceptCommandIsOptInAndArgumentScoped() {
        #expect(ProofOnlyAcceptCommand.argument == "--proof-only-accept-next-word")
        #expect(ProofOnlyAcceptCommand.isRequested(arguments: ["SteadyType", "--proof-only-accept-next-word"]))
        #expect(!ProofOnlyAcceptCommand.isRequested(arguments: ["SteadyType"]))

        let key = ProofOnlyAcceptCommand.enabledEnvironmentKey
        #expect(!ProofOnlyAcceptCommand.isEnabled(environment: [:]))
        #expect(ProofOnlyAcceptCommand.isEnabled(environment: [key: "1"]))
        #expect(ProofOnlyAcceptCommand.isEnabled(environment: [key: "true"]))
        #expect(ProofOnlyAcceptCommand.isEnabled(environment: [key: "YES"]))
        #expect(ProofOnlyAcceptCommand.isEnabled(environment: [key: "on"]))
        #expect(!ProofOnlyAcceptCommand.isEnabled(environment: [key: "0"]))
        #expect(ProofOnlyAcceptCommand.run(environment: [:]) == 64)
    }
}
