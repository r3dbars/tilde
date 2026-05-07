import Foundation

public enum CompatibilitySupportState: String, Comparable, Sendable {
    case blocked
    case experimental
    case caveated
    case supported

    public static func < (lhs: CompatibilitySupportState, rhs: CompatibilitySupportState) -> Bool {
        lhs.rank < rhs.rank
    }

    private var rank: Int {
        switch self {
        case .blocked:
            0
        case .experimental:
            1
        case .caveated:
            2
        case .supported:
            3
        }
    }
}

public struct CompatibilitySupportEvaluation: Equatable, Sendable {
    public let bundleIdentifier: String
    public let displayName: String
    public let state: CompatibilitySupportState
    public let reasons: [String]
    public let presentedCount: Int
    public let acceptedAndKeptCount: Int
    public let acceptedAndKeptShownRate: Double
    public let insertionVerificationSuccessRate: Double
    public let p95LatencyMilliseconds: Int?
    public let caretFailureRate: Double
    public let duplicateTextCount: Int
    public let wrongInsertionCount: Int
    public let tabConflictCount: Int
    public let focusStealCount: Int
    public let sensitiveFieldShownCount: Int
    public let annoyanceScore: Double
    public let appFamily: String
    public let minimumSampleSize: Int

    public init(
        bundleIdentifier: String,
        displayName: String,
        state: CompatibilitySupportState,
        reasons: [String],
        presentedCount: Int,
        acceptedAndKeptCount: Int,
        acceptedAndKeptShownRate: Double,
        insertionVerificationSuccessRate: Double,
        p95LatencyMilliseconds: Int?,
        caretFailureRate: Double,
        duplicateTextCount: Int,
        wrongInsertionCount: Int,
        tabConflictCount: Int,
        focusStealCount: Int,
        sensitiveFieldShownCount: Int,
        annoyanceScore: Double,
        appFamily: String = "unknown",
        minimumSampleSize: Int = 20
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.state = state
        self.reasons = reasons
        self.presentedCount = presentedCount
        self.acceptedAndKeptCount = acceptedAndKeptCount
        self.acceptedAndKeptShownRate = acceptedAndKeptShownRate
        self.insertionVerificationSuccessRate = insertionVerificationSuccessRate
        self.p95LatencyMilliseconds = p95LatencyMilliseconds
        self.caretFailureRate = caretFailureRate
        self.duplicateTextCount = duplicateTextCount
        self.wrongInsertionCount = wrongInsertionCount
        self.tabConflictCount = tabConflictCount
        self.focusStealCount = focusStealCount
        self.sensitiveFieldShownCount = sensitiveFieldShownCount
        self.annoyanceScore = annoyanceScore
        self.appFamily = appFamily
        self.minimumSampleSize = minimumSampleSize
    }
}

public struct CompatibilitySupportEvaluator: Equatable, Sendable {
    public let profileStore: CompatibilityProfileStore

    public init(profileStore: CompatibilityProfileStore = .mvp) {
        self.profileStore = profileStore
    }

    public func evaluations(for events: [AutocompleteTraceEvent]) -> [CompatibilitySupportEvaluation] {
        Set(events.map(\.appBundleIdentifier))
            .filter { !$0.isEmpty }
            .sorted()
            .map { evaluate(bundleIdentifier: $0, events: events) }
    }

