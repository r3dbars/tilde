import Testing
@testable import AutocompleteLabApp

@Suite("Llama restart policy")
struct LlamaRestartPolicyTests {
    @Test("Failures back off but always retry")
    func boundedBackoff() {
        var policy = LlamaRestartPolicy()
        let delays = (0..<8).map { _ in policy.delay(wasHealthy: false, uptime: 1) }
        #expect(delays == [2, 4, 8, 16, 32, 60, 60, 60])
    }

    @Test("A proven run resets the backoff")
    func provenRunResets() {
        var policy = LlamaRestartPolicy()
        _ = policy.delay(wasHealthy: false, uptime: 1)
        _ = policy.delay(wasHealthy: false, uptime: 1)
        #expect(policy.delay(wasHealthy: true, uptime: 120) == 2)
        #expect(policy.failures == 1)
    }
}
