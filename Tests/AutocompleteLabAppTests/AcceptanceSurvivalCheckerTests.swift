import Foundation
import Testing
@testable import AutocompleteLabApp
@testable import AutocompleteLabCore

@Suite("Acceptance survival checker")
struct AcceptanceSurvivalCheckerTests {
    @Test("Two second deletion marks acceptance as rejected and retained for later checkpoints")
    func twoSecondDeletionMarksAcceptanceRejected() async {
        let checker = AcceptanceSurvivalChecker()
        let tracker = acceptanceTracker(acceptedText: "that works")

        await checker.beginTracking(tracker)
        let result = await checker.measure(
            acceptanceID: tracker.acceptanceID,
            checkpoint: .twoSeconds,
            currentTextWindow: "Let me know if ",
            now: tracker.acceptedAt.addingTimeInterval(2)
        )

        #expect(result?.measurement.survivalClass == .rejectedAfterAccept)
        #expect(result?.shouldRecordAcceptedThenDeleted == true)
        #expect(result?.shouldRecordAcceptedAndKept == false)
        #expect(await checker.tracker(acceptanceID: tracker.acceptanceID)?.deletedWithinTwoSeconds == true)
    }

    @Test("Thirty second kept acceptance records final accepted and kept")
    func thirtySecondKeptAcceptanceRecordsFinalMetric() async {
        let checker = AcceptanceSurvivalChecker()
        let tracker = acceptanceTracker(acceptedText: "that works")

        await checker.beginTracking(tracker)
        let result = await checker.measure(
            acceptanceID: tracker.acceptanceID,
            checkpoint: .thirtySeconds,
            currentTextWindow: "Let me know if that works for you.",
            now: tracker.acceptedAt.addingTimeInterval(30)
        )

        #expect(result?.measurement.survivalClass == .exactKept)
        #expect(result?.shouldRecordAcceptedAndKept == true)
        #expect(result?.shouldFinish == true)
        #expect(result?.finishReason == "thirty-second-finalized")

        _ = await checker.finishTracking(acceptanceID: tracker.acceptanceID)
        #expect(await checker.tracker(acceptanceID: tracker.acceptanceID) == nil)
    }

    @Test("Field blur finalizes matching field trackers")
    func fieldBlurFinalizesMatchingFieldTrackers() async {
        let checker = AcceptanceSurvivalChecker()
        let tracker = acceptanceTracker(acceptedText: "that works")

        await checker.beginTracking(tracker)
        let results = await checker.measureFieldBlur(
            fieldIdentity: tracker.fieldIdentity,
            currentTextWindow: "Let me know if that works.",
            now: tracker.acceptedAt.addingTimeInterval(4)
        )

        #expect(results.count == 1)
        #expect(results.first?.shouldFinish == true)
        #expect(results.first?.finishReason == "field-blur-finalized")
        #expect(results.first?.measurement.survivalClass == .exactKept)
    }

    private func acceptanceTracker(acceptedText: String) -> AcceptanceSurvivalTracker {
        let fieldIdentity = FocusedFieldIdentity(
            bundleIdentifier: "com.apple.TextEdit",
            processIdentifier: 42,
            elementIdentifier: 7
        )
        let profile = CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit")!

        return AcceptanceSurvivalTracker(
            acceptanceID: "accept-one",
            suggestionID: "suggest-one",
            appBundleIdentifier: "com.apple.TextEdit",
            fieldIdentity: fieldIdentity,
            requestMode: CompletionRequestMode.phraseContinuation.rawValue,
            acceptMode: KeyboardAction.acceptNextWord.diagnosticName,
            acceptedText: acceptedText,
            expectedInsertionUTF16Offset: "Let me know if ".utf16.count,
            acceptedAt: Date(timeIntervalSince1970: 1_000),
            profile: profile,
            fieldKind: .multilineCompose,
            fieldKindReason: "role:AXTextArea",
            behaviorProfileID: .docsProse
        )
    }
}
