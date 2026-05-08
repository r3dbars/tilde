import Testing
@testable import AutocompleteLabApp
@testable import AutocompleteLabCore

@Suite("Unavailable model runtime")
struct UnavailableModelRuntimeTests {
    @Test("Unavailable runtime fails closed instead of producing mock suggestions")
    func unavailableRuntimeFailsClosed() async {
        let runtime = UnavailableModelRuntime(
            candidate: .mlx,
            reason: "missing model asset"
        )

        await #expect(runtime.state == .unavailable(reason: "missing model asset"))

        await #expect(throws: UnavailableModelRuntimeError.self) {
            try await runtime.warm()
        }

        await #expect(throws: UnavailableModelRuntimeError.self) {
            _ = try await runtime.complete(CompletionRequest(textBeforeCursor: "hello"))
        }
    }
}
