import AutocompleteLabCore
import Testing
@testable import AutocompleteLabApp

@MainActor
@Suite("Suggestion insertion host")
struct SuggestionInsertionHostTests {
    @Test("Blocks insertion when the compatibility profile is missing")
    func missingProfileFailsClosed() {
        let spy = SuggestionInsertionHostSpy()
        let host = makeHost(profile: nil, spy: spy)

        #expect(!host.insertAcceptedText("safe"))
        #expect(spy.decisions == ["Blocked: missing compatibility profile"])
        #expect(spy.hiddenReasons == ["insert-missing-compatibility-profile"])
        #expect(spy.insertions.isEmpty)
    }

    @Test("Blocks unsafe accepted text before any native route")
    func unsafeTextFailsClosed() throws {
        let profile = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit"))
        let spy = SuggestionInsertionHostSpy()
        let host = makeHost(profile: profile, spy: spy)

        #expect(!host.insertAcceptedText("safe\ntext"))
        #expect(spy.decisions == ["Blocked: unsafe accepted text"])
        #expect(spy.hiddenReasons == ["insert-unsafe-accepted-text"])
        #expect(spy.insertions.isEmpty)
    }

    @Test("Preserves direct app route ordering and pauses after success")
    func directRouteWinsBeforeDefaultInsertion() throws {
        let profile = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit"))
        let spy = SuggestionInsertionHostSpy()
        spy.codexRoute = true
        let host = makeHost(profile: profile, spy: spy)

        #expect(host.insertAcceptedText("safe"))
        #expect(spy.insertions == ["codex"])
        #expect(spy.pauseDurations == [220])
        #expect(spy.defaultExpectedFieldIdentity == nil)
    }

    @Test("Binds default insertion to the current suggestion field identity")
    func defaultInsertionKeepsValidatedIdentity() throws {
        let profile = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit"))
        let identity = FocusedFieldIdentity(
            bundleIdentifier: "com.apple.TextEdit",
            processIdentifier: 4321,
            elementIdentifier: 99
        )
        let state = CurrentSuggestionStateHost()
        state.fieldIdentity = identity
        let spy = SuggestionInsertionHostSpy()
        let host = makeHost(profile: profile, state: state, spy: spy)

        #expect(host.insertAcceptedText("safe"))
        #expect(spy.insertions == ["default"])
        #expect(spy.defaultExpectedFieldIdentity == identity)
        #expect(spy.pauseDurations == [220])
    }

    private func makeHost(
        profile: CompatibilityProfile?,
        state: CurrentSuggestionStateHost = CurrentSuggestionStateHost(),
        spy: SuggestionInsertionHostSpy
    ) -> SuggestionInsertionHost {
        SuggestionInsertionHost(
            dependencies: SuggestionInsertionHostDependencies(
                currentProfile: { profile },
                currentSuggestionState: state,
                currentFieldIdentity: { nil },
                acceptedTextSafetyPolicy: AcceptedTextSafetyPolicy(),
                setSuggestionDecision: { spy.decisions.append($0) },
                hideSuggestion: { spy.hiddenReasons.append($0) },
                suppressPassthroughObservation: { _ in spy.suppressionCount += 1 },
                shouldUseClaudeCodeTerminalHostProofDirectInsertion: { _, _ in spy.terminalRoute },
                shouldUseCodexProofDirectInsertion: { _ in spy.codexRoute },
                shouldUseClaudeDesktopProofDirectInsertion: { _ in spy.claudeDesktopRoute },
                shouldUseObsidianDirectValueInsertion: { _, _ in spy.obsidianDirectRoute },
                shouldUseObsidianSystemEventsInsertion: { _ in spy.obsidianSystemEventsRoute },
                insertCodexProofText: { _ in spy.insertions.append("codex"); return spy.routeSucceeded },
                insertClaudeCodeTerminalHostProofText: { _ in
                    spy.insertions.append("terminal")
                    return spy.routeSucceeded
                },
                insertClaudeDesktopProofText: { _ in
                    spy.insertions.append("claude-desktop")
                    return spy.routeSucceeded
                },
                insertObsidianDirectValueText: { _, _ in
                    spy.insertions.append("obsidian-direct")
                    return spy.routeSucceeded
                },
                insertObsidianSystemEventsPasteText: { _ in
                    spy.insertions.append("obsidian-system-events")
                    return spy.routeSucceeded
                },
                repairObsidianFullAcceptCaret: { _, _ in spy.repairCount += 1 },
                defaultInsertion: { _, profile, expectedFieldIdentity, _ in
                    spy.insertions.append("default")
                    spy.defaultExpectedFieldIdentity = expectedFieldIdentity
                    return InsertionResult(
                        succeeded: spy.defaultSucceeded,
                        mode: profile.insertionMode,
                        message: "test"
                    )
                },
                pausePolling: { spy.pauseDurations.append($0) },
                postInsertionPollPauseMilliseconds: 220
            )
        )
    }
}

@MainActor
private final class SuggestionInsertionHostSpy {
    var decisions: [String] = []
    var hiddenReasons: [String] = []
    var insertions: [String] = []
    var pauseDurations: [Int] = []
    var defaultExpectedFieldIdentity: FocusedFieldIdentity?
    var suppressionCount = 0
    var repairCount = 0
    var codexRoute = false
    var terminalRoute = false
    var claudeDesktopRoute = false
    var obsidianDirectRoute = false
    var obsidianSystemEventsRoute = false
    var routeSucceeded = true
    var defaultSucceeded = true
}
