import Foundation
import Testing
import AutocompleteLabCore
@testable import AutocompleteLabApp

@Suite("Acceptance survival checker")
struct AcceptanceSurvivalCheckerTests {
    @Test("Rejected two-second checkpoint marks the tracker as deleted")
    func rejectedTwoSecondCheckpointMarksTrackerDeleted() async throws {
        let checker = AcceptanceSurvivalChecker()
        let tracker = makeTracker(
            acceptedText: " accepted text",
            textBeforeCursor: "Draft"
        )
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

    @Test("Thirty-second kept checkpoint records accepted and kept without finishing")
    func thirtySecondKeptCheckpointRecordsAcceptedAndKeptWithoutFinishing() async throws {
        let checker = AcceptanceSurvivalChecker()
        let tracker = makeTracker(
            acceptedText: " accepted text",
            textBeforeCursor: "Draft"
        )
        await checker.beginTracking(tracker)

        let result = try #require(await checker.measure(
            acceptanceID: tracker.acceptanceID,
            checkpoint: .thirtySeconds,
            currentTextWindow: "Draft accepted text",
            now: tracker.acceptedAt.addingTimeInterval(30)
        ))

        #expect(result.shouldRecordAcceptedAndKept)
        #expect(!result.shouldFinish)
        #expect(result.finishReason == nil)
        #expect(await checker.tracker(acceptanceID: tracker.acceptanceID) != nil)
    }

    @Test("Five-minute kept checkpoint records accepted and kept then finishes")
    func fiveMinuteKeptCheckpointRecordsAcceptedAndKeptThenFinishes() async throws {
        let checker = AcceptanceSurvivalChecker()
        let tracker = makeTracker(
            acceptedText: " accepted text",
            textBeforeCursor: "Draft"
        )
        await checker.beginTracking(tracker)

        let result = try #require(await checker.measure(
            acceptanceID: tracker.acceptanceID,
            checkpoint: .fiveMinutes,
            currentTextWindow: "Draft accepted text",
            now: tracker.acceptedAt.addingTimeInterval(300)
        ))
        let removed = await checker.finishTracking(acceptanceID: tracker.acceptanceID)

        #expect(result.shouldRecordAcceptedAndKept)
        #expect(result.shouldFinish)
        #expect(result.finishReason == "five-minute-finalized")
        #expect(removed?.acceptanceID == tracker.acceptanceID)
    }

    @Test("Records two-second deletes and finalizes retained text from RAM")
    func recordsDeletesAndClearsTracker() async throws {
        let checker = AcceptanceSurvivalChecker()
        let tracker = makeTracker(
            acceptedText: "wrong direction",
            acceptedAt: Date(timeIntervalSince1970: 1_000)
        )

        await checker.beginTracking(tracker)
        let deleted = try #require(await checker.measure(
            acceptanceID: tracker.acceptanceID,
            checkpoint: .twoSeconds,
            currentTextWindow: "Start again.",
            now: Date(timeIntervalSince1970: 1_001)
        ))

        #expect(deleted.shouldRecordAcceptedThenDeleted)
        #expect(deleted.measurement.survivalClass == .rejectedAfterAccept)
        #expect(deleted.measurement.deletedWithinTwoSeconds)

        let thirtySecond = try #require(await checker.measure(
            acceptanceID: tracker.acceptanceID,
            checkpoint: .thirtySeconds,
            currentTextWindow: "Start again.",
            now: Date(timeIntervalSince1970: 1_031)
        ))

        #expect(!thirtySecond.shouldFinish)
        #expect(thirtySecond.finishReason == nil)
        #expect(thirtySecond.measurement.deletedWithinTwoSeconds)

        let final = try #require(await checker.measure(
            acceptanceID: tracker.acceptanceID,
            checkpoint: .fiveMinutes,
            currentTextWindow: "Start again.",
            now: Date(timeIntervalSince1970: 1_301)
        ))

        #expect(final.shouldFinish)
        #expect(final.finishReason == "five-minute-finalized")
        #expect(final.measurement.deletedWithinTwoSeconds)
        #expect(await checker.finishTracking(acceptanceID: tracker.acceptanceID) != nil)
        #expect(await checker.tracker(acceptanceID: tracker.acceptanceID) == nil)
    }

    @Test("Builds survival metadata without durable raw accepted text")
    func buildsLogSafeMetadataWithoutRawAcceptedText() {
        let tracker = makeTracker(acceptedText: "make this private")
        let measurement = AcceptanceSurvivalMeasurement(
            checkpoint: .tenSeconds,
            tokenRecall: 1,
            normalizedEditDistance: 0,
            survivalClass: .exactKept
        )
        let metadata = AcceptanceSurvivalTraceMetadata.measurementMetadata(
            tracker: tracker,
            measurement: measurement,
            secret: Data("survival-secret".utf8)
        )
        let encoded = String(decoding: try! JSONEncoder().encode(metadata), as: UTF8.self)

        #expect(metadata["acceptanceID"] == tracker.acceptanceID)
        #expect(metadata["acceptedTextChars"] == "17")
        #expect(metadata["traceRetention"] == "ram-only")
        #expect(metadata["checkpoint"] == "10s")
        #expect(metadata["acceptedTextHMACToken"]?.isEmpty == false)
        #expect(!encoded.localizedCaseInsensitiveContains("private"))
        #expect(!encoded.localizedCaseInsensitiveContains("make this"))
    }

    @Test("Strong ten-second keeps are eligible for accepted-and-kept proof")
    func strongTenSecondKeepsAreProofEvents() async throws {
        let checker = AcceptanceSurvivalChecker()
        let tracker = makeTracker(acceptedText: "make this easier")

        await checker.beginTracking(tracker)
        let result = try #require(await checker.measure(
            acceptanceID: tracker.acceptanceID,
            checkpoint: .tenSeconds,
            currentTextWindow: "Start make this easier today."
        ))

        #expect(result.shouldRecordAcceptedAndKept)
        #expect(!result.shouldFinish)
        #expect(result.measurement.isStrongAcceptedAndKept)
    }

    private func makeTracker(
        acceptedText: String,
        acceptedAt: Date = Date(timeIntervalSince1970: 1_000),
        requestMode: CompletionRequestMode = .wordCompletion,
        textBeforeCursor: String = "Start "
    ) -> AcceptanceSurvivalTracker {
        AcceptanceSurvivalTracker(
            acceptanceID: "acceptance-one",
            suggestionID: "suggestion-one",
            appBundleIdentifier: "com.apple.TextEdit",
            fieldIdentity: FocusedFieldIdentity(
                bundleIdentifier: "com.apple.TextEdit",
                processIdentifier: 42,
                elementIdentifier: 7
            ),
            requestMode: requestMode.rawValue,
            acceptedText: acceptedText,
            textBeforeCursorAtAccept: textBeforeCursor,
            expectedInsertionUTF16Offset: textBeforeCursor.utf16.count,
            acceptedAt: acceptedAt,
            profile: CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit")!,
            fieldKind: .multilineCompose,
            fieldKindReason: "unit-test"
        )
    }
}
