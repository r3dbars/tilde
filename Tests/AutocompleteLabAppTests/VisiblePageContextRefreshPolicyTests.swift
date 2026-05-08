import Foundation
import Testing
@testable import AutocompleteLabApp

@Suite("Visible page context refresh policy")
struct VisiblePageContextRefreshPolicyTests {
    private let policy = VisiblePageContextRefreshPolicy(
        minimumRefreshInterval: 3,
        maximumCacheAge: 20
    )

    @Test("Skips duplicate capture while the same key is in flight")
    func skipsSameKeyInFlightCapture() {
        #expect(!policy.shouldRefresh(
            inFlightMatchesKey: true,
            matchingCacheAge: nil,
            lastAttemptAge: nil,
            allowsFreshCacheRefresh: true
        ))
    }

    @Test("Keeps idle OCR cache until it is stale")
    func keepsIdleCacheUntilStale() {
        #expect(!policy.shouldRefresh(
            inFlightMatchesKey: false,
            matchingCacheAge: 8,
            lastAttemptAge: 8,
            allowsFreshCacheRefresh: false
        ))

        #expect(policy.shouldRefresh(
            inFlightMatchesKey: false,
            matchingCacheAge: 21,
            lastAttemptAge: 21,
            allowsFreshCacheRefresh: false
        ))
    }

    @Test("Allows fresher OCR refresh when the user is typing")
    func allowsRefreshOnTextChangeAfterMinimumInterval() {
        #expect(policy.shouldRefresh(
            inFlightMatchesKey: false,
            matchingCacheAge: 4,
            lastAttemptAge: 4,
            allowsFreshCacheRefresh: true
        ))
    }

    @Test("Still protects the app from capture storms while typing")
    func stillProtectsAgainstCaptureStorms() {
        #expect(!policy.shouldRefresh(
            inFlightMatchesKey: false,
            matchingCacheAge: 2,
            lastAttemptAge: 2,
            allowsFreshCacheRefresh: true
        ))
    }
}
