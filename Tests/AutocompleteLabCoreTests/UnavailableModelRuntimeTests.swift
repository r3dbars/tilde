import Testing
@testable import AutocompleteLabCore

@Suite("Unavailable model runtime")
struct UnavailableModelRuntimeTests {
    @Test("Reports unavailable state and refuses warm or completion")
    func reportsUnavailableStateAndRefusesWork() async {
        let runtime = UnavailableModelRuntime(reason: "model missing")

        #expect(await runtime.state == .unavailable(reason: "model missing"))

        await #expect(throws: UnavailableModelRuntimeError(reason: "model missing")) {
            try await runtime.warm()
        }

        await #expect(throws: UnavailableModelRuntimeError(reason: "model missing")) {
            _ = try await runtime.complete(CompletionRequest(textBeforeCursor: "Smoke proof feels"))
        }
    }

    @Test("Error description stays tester-safe")
    func errorDescriptionStaysTesterSafe() {
        let error = UnavailableModelRuntimeError(reason: "local model is not installed")

        #expect(error.errorDescription == "Local model runtime is unavailable: local model is not installed")
    }
}
