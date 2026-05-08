import Foundation
import Testing
import AutocompleteLabCore
@testable import AutocompleteLabApp

@Suite("Acceptance survival checker")
struct AppAcceptanceSurvivalCheckerTests {
    @Test("Rejected two-second checkpoint marks the tracker as deleted")
    func rejectedTwoSecondCheckpointMarksTrackerDeleted() async throws {
        let checker = AcceptanceSurvivalChecker()
        let tracker = try makeTracker(acceptedText: " accepted text")
        await checker.beginTracking(tracker)

        let result = try #require(await checker.measure(
            acceptanceID: tracker.acceptanceID,
            checkpoint: .twoSeconds,
            currentTextWindow: "Draft without it",
            now: tracker.acceptedAt.addingTimeInterval(2)
        ))
        let updated = try #require(await checker.tracker(acceptanceID: tracker.acceptanceID))

        #expect(result.shouldRecordAcceptedThenDeleted)
        #expect(result.measurement.survivalClass == .rejectedAfterAccept)
        #expect(updated.deletedWithinTwoSeconds)
    }

    @Test("Final kept checkpoint records accepted and kept then finishes")
    func finalKeptCheckpointRecordsAcceptedAndKeptThenFinishes() async throws {
        let checker = AcceptanceSurvivalChecker()
        let tracker = try makeTracker(acceptedText: " accepted text")
        await checker.beginTracking(tracker)

        let result = try #require(await checker.measure(
            acceptanceID: tracker.acceptanceID,
            checkpoint: .thirtySeconds,
            currentTextWindow: "Draft accepted text",
            now: tracker.acceptedAt.addingTimeInterval(30)
        ))
        let removed = await checker.finishTracking(acceptanceID: tracker.acceptanceID)

        #expect(result.shouldRecordAcceptedAndKept)
        #expect(result.shouldFinish)
        #expect(result.finishReason == "thirty-second-finalized")
        #expect(removed?.acceptanceID == tracker.acceptanceID)
    }

    private func makeTracker(acceptedText: String) throws -> AcceptanceSurvivalTracker {
        let profile = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit"))
        return AcceptanceSurvivalTracker(
            acceptanceID: "accept-\(UUID().uuidString)",
            suggestionID: "suggestion-one",
            appBundleIdentifier: "com.apple.TextEdit",
            fieldIdentity: FocusedFieldIdentity(
                bundleIdentifier: "com.apple.TextEdit",
                processIdentifier: 42,
                elementIdentifier: 7
            ),
            requestMode: CompletionRequestMode.phraseContinuation.rawValue,
            acceptedText: acceptedText,
            expectedInsertionUTF16Offset: "Draft".utf16.count,
            acceptedAt: Date(),
            profile: profile,
            fieldKind: .multilineCompose,
            fieldKindReason: "test"
        )
    }
}
