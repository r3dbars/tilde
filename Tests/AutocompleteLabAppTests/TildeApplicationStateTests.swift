import Foundation
import Testing
@testable import AutocompleteLabApp

@Suite("Tilde application state")
struct TildeApplicationStateTests {
    @Test("Ready requires every live prediction prerequisite")
    func ready() {
        #expect(resolve() == .ready)
    }

    @Test("User controls win over runtime readiness")
    func disabledAndPaused() {
        let now = Date(timeIntervalSince1970: 1_000)
        #expect(resolve(suggestionsEnabled: false, now: now) == .disabled)
        #expect(resolve(screenMemoryEnabled: false, now: now) == .disabled)
        #expect(
            resolve(pausedUntil: now.addingTimeInterval(3_600), now: now)
                == .paused(until: now.addingTimeInterval(3_600))
        )
    }

    @Test("Missing permission and runtime failures are honest")
    func attentionStates() {
        #expect(resolve(screenRecordingGranted: false) == .needsPermission)
        #expect(resolve(runtime: .starting) == .preparingModel)
        #expect(resolve(runtime: .failed(.assetsMissing)) == .recoverableError)
        #expect(resolve(socketAvailable: false) == .recoverableError)
    }

    @Test("Every state maps to one of the three icon appearances")
    func iconAppearances() {
        #expect(TildeApplicationState.ready.iconAppearance == .normal)
        #expect(TildeApplicationState.disabled.iconAppearance == .dimmed)
        #expect(TildeApplicationState.needsPermission.iconAppearance == .warning)
    }

    private func resolve(
        suggestionsEnabled: Bool = true,
        pausedUntil: Date? = nil,
        screenMemoryEnabled: Bool = true,
        screenRecordingGranted: Bool = true,
        runtime: LlamaRuntimeSnapshot = .ready,
        socketAvailable: Bool = true,
        now: Date = Date(timeIntervalSince1970: 1_000)
    ) -> TildeApplicationState {
        TildeApplicationState.resolve(
            suggestionsEnabled: suggestionsEnabled,
            pausedUntil: pausedUntil,
            screenMemoryEnabled: screenMemoryEnabled,
            screenRecordingGranted: screenRecordingGranted,
            runtime: runtime,
            socketAvailable: socketAvailable,
            now: now
        )
    }
}

