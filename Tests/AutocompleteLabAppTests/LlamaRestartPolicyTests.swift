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

@Suite("Llama health probe cadence")
struct LlamaHealthProbeCadenceTests {
    @Test("Probes start fast, then settle back to the original steady cadence")
    func laddersFromFastToSteady() {
        #expect(LlamaServerProcessHost.healthProbeDelayMilliseconds(attempt: 0) == 100)
        #expect(LlamaServerProcessHost.healthProbeDelayMilliseconds(attempt: 3) == 100)
        #expect(LlamaServerProcessHost.healthProbeDelayMilliseconds(attempt: 4) == 250)
        #expect(LlamaServerProcessHost.healthProbeDelayMilliseconds(attempt: 8) == 500)
        #expect(LlamaServerProcessHost.healthProbeDelayMilliseconds(attempt: 11) == 500)
        #expect(LlamaServerProcessHost.healthProbeDelayMilliseconds(attempt: 12) == 1_000)
        #expect(LlamaServerProcessHost.healthProbeDelayMilliseconds(attempt: 16) == 2_000)
        #expect(LlamaServerProcessHost.healthProbeDelayMilliseconds(attempt: 57) == 2_000)
    }

    /// The whole point of the ladder: a helper serving 300ms after launch is
    /// discovered then, not at the next flat two-second tick.
    @Test("A helper ready shortly after launch is discovered in the first few hundred milliseconds")
    func fastStartIsDiscoveredFast() {
        let waitBeforeFourthProbe = (0..<3).reduce(0) {
            $0 + LlamaServerProcessHost.healthProbeDelayMilliseconds(attempt: $1)
        }
        #expect(waitBeforeFourthProbe == 300)
    }

    @Test("The ladder keeps the health-timeout ceiling of the flat loop it replaced")
    func ceilingIsPreserved() {
        let total = (0..<LlamaServerProcessHost.healthProbeAttempts).reduce(0) {
            $0 + LlamaServerProcessHost.healthProbeDelayMilliseconds(attempt: $1)
        }
        // The flat loop it replaced was 45 probes x 2,000ms.
        #expect(total >= 90_000)
        #expect(total <= 95_000)
    }
}
