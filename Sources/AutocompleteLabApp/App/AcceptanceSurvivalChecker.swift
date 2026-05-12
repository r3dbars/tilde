import Foundation
import AutocompleteLabCore

actor AcceptanceSurvivalChecker {
    private let classifier: AcceptanceSurvivalClassifier
    private var trackers: [String: AcceptanceSurvivalTracker] = [:]

    init(classifier: AcceptanceSurvivalClassifier = AcceptanceSurvivalClassifier()) {
        self.classifier = classifier
    }

    func beginTracking(_ tracker: AcceptanceSurvivalTracker) {
        trackers[tracker.acceptanceID] = tracker
    }

    func tracker(acceptanceID: String) -> AcceptanceSurvivalTracker? {
        trackers[acceptanceID]
    }

    func measure(
        acceptanceID: String,
        checkpoint: AcceptanceSurvivalCheckpoint,
        currentTextWindow: String,
        now: Date = Date()
    ) -> AcceptanceSurvivalCheckResult? {
        guard let tracker = trackers[acceptanceID] else {
            return nil
        }

        let firstPass = classifier.classifyAroundExpectedInsertion(
            acceptedText: tracker.acceptedText,
            currentFullText: currentTextWindow,
            expectedInsertionUTF16Offset: tracker.expectedInsertionUTF16Offset,
            checkpoint: checkpoint,
            deletedWithinTwoSeconds: tracker.deletedWithinTwoSeconds
        )

        var updatedTracker = tracker
        if checkpoint == .twoSeconds,
           firstPass.survivalClass == AcceptanceSurvivalClass.rejectedAfterAccept {
            updatedTracker.deletedWithinTwoSeconds = true
            trackers[tracker.acceptanceID] = updatedTracker
        }

        let measurement = classifier.classifyAroundExpectedInsertion(
            acceptedText: tracker.acceptedText,
            currentFullText: currentTextWindow,
            expectedInsertionUTF16Offset: tracker.expectedInsertionUTF16Offset,
            checkpoint: checkpoint,
            firstEditDelayMilliseconds: firstPass.survivalClass == AcceptanceSurvivalClass.exactKept
                ? nil
                : max(0, Int(now.timeIntervalSince(tracker.acceptedAt) * 1_000)),
            deletedWithinTwoSeconds: updatedTracker.deletedWithinTwoSeconds
        )

        return AcceptanceSurvivalCheckResult(
            tracker: updatedTracker,
            measurement: measurement,
            shouldRecordAcceptedThenDeleted: checkpoint == .twoSeconds
                && measurement.survivalClass == AcceptanceSurvivalClass.rejectedAfterAccept,
            shouldRecordAcceptedAndKept: measurement.isStrongAcceptedAndKept
                || measurement.isFinalAcceptedAndKept,
            shouldFinish: checkpoint.isFinalMetricCheckpoint,
            finishReason: checkpoint.isFinalMetricCheckpoint
                ? finishReason(for: checkpoint)
                : nil
        )
    }

    func measureFieldBlur(
        fieldIdentity: FocusedFieldIdentity,
        currentTextWindow: String,
        now: Date = Date()
    ) -> [AcceptanceSurvivalCheckResult] {
        measureFinalization(
            fieldIdentity: fieldIdentity,
            checkpoint: .fieldBlur,
            currentTextWindow: currentTextWindow,
            now: now
        )
    }

    func measureFieldSend(
        fieldIdentity: FocusedFieldIdentity,
        currentTextWindow: String,
        now: Date = Date()
    ) -> [AcceptanceSurvivalCheckResult] {
        measureFinalization(
            fieldIdentity: fieldIdentity,
            checkpoint: .fieldSend,
            currentTextWindow: currentTextWindow,
            now: now
        )
    }

    private func measureFinalization(
        fieldIdentity: FocusedFieldIdentity,
        checkpoint: AcceptanceSurvivalCheckpoint,
        currentTextWindow: String,
        now: Date
    ) -> [AcceptanceSurvivalCheckResult] {
        trackers.values
            .filter { $0.fieldIdentity == fieldIdentity }
            .compactMap {
                measure(
                    acceptanceID: $0.acceptanceID,
                    checkpoint: checkpoint,
                    currentTextWindow: currentTextWindow,
                    now: now
                )
            }
    }

    func finishTracking(acceptanceID: String) -> AcceptanceSurvivalTracker? {
        trackers.removeValue(forKey: acceptanceID)
    }

    func cancelAll() {
        trackers.removeAll()
    }

    private func finishReason(for checkpoint: AcceptanceSurvivalCheckpoint) -> String {
        switch checkpoint {
        case .fieldBlur:
            "field-blur-finalized"
        case .fieldSend:
            "field-send-finalized"
        case .thirtySeconds:
            "thirty-second-finalized"
        case .twoSeconds, .tenSeconds:
            "checkpoint-finalized"
        }
    }
}

struct AcceptanceSurvivalCheckResult: Sendable {
    let tracker: AcceptanceSurvivalTracker
    let measurement: AcceptanceSurvivalMeasurement
    let shouldRecordAcceptedThenDeleted: Bool
    let shouldRecordAcceptedAndKept: Bool
    let shouldFinish: Bool
    let finishReason: String?
}

struct AcceptanceSurvivalTracker: Equatable, Sendable {
    let acceptanceID: String
    let suggestionID: String
    let appBundleIdentifier: String
    let fieldIdentity: FocusedFieldIdentity
    let requestMode: String
    let acceptMode: String
    let acceptedText: String
    let textBeforeCursorAtAccept: String
    let expectedInsertionUTF16Offset: Int
    let acceptedAt: Date
    let profile: CompatibilityProfile
    let fieldKind: AXFieldKind
    let fieldKindReason: String
    let behaviorProfileID: AutocompleteBehaviorProfileID
    var deletedWithinTwoSeconds: Bool = false

    init(
        acceptanceID: String,
        suggestionID: String,
        appBundleIdentifier: String,
        fieldIdentity: FocusedFieldIdentity,
        requestMode: String,
        acceptMode: String = "acceptNextWord",
        acceptedText: String,
        textBeforeCursorAtAccept: String = "",
        expectedInsertionUTF16Offset: Int,
        acceptedAt: Date,
        profile: CompatibilityProfile,
        fieldKind: AXFieldKind,
        fieldKindReason: String,
        behaviorProfileID: AutocompleteBehaviorProfileID = .notes,
        deletedWithinTwoSeconds: Bool = false
    ) {
        self.acceptanceID = acceptanceID
        self.suggestionID = suggestionID
        self.appBundleIdentifier = appBundleIdentifier
        self.fieldIdentity = fieldIdentity
        self.requestMode = requestMode
        self.acceptMode = acceptMode
        self.acceptedText = acceptedText
        self.textBeforeCursorAtAccept = textBeforeCursorAtAccept
        self.expectedInsertionUTF16Offset = expectedInsertionUTF16Offset
        self.acceptedAt = acceptedAt
        self.profile = profile
        self.fieldKind = fieldKind
        self.fieldKindReason = fieldKindReason
        self.behaviorProfileID = behaviorProfileID
        self.deletedWithinTwoSeconds = deletedWithinTwoSeconds
    }
}
