import Foundation
import Testing
@testable import AutocompleteLabCore

@Suite("Focus polling cadence policy")
struct FocusPollingCadencePolicyTests {
    @Test("Uses bounded active polling only while a suggestion is visible")
    func usesBoundedActivePollingOnlyWhileSuggestionIsVisible() {
        let policy = FocusPollingCadencePolicy()

        #expect(policy.activeSuggestionIntervalSeconds == 0.05)
        #expect(policy.interval(
            isTrustedForAccessibility: true,
            hasSupportedProfile: true,
            hasVisibleSuggestion: true
        ) == policy.activeSuggestionIntervalSeconds)

        #expect(policy.interval(
            isTrustedForAccessibility: true,
            hasSupportedProfile: true,
            hasVisibleSuggestion: false
        ) == policy.supportedTypingWatchIntervalSeconds)
    }

    @Test("Backs off supported polling during recent active typing")
    func backsOffSupportedPollingDuringRecentActiveTyping() {
        let policy = FocusPollingCadencePolicy(
            supportedTypingWatchIntervalSeconds: 0.12,
            recentTextChangeIntervalSeconds: 0.20,
            recentTextChangeWindowSeconds: 0.75
        )
        let now = Date(timeIntervalSince1970: 100)

        #expect(policy.hasRecentTextChange(
            lastTextChangeAt: now.addingTimeInterval(-0.7),
            now: now
        ))
        #expect(!policy.hasRecentTextChange(
            lastTextChangeAt: now.addingTimeInterval(-0.8),
            now: now
        ))
        #expect(policy.interval(
            isTrustedForAccessibility: true,
            hasSupportedProfile: true,
            hasVisibleSuggestion: false,
            hasRecentTextChange: true
        ) == policy.recentTextChangeIntervalSeconds)
    }

    @Test("Backs off when Accessibility is missing or no target app is supported")
    func backsOffWhenAccessibilityIsMissingOrNoTargetAppIsSupported() {
        let policy = FocusPollingCadencePolicy()

        #expect(policy.interval(
            isTrustedForAccessibility: false,
            hasSupportedProfile: true,
            hasVisibleSuggestion: true
        ) == policy.untrustedIntervalSeconds)

        #expect(policy.interval(
            isTrustedForAccessibility: true,
            hasSupportedProfile: false,
            hasVisibleSuggestion: false
        ) == policy.idleIntervalSeconds)
    }

    @Test("Skips polls until the current cadence interval has elapsed")
    func skipsPollsUntilCurrentCadenceIntervalHasElapsed() {
        let policy = FocusPollingCadencePolicy(
            activeSuggestionIntervalSeconds: 0.05,
            supportedTypingWatchIntervalSeconds: 0.2,
            idleIntervalSeconds: 0.4,
            untrustedIntervalSeconds: 0.8
        )
        let start = Date(timeIntervalSince1970: 1_000)

        #expect(policy.shouldPoll(
            now: start,
            lastPollAt: nil,
            isTrustedForAccessibility: true,
            hasSupportedProfile: true,
            hasVisibleSuggestion: false
        ))
        #expect(!policy.shouldPoll(
            now: start.addingTimeInterval(0.19),
            lastPollAt: start,
            isTrustedForAccessibility: true,
            hasSupportedProfile: true,
            hasVisibleSuggestion: false
        ))
        #expect(policy.shouldPoll(
            now: start.addingTimeInterval(0.2),
            lastPollAt: start,
            isTrustedForAccessibility: true,
            hasSupportedProfile: true,
            hasVisibleSuggestion: false
        ))
    }

    @Test("Reports the next poll date for timer backoff")
    func reportsTheNextPollDateForTimerBackoff() {
        let policy = FocusPollingCadencePolicy(
            activeSuggestionIntervalSeconds: 0.05,
            supportedTypingWatchIntervalSeconds: 0.2,
            recentTextChangeIntervalSeconds: 0.3,
            idleIntervalSeconds: 0.4,
            untrustedIntervalSeconds: 0.8
        )
        let start = Date(timeIntervalSince1970: 1_000)

        #expect(policy.nextPollDate(
            lastPollAt: nil,
            isTrustedForAccessibility: true,
            hasSupportedProfile: true,
            hasVisibleSuggestion: false
        ) == nil)
        #expect(policy.nextPollDate(
            lastPollAt: start,
            isTrustedForAccessibility: true,
            hasSupportedProfile: true,
            hasVisibleSuggestion: false,
            hasRecentTextChange: true
        ) == start.addingTimeInterval(0.3))
        #expect(policy.nextPollDate(
            lastPollAt: start,
            isTrustedForAccessibility: true,
            hasSupportedProfile: false,
            hasVisibleSuggestion: false
        ) == start.addingTimeInterval(0.4))
        #expect(policy.nextPollDate(
            lastPollAt: start,
            isTrustedForAccessibility: false,
            hasSupportedProfile: true,
            hasVisibleSuggestion: true
        ) == start.addingTimeInterval(0.8))
    }

    @Test("Future poll timestamps stay fail open")
    func futurePollTimestampsStayFailOpen() {
        let policy = FocusPollingCadencePolicy(supportedTypingWatchIntervalSeconds: 0.2)
        let now = Date(timeIntervalSince1970: 1_000)

        #expect(policy.shouldPoll(
            now: now,
            lastPollAt: now.addingTimeInterval(1),
            isTrustedForAccessibility: true,
            hasSupportedProfile: true,
            hasVisibleSuggestion: false
        ))
    }

    @Test("Visible suggestions keep the poll loop responsive")
    func visibleSuggestionsKeepThePollLoopResponsive() {
        let policy = FocusPollingCadencePolicy(
            activeSuggestionIntervalSeconds: 0.05,
            supportedTypingWatchIntervalSeconds: 0.2
        )
        let start = Date(timeIntervalSince1970: 1_000)

        #expect(policy.shouldPoll(
            now: start.addingTimeInterval(0.051),
            lastPollAt: start,
            isTrustedForAccessibility: true,
            hasSupportedProfile: true,
            hasVisibleSuggestion: true
        ))
        #expect(!policy.shouldPoll(
            now: start.addingTimeInterval(0.049),
            lastPollAt: start,
            isTrustedForAccessibility: true,
            hasSupportedProfile: true,
            hasVisibleSuggestion: true
        ))
    }
}