    public func evaluate(
        bundleIdentifier: String,
        events: [AutocompleteTraceEvent]
    ) -> CompatibilitySupportEvaluation {
        let appEvents = events.filter { $0.appBundleIdentifier == bundleIdentifier }
        let supportStatus = profileStore.supportStatus(for: bundleIdentifier)
        let displayName = displayName(for: bundleIdentifier, supportStatus: supportStatus)
        let appFamily = appFamily(for: bundleIdentifier)
        let minimumSampleSize = minimumSampleSize(for: appFamily)
        let presentedByID = firstPresentedBySuggestionID(from: appEvents)
        let presented = Array(presentedByID.values)
        let presentedIDs = Set(presentedByID.keys)
        let acceptedTextEdited = appEvents.filter { $0.type == .acceptedTextEdited }
        let acceptedAndKeptSuggestionIDs = Set(acceptedTextEdited
            .filter(isAcceptedAndKeptEvent)
            .map(\.suggestionID))
            .intersection(presentedIDs)
        let insertionVerifiedCount = appEvents.filter { $0.type == .insertionVerified }.count
        let insertionFailures = appEvents.filter { $0.type == .insertionFailed }
        let insertionAttemptCount = insertionVerifiedCount + insertionFailures.count
        let insertionSuccessRate = insertionAttemptCount == 0
            ? 0
            : Double(insertionVerifiedCount) / Double(insertionAttemptCount)
        let caretFailureCount = appEvents.filter { $0.type == .caretGeometryFailed }.count
        let caretFailureRate = Double(caretFailureCount) / Double(max(1, presented.count + caretFailureCount))
        let duplicateTextCount = insertionFailures.filter(isDuplicateTextEvent).count
        let wrongInsertionCount = insertionFailures.filter { !isDuplicateTextEvent($0) }.count
        let acceptedThenDeletedCount = appEvents.filter(isAcceptedThenDeletedEvent).count
        let tabConflictCount = appEvents.filter(isTabConflictEvent).count
        let focusStealCount = appEvents.filter(isFocusStealEvent).count
        let sensitiveFieldShownCount = presented.filter(isSensitiveFieldPresentation).count
        let appDisableCount = appEvents.filter { $0.type == .appDisabled }.count
        let detachedWholeAnchorCount = presented.filter(isDetachedWholeAnchorPresentation).count
        let firstShownLatencies = presented.compactMap(\.latencyMilliseconds).sorted()
        let p95LatencyMilliseconds = percentile(0.95, in: firstShownLatencies)
        let summary = AutocompleteTraceAnalyzer().summary(for: appEvents)
        let acceptedAndKeptShownRate = presentedIDs.isEmpty
            ? 0
            : Double(acceptedAndKeptSuggestionIDs.count) / Double(presentedIDs.count)
        let actionableSuppressedRate = summary.presentedCount == 0
            ? Double(summary.actionableSuppressedCount > 0 ? 1 : 0)
            : Double(summary.actionableSuppressedCount) / Double(summary.presentedCount + summary.actionableSuppressedCount)

        var hardBlockReasons: [String] = []
        switch supportStatus {
        case let .supported(profile):
            if profile.isSensitive {
                hardBlockReasons.append("\(profile.displayName) is diagnostics-only because it is sensitive.")
            }
            if !profile.canPresentSuggestions {
                hardBlockReasons.append("\(profile.displayName) cannot present suggestions safely yet.")
            }
        case .denylisted:
            hardBlockReasons.append("App is denylisted.")
        case .unsupported:
            hardBlockReasons.append("No MVP compatibility profile.")
        }

        if duplicateTextCount > 0 {
            hardBlockReasons.append("Duplicate insertion was detected.")
        }
        if wrongInsertionCount > 0 {
            hardBlockReasons.append("Insertion verification failed.")
        }
        if tabConflictCount > 0 {
            hardBlockReasons.append("Tab conflict was detected.")
        }
        if focusStealCount > 0 {
            hardBlockReasons.append("Focus stealing was detected.")
        }
        if acceptedThenDeletedCount > 0 {
            hardBlockReasons.append("Accepted text was deleted within 2 seconds.")
        }
        if sensitiveFieldShownCount > 0 {
            hardBlockReasons.append("Suggestion was shown in a sensitive field kind.")
        }
        if detachedWholeAnchorCount > 0 {
            hardBlockReasons.append("Detached suggestion was shown without a caret rect.")
        }
        if appDisableCount > 0 {
            hardBlockReasons.append("App was disabled during tracing.")
        }
        if insertionAttemptCount >= 3, insertionSuccessRate < 0.90 {
            hardBlockReasons.append("Insertion verification success is below 90%.")
        }
        if caretFailureRate > 0.10 {
            hardBlockReasons.append("Caret failure rate is above 10%.")
        }
        if let p95LatencyMilliseconds, presented.count >= 5, p95LatencyMilliseconds > 1_500 {
            hardBlockReasons.append("p95 first-visible latency is above 1500ms.")
        }
        if summary.annoyanceScore > 0.35 {
            hardBlockReasons.append("Annoyance score is above 0.35.")
        }

        let state: CompatibilitySupportState
        let reasons: [String]
        if !hardBlockReasons.isEmpty {
            state = .blocked
            reasons = hardBlockReasons
        } else if presented.count >= minimumSampleSize
            && acceptedAndKeptShownRate >= 0.15
            && acceptedAndKeptSuggestionIDs.count >= 3
            && insertionSuccessRate >= 0.98
            && (p95LatencyMilliseconds ?? Int.max) <= 750
            && caretFailureRate == 0
            && actionableSuppressedRate <= 0.15
            && summary.annoyanceScore <= 0.10 {
            state = .supported
            reasons = ["Meets supported gates."]
        } else if presented.count >= 10
            && acceptedAndKeptShownRate >= 0.08
            && acceptedAndKeptSuggestionIDs.count >= 1
            && insertionSuccessRate >= 0.95
            && (p95LatencyMilliseconds ?? Int.max) <= 1_000
            && caretFailureRate <= 0.05
            && summary.annoyanceScore <= 0.20 {
            state = .caveated
            reasons = caveatedReasons(
                presentedCount: presented.count,
                minimumSampleSize: minimumSampleSize,
                acceptedAndKeptShownRate: acceptedAndKeptShownRate,
                p95LatencyMilliseconds: p95LatencyMilliseconds,
                actionableSuppressedRate: actionableSuppressedRate,
                events: appEvents
            )
        } else {
            state = .experimental
            reasons = experimentalReasons(
                presentedCount: presented.count,
                acceptedAndKeptCount: acceptedAndKeptSuggestionIDs.count,
                insertionAttemptCount: insertionAttemptCount,
                insertionSuccessRate: insertionSuccessRate,
                p95LatencyMilliseconds: p95LatencyMilliseconds
            )
        }

        return CompatibilitySupportEvaluation(
            bundleIdentifier: bundleIdentifier,
            displayName: displayName,
            state: state,
            reasons: reasons,
            presentedCount: presented.count,
            acceptedAndKeptCount: acceptedAndKeptSuggestionIDs.count,
            acceptedAndKeptShownRate: acceptedAndKeptShownRate,
            insertionVerificationSuccessRate: insertionSuccessRate,
            p95LatencyMilliseconds: p95LatencyMilliseconds,
            caretFailureRate: caretFailureRate,
            duplicateTextCount: duplicateTextCount,
            wrongInsertionCount: wrongInsertionCount,
            tabConflictCount: tabConflictCount,
            focusStealCount: focusStealCount,
            sensitiveFieldShownCount: sensitiveFieldShownCount,
            annoyanceScore: summary.annoyanceScore,
            appFamily: appFamily,
            minimumSampleSize: minimumSampleSize
        )
    }

