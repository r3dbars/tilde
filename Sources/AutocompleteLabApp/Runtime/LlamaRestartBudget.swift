import Foundation

/// Restart policy for the llama-server child: crash loops must not spin
/// forever, but one bad burst must not disable the engine until the next app
/// relaunch either. A server that proved itself — healthy and alive past
/// `provenUptime` — earns its full budget back; only consecutive quick deaths
/// exhaust it. (2026-08-04: a 3-crash burst at 10:21pm permanently gave up,
/// and the owner typed brainless the next morning.)
struct LlamaRestartBudget {

    let maximumRestarts: Int
    let provenUptime: TimeInterval
    private(set) var consecutiveFailures = 0

    init(maximumRestarts: Int = 3, provenUptime: TimeInterval = 120) {
        self.maximumRestarts = maximumRestarts
        self.provenUptime = provenUptime
    }

    /// Decides whether the server that just exited should relaunch.
    /// `wasHealthy` and `uptime` describe the process that died.
    mutating func shouldRestart(wasHealthy: Bool, uptime: TimeInterval) -> Bool {
        if wasHealthy && uptime >= provenUptime {
            consecutiveFailures = 0
        }
        guard consecutiveFailures < maximumRestarts else { return false }
        consecutiveFailures += 1
        return true
    }
}
