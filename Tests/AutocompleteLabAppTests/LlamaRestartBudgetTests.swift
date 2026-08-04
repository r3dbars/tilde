import Foundation
import Testing
@testable import AutocompleteLabApp

@Suite("Llama restart budget")
struct LlamaRestartBudgetTests {

    private func decisions(
        _ budget: inout LlamaRestartBudget,
        _ exits: [(wasHealthy: Bool, uptime: TimeInterval)]
    ) -> [Bool] {
        exits.map { budget.shouldRestart(wasHealthy: $0.wasHealthy, uptime: $0.uptime) }
    }

    @Test("A rapid crash loop exhausts the budget and stays exhausted")
    func rapidCrashLoopExhausts() {
        var budget = LlamaRestartBudget(maximumRestarts: 3, provenUptime: 120)
        let crash = (wasHealthy: false, uptime: TimeInterval(1))
        #expect(decisions(&budget, [crash, crash, crash, crash, crash])
            == [true, true, true, false, false])
    }

    @Test("Healthy-then-quick-death still counts against the budget")
    func healthyButShortLivedCounts() {
        // The 2026-08-04 incident: each restart reported healthy, then died
        // ~3s later. Health alone must not refill the budget.
        var budget = LlamaRestartBudget(maximumRestarts: 3, provenUptime: 120)
        let blip = (wasHealthy: true, uptime: TimeInterval(3))
        #expect(decisions(&budget, [blip, blip, blip, blip])
            == [true, true, true, false])
    }

    @Test("A proven run earns the full budget back")
    func provenUptimeResets() {
        var budget = LlamaRestartBudget(maximumRestarts: 3, provenUptime: 120)
        let crash = (wasHealthy: false, uptime: TimeInterval(1))
        // Two quick failures, then the server ran healthy for five minutes
        // before dying: restart, and treat what follows as a fresh episode.
        let proven = (wasHealthy: true, uptime: TimeInterval(300))
        #expect(decisions(&budget, [crash, crash, proven]) == [true, true, true])
        #expect(budget.consecutiveFailures == 1)
        #expect(decisions(&budget, [crash, crash, crash]) == [true, true, false])
    }

    @Test("An unhealthy long run does not earn the budget back")
    func unhealthyLongRunDoesNotReset() {
        // Alive-but-never-healthy (e.g. model load wedged) is not proof.
        var budget = LlamaRestartBudget(maximumRestarts: 3, provenUptime: 120)
        let wedged = (wasHealthy: false, uptime: TimeInterval(999))
        #expect(decisions(&budget, [wedged, wedged, wedged, wedged])
            == [true, true, true, false])
    }
}