    private func displayName(
        for bundleIdentifier: String,
        supportStatus: CompatibilitySupportStatus
    ) -> String {
        switch supportStatus {
        case let .supported(profile):
            return profile.displayName
        case .denylisted:
            if bundleIdentifier == "com.apple.Terminal" {
                return "Terminal"
            }
            return bundleIdentifier
        case .unsupported:
            if bundleIdentifier == "com.openai.atlas" {
                return "Atlas"
            }
            return bundleIdentifier
        }
    }

    private func appFamily(for bundleIdentifier: String) -> String {
        switch bundleIdentifier {
        case "com.apple.TextEdit", "com.apple.Notes":
            return "nativeText"
        case "com.google.Chrome":
            return "browserTextarea"
        case "md.obsidian", "com.openai.codex":
            return "electronEditor"
        case "com.apple.mail":
            return "richTextCompose"
        default:
            return "unknown"
        }
    }

    private func minimumSampleSize(for appFamily: String) -> Int {
        switch appFamily {
        case "nativeText":
            return 20
        case "browserTextarea", "electronEditor":
            return 15
        case "richTextCompose":
            return 20
        default:
            return 10
        }
    }

    private func firstPresentedBySuggestionID(
        from events: [AutocompleteTraceEvent]
    ) -> [String: AutocompleteTraceEvent] {
        var eventsByID: [String: AutocompleteTraceEvent] = [:]
        for event in events where event.type == .suggestionPresented && eventsByID[event.suggestionID] == nil {
            eventsByID[event.suggestionID] = event
        }
        return eventsByID
    }

    private func isAcceptedAndKeptEvent(_ event: AutocompleteTraceEvent) -> Bool {
        if event.metadata["strongAcceptedAndKept"] == "true"
            || event.metadata["finalAcceptedAndKept"] == "true" {
            return true
        }

        guard ["10s", "30s", "fieldBlur", "fieldSend"].contains(event.metadata["checkpoint"] ?? "") else {
            return false
        }

        return ["exactKept", "lightlyEditedKept", "partiallyKept"].contains(event.metadata["survivalClass"] ?? "")
    }

    private func isDuplicateTextEvent(_ event: AutocompleteTraceEvent) -> Bool {
        event.metadata["duplicateDetected"] == "true"
            || event.reason.localizedCaseInsensitiveContains("duplicate")
            || event.outcome.localizedCaseInsensitiveContains("duplicate")
    }

