import Foundation
import Testing
import AutocompleteLabCore
@testable import AutocompleteLabApp

@Suite("Suggestion pipeline controller")
struct SuggestionPipelineControllerTests {
    @MainActor
    @Test("Requested polls coalesce and bypass the repeating cadence")
    func requestedPollsCoalesce() async throws {
        let host = PollingHostStub()
        let controller = SuggestionPipelineController(host: host)

        controller.requestPollSoon(afterMilliseconds: 30)
        controller.requestPollSoon(afterMilliseconds: 0)
        await Task.yield()
        try await Task.sleep(for: .milliseconds(50))

        #expect(host.pollCount == 1)
    }

    @MainActor
    @Test("Requested polls keep accessibility and profile eligibility gates")
    func requestedPollsKeepEligibilityGates() async throws {
        let host = PollingHostStub()
        host.signals.isTrustedForAccessibility = false
        let controller = SuggestionPipelineController(host: host)

        controller.requestPollSoon(afterMilliseconds: 0)
        await Task.yield()

        #expect(host.pollCount == 0)
    }
}

@MainActor
private final class PollingHostStub: SuggestionPipelineHost {
    var signals = FocusPollingCadenceSignals(
        isTrustedForAccessibility: true,
        hasSupportedProfile: true,
        hasVisibleSuggestion: false,
        hasPersonalCapture: false,
        lastFocusedTextChangeAt: nil
    )
    var pollCount = 0

    func focusedTextPollCadenceSignals() -> FocusPollingCadenceSignals {
        signals
    }

    func executeFocusedTextPoll(startedAt: UInt64) -> Bool {
        pollCount += 1
        return false
    }

    func applyFocusedTextPollingThrottle(_ recommendation: FocusedTextPollingThrottleRecommendation) {}
}