    private func isTabConflictEvent(_ event: AutocompleteTraceEvent) -> Bool {
        event.metadata["tabConflict"] == "true"
            || event.reason.localizedCaseInsensitiveContains("tab-conflict")
            || event.reason.localizedCaseInsensitiveContains("tab conflict")
            || event.outcome.localizedCaseInsensitiveContains("tab-conflict")
            || event.outcome.localizedCaseInsensitiveContains("tab conflict")
    }

    private func isFocusStealEvent(_ event: AutocompleteTraceEvent) -> Bool {
        event.metadata["focusStealing"] == "true"
            || event.metadata["focusSteal"] == "true"
            || event.reason.localizedCaseInsensitiveContains("focus-steal")
            || event.reason.localizedCaseInsensitiveContains("focus steal")
            || event.outcome.localizedCaseInsensitiveContains("focus-steal")
            || event.outcome.localizedCaseInsensitiveContains("focus steal")
    }

    private func isAcceptedThenDeletedEvent(_ event: AutocompleteTraceEvent) -> Bool {
        event.type == .acceptedTextEdited
            && event.metadata["survivalClass"] == AcceptanceSurvivalClass.rejectedAfterAccept.rawValue
            && (
                (Int(event.metadata["firstEditDelayMs"] ?? "") ?? Int.max) <= 2_000
                    || event.metadata["checkpoint"] == AcceptanceSurvivalCheckpoint.twoSeconds.rawValue
            )
    }

    private func isSensitiveFieldPresentation(_ event: AutocompleteTraceEvent) -> Bool {
        let fieldKind = event.metadata["fieldKind"] ?? ""
        return ["search", "form", "url", "secure"].contains(fieldKind)
    }

    private func isDetachedWholeAnchorPresentation(_ event: AutocompleteTraceEvent) -> Bool {
        event.metadata["effectiveRenderMode"] == SuggestionRenderMode.floatingMirror.rawValue
            && event.metadata["hasCaretRect"] == "false"
    }

    private func percentile(_ fraction: Double, in sortedValues: [Int]) -> Int? {
        guard !sortedValues.isEmpty else {
            return nil
        }

        let index = min(
            sortedValues.count - 1,
            Int((Double(sortedValues.count - 1) * fraction).rounded())
        )
        return sortedValues[index]
    }

    private func caveatedReasons(
        presentedCount: Int,
        minimumSampleSize: Int,
        acceptedAndKeptShownRate: Double,
        p95LatencyMilliseconds: Int?,
        actionableSuppressedRate: Double,
        events: [AutocompleteTraceEvent]
    ) -> [String] {
        var reasons = ["Meets caveated gates."]
        if presentedCount < minimumSampleSize {
            reasons.append("Needs \(minimumSampleSize) shown suggestions for supported.")
        }
        if acceptedAndKeptShownRate < 0.15 {
            reasons.append("Accepted-and-kept rate is below the supported gate.")
        }
        if let p95LatencyMilliseconds, p95LatencyMilliseconds > 750 {
            reasons.append("p95 first-visible latency is above the supported gate.")
        }
        if actionableSuppressedRate > 0.15 {
            reasons.append("Actionable suppression rate is above the supported gate.")
        }
        if events.contains(where: { $0.type == .suggestionSuppressed && $0.reason == "detached-suggestion-disabled" }) {
            reasons.append("Detached suggestions were safely suppressed.")
        }
        return reasons
    }

    private func experimentalReasons(
        presentedCount: Int,
        acceptedAndKeptCount: Int,
        insertionAttemptCount: Int,
        insertionSuccessRate: Double,
        p95LatencyMilliseconds: Int?
    ) -> [String] {
        var reasons: [String] = []
        if presentedCount < 10 {
            reasons.append("Needs 10 shown suggestions for caveated.")
        }
        if acceptedAndKeptCount < 1 {
            reasons.append("Needs at least one accepted-and-kept suggestion.")
        }
        if insertionAttemptCount == 0 {
            reasons.append("Needs insertion verification proof.")
        } else if insertionSuccessRate < 0.95 {
            reasons.append("Insertion verification success is below caveated gate.")
        }
        if p95LatencyMilliseconds == nil {
            reasons.append("Needs first-visible latency proof.")
        }
        return reasons.isEmpty ? ["Needs more clean trace proof."] : reasons
    }
}
