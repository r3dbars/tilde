import Foundation

public struct AutocompleteNonAnnoyanceThresholds: Equatable, Sendable {
    public var maxShownPerActiveMinute: Double
    public var maxDismissalsPerShown: Double
    public var maxTypedOverWithinOneSecondRate: Double
    public var maxAcceptedThenDeletedRate: Double
    public var maxImmediateResurfacing: Int
    public var maxLateSuggestionsShown: Int
    public var minLateSuggestionsHiddenRate: Double
    public var maxPauseDisablePerShown: Double
    public var minSevereSuppressionRate: Double

    public init(
        maxShownPerActiveMinute: Double = 2.0,
        maxDismissalsPerShown: Double = 0.25,
        maxTypedOverWithinOneSecondRate: Double = 0.20,
        maxAcceptedThenDeletedRate: Double = 0.05,
        maxImmediateResurfacing: Int = 0,
        maxLateSuggestionsShown: Int = 0,
        minLateSuggestionsHiddenRate: Double = 1.0,
        maxPauseDisablePerShown: Double = 0.10,
        minSevereSuppressionRate: Double = 1.0
    ) {
        self.maxShownPerActiveMinute = maxShownPerActiveMinute
        self.maxDismissalsPerShown = maxDismissalsPerShown
        self.maxTypedOverWithinOneSecondRate = maxTypedOverWithinOneSecondRate
        self.maxAcceptedThenDeletedRate = maxAcceptedThenDeletedRate
        self.maxImmediateResurfacing = maxImmediateResurfacing
        self.maxLateSuggestionsShown = maxLateSuggestionsShown
        self.minLateSuggestionsHiddenRate = minLateSuggestionsHiddenRate
        self.maxPauseDisablePerShown = maxPauseDisablePerShown
        self.minSevereSuppressionRate = minSevereSuppressionRate
    }
}

public struct AutocompleteNonAnnoyanceReport: Equatable, Sendable {
    public let activeWritingMinutes: Double
    public let shown: Int
    public let dismissals: Int
    public let typedOverWithinOneSecond: Int
    public let acceptedThenDeleted: Int
    public let immediateResurfacing: Int
    public let lateSuggestionsShown: Int
    public let lateSuggestionsHidden: Int
    public let pauseDisableEvents: Int
    public let severeSignals: Int
    public let severeSignalsSuppressed: Int
    public let gateFailures: [String]

    public var shownPerActiveMinute: Double {
        rate(Double(shown), activeWritingMinutes)
    }

    public var dismissalsPerShown: Double {
        rate(Double(dismissals), Double(shown))
    }

    public var typedOverWithinOneSecondRate: Double {
        rate(Double(typedOverWithinOneSecond), Double(shown))
    }

    public var acceptedThenDeletedRate: Double {
        rate(Double(acceptedThenDeleted), Double(shown))
    }

    public var lateSuggestionsHiddenRate: Double {
        rate(Double(lateSuggestionsHidden), Double(lateSuggestionsHidden + lateSuggestionsShown))
    }

    public var pauseDisablePerShown: Double {
        rate(Double(pauseDisableEvents), Double(shown))
    }

    public var severeSuppressionRate: Double {
        rate(Double(severeSignalsSuppressed), Double(severeSignals))
    }

    public var gatePassed: Bool {
        gateFailures.isEmpty
    }

    public func plainTextReport() -> String {
        """
        Non-annoyance report
        Gate: \(gatePassed ? "pass" : "fail")
        Active writing minutes: \(Self.format(activeWritingMinutes))
        Shown/min: \(Self.format(shownPerActiveMinute)) (\(shown) shown)
        Dismissals/shown: \(Self.percent(dismissalsPerShown)) (\(dismissals)/\(shown))
        Typed-over within 1s: \(Self.percent(typedOverWithinOneSecondRate)) (\(typedOverWithinOneSecond)/\(shown))
        Accepted-then-deleted: \(acceptedThenDeleted)
        Immediate resurfacing: \(immediateResurfacing)
        Late suggestions shown: \(lateSuggestionsShown)
        Late suggestions hidden: \(lateSuggestionsHidden)/\(lateSuggestionsHidden + lateSuggestionsShown) (\(Self.percent(lateSuggestionsHiddenRate)))
        Pause/disable events: \(pauseDisableEvents)
        Severe suppression coverage: \(severeSignalsSuppressed)/\(severeSignals) (\(Self.percent(severeSuppressionRate)))
        Failures: \(gateFailures.isEmpty ? "none" : gateFailures.joined(separator: "; "))
        """
    }

    private func rate(_ numerator: Double, _ denominator: Double) -> Double {
        guard denominator > 0 else {
            return 0
        }
        return numerator / denominator
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private static func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}

public struct AutocompleteNonAnnoyanceReporter: Equatable, Sendable {
    public let thresholds: AutocompleteNonAnnoyanceThresholds

    public init(thresholds: AutocompleteNonAnnoyanceThresholds = AutocompleteNonAnnoyanceThresholds()) {
        self.thresholds = thresholds
    }

    public func report(for events: [AutocompleteTraceEvent]) -> AutocompleteNonAnnoyanceReport {
        reportForRedactedEvents(events.map { $0.redactedForDefaultTrace() })
    }

    public func reportForRedactedEvents(_ events: [AutocompleteTraceEvent]) -> AutocompleteNonAnnoyanceReport {
        let sortedEvents = events.sorted { lhs, rhs in
            timestamp(for: lhs) < timestamp(for: rhs)
        }
        let presentations = sortedEvents.filter { $0.type == .suggestionPresented }
        let dismissals = sortedEvents.filter(isDismissal)
        let typedOverWithinOneSecond = typedOverWithinOneSecondCount(in: sortedEvents)
        let acceptedThenDeletedEvents = sortedEvents.filter(isAcceptedThenDeleted)
        let acceptedThenDeleted = uniqueAcceptanceKeys(in: acceptedThenDeletedEvents).count
        let immediateResurfacing = immediateResurfacingCount(in: sortedEvents)
        let lateSuggestionsShown = presentations.filter(isLateSuggestion).count
        let lateSuggestionsHidden = sortedEvents.filter {
            $0.type == .suggestionHidden && isLateSuggestion($0)
        }.count
        let pauseDisableEvents = sortedEvents.filter(isPauseOrDisable).count
        let severeCoverage = severeSuppressionCoverage(in: sortedEvents, severeEvents: acceptedThenDeletedEvents)
        let activeWritingMinutes = activeMinutes(in: sortedEvents)

        var report = AutocompleteNonAnnoyanceReport(
            activeWritingMinutes: activeWritingMinutes,
            shown: presentations.count,
            dismissals: dismissals.count,
            typedOverWithinOneSecond: typedOverWithinOneSecond,
            acceptedThenDeleted: acceptedThenDeleted,
            immediateResurfacing: immediateResurfacing,
            lateSuggestionsShown: lateSuggestionsShown,
            lateSuggestionsHidden: lateSuggestionsHidden,
            pauseDisableEvents: pauseDisableEvents,
            severeSignals: severeCoverage.total,
            severeSignalsSuppressed: severeCoverage.suppressed,
            gateFailures: []
        )
        report = AutocompleteNonAnnoyanceReport(
            activeWritingMinutes: report.activeWritingMinutes,
            shown: report.shown,
            dismissals: report.dismissals,
            typedOverWithinOneSecond: report.typedOverWithinOneSecond,
            acceptedThenDeleted: report.acceptedThenDeleted,
            immediateResurfacing: report.immediateResurfacing,
            lateSuggestionsShown: report.lateSuggestionsShown,
            lateSuggestionsHidden: report.lateSuggestionsHidden,
            pauseDisableEvents: report.pauseDisableEvents,
            severeSignals: report.severeSignals,
            severeSignalsSuppressed: report.severeSignalsSuppressed,
            gateFailures: gateFailures(for: report)
        )
        return report
    }

    private func gateFailures(for report: AutocompleteNonAnnoyanceReport) -> [String] {
        var failures: [String] = []
        if report.shownPerActiveMinute > thresholds.maxShownPerActiveMinute {
            failures.append("shown/min above \(thresholds.maxShownPerActiveMinute)")
        }
        if report.dismissalsPerShown > thresholds.maxDismissalsPerShown {
            failures.append("dismissals/shown above \(thresholds.maxDismissalsPerShown)")
        }
        if report.typedOverWithinOneSecondRate > thresholds.maxTypedOverWithinOneSecondRate {
            failures.append("typed-over within 1s above \(thresholds.maxTypedOverWithinOneSecondRate)")
        }
        if report.acceptedThenDeletedRate > thresholds.maxAcceptedThenDeletedRate {
            failures.append("accepted-then-deleted above \(thresholds.maxAcceptedThenDeletedRate)")
        }
        if report.immediateResurfacing > thresholds.maxImmediateResurfacing {
            failures.append("immediate resurfacing above \(thresholds.maxImmediateResurfacing)")
        }
        if report.lateSuggestionsShown > thresholds.maxLateSuggestionsShown {
            failures.append("late suggestions shown above \(thresholds.maxLateSuggestionsShown)")
        }
        if report.lateSuggestionsHidden + report.lateSuggestionsShown > 0,
           report.lateSuggestionsHiddenRate < thresholds.minLateSuggestionsHiddenRate {
            failures.append("late suggestions hidden below \(thresholds.minLateSuggestionsHiddenRate)")
        }
        if report.pauseDisablePerShown > thresholds.maxPauseDisablePerShown {
            failures.append("pause/disable rate above \(thresholds.maxPauseDisablePerShown)")
        }
        if report.severeSignals > 0,
           report.severeSuppressionRate < thresholds.minSevereSuppressionRate {
            failures.append("severe suppression coverage below \(thresholds.minSevereSuppressionRate)")
        }
        return failures
    }

    private func activeMinutes(in events: [AutocompleteTraceEvent]) -> Double {
        let dates = events.compactMap(timestamp)
        guard let first = dates.first,
              let last = dates.last else {
            return 1
        }
        return max(1, last.timeIntervalSince(first) / 60)
    }

    private func typedOverWithinOneSecondCount(in events: [AutocompleteTraceEvent]) -> Int {
        var presentedAtByKey: [String: Date] = [:]
        var count = 0
        for event in events {
            let key = suggestionKey(event)
            switch event.type {
            case .suggestionPresented:
                presentedAtByKey[key] = timestamp(for: event)
            case .suggestionTypedOver:
                guard let presentedAt = presentedAtByKey[key] else {
                    continue
                }
                if timestamp(for: event).timeIntervalSince(presentedAt) <= 1 {
                    count += 1
                }
            default:
                continue
            }
        }
        return count
    }

    private func immediateResurfacingCount(in events: [AutocompleteTraceEvent]) -> Int {
        struct RecentRejection {
            let event: AutocompleteTraceEvent
            var coveredBySuppression: Bool
        }

        var rejections: [RecentRejection] = []
        var count = 0

        for event in events {
            if event.type == .suggestionPresented {
                let presentedAt = timestamp(for: event)
                if rejections.contains(where: {
                    !$0.coveredBySuppression
                        && sameSurface($0.event, event)
                        && presentedAt.timeIntervalSince(timestamp(for: $0.event)) > 0
                        && presentedAt.timeIntervalSince(timestamp(for: $0.event)) <= 2
                }) {
                    count += 1
                }
                rejections.removeAll {
                    presentedAt.timeIntervalSince(timestamp(for: $0.event)) > 2
                }
                continue
            }

            if event.type == .suggestionSuppressed,
               isImmediateResurfacingSuppression(event) {
                let suppressedAt = timestamp(for: event)
                for index in rejections.indices where sameSurface(rejections[index].event, event) {
                    let delay = suppressedAt.timeIntervalSince(timestamp(for: rejections[index].event))
                    if delay >= 0 && delay <= 2 {
                        rejections[index].coveredBySuppression = true
                    }
                }
                continue
            }

            if isDismissal(event) || event.type == .suggestionTypedOver || isAcceptedThenDeleted(event) {
                rejections.append(RecentRejection(event: event, coveredBySuppression: false))
            }
        }
        return count
    }

    private func isImmediateResurfacingSuppression(_ event: AutocompleteTraceEvent) -> Bool {
        let cooldownReason = event.metadata["prefixCooldownReason"] ?? event.reason
        return cooldownReason == PrefixFamilyCooldownReason.typedOver.rawValue
            || cooldownReason == PrefixFamilyCooldownReason.escapeDismissal.rawValue
            || cooldownReason == PrefixFamilyCooldownReason.acceptedThenDeleted.rawValue
            || event.triggerReason == "annoyance-signal"
    }

    private func severeSuppressionCoverage(
        in events: [AutocompleteTraceEvent],
        severeEvents: [AutocompleteTraceEvent]
    ) -> (suppressed: Int, total: Int) {
        let uniqueEvents = Dictionary(grouping: severeEvents, by: acceptanceKey)
            .compactMap { $0.value.first }
        let suppressed = uniqueEvents.filter { severeEvent in
            if severeEvent.metadata["prefixCooldownReason"] == PrefixFamilyCooldownReason.acceptedThenDeleted.rawValue {
                return true
            }
            return events.contains { candidate in
                candidate.type == .suggestionSuppressed
                    && sameSurface(severeEvent, candidate)
                    && timestamp(for: candidate).timeIntervalSince(timestamp(for: severeEvent)) >= 0
                    && timestamp(for: candidate).timeIntervalSince(timestamp(for: severeEvent)) <= 120
                    && (
                        candidate.metadata["prefixCooldownReason"] == PrefixFamilyCooldownReason.acceptedThenDeleted.rawValue
                            || candidate.triggerReason == "annoyance-signal"
                            || candidate.metadata["annoyanceSignal"] == "acceptedThenDeleted"
                    )
            }
        }.count
        return (suppressed, uniqueEvents.count)
    }

    private func isDismissal(_ event: AutocompleteTraceEvent) -> Bool {
        event.type == .suggestionHidden && (
            event.reason.localizedCaseInsensitiveContains("escape")
                || event.reason.localizedCaseInsensitiveContains("dismiss")
                || event.outcome.localizedCaseInsensitiveContains("dismiss")
        )
    }

    private func isAcceptedThenDeleted(_ event: AutocompleteTraceEvent) -> Bool {
        let joined = [
            event.triggerReason,
            event.outcome,
            event.reason,
            event.metadata["annoyanceSignal"] ?? "",
            event.metadata["survivalClass"] ?? "",
            event.metadata["finishReason"] ?? ""
        ].joined(separator: " ")
        return joined.localizedCaseInsensitiveContains("acceptedthendeleted")
            || joined.localizedCaseInsensitiveContains("accepted-then-deleted")
            || (event.type == .acceptedTextEdited
                && event.metadata["deletedWithinTwoSeconds"] == "true")
            || (event.type == .acceptanceRetentionCleared
                && event.reason.localizedCaseInsensitiveContains("deleted"))
    }

    private func isLateSuggestion(_ event: AutocompleteTraceEvent) -> Bool {
        if (event.latencyMilliseconds ?? 0) > 750 {
            return true
        }
        let joined = [
            event.reason,
            event.outcome,
            event.metadata["lateSuggestion"] ?? "",
            event.metadata["staleLateSuggestion"] ?? "",
            event.metadata["displayDecision"] ?? "",
            event.metadata["suppressionReason"] ?? ""
        ].joined(separator: " ")
        return joined.localizedCaseInsensitiveContains("late")
            || joined.localizedCaseInsensitiveContains("stale")
    }

    private func isPauseOrDisable(_ event: AutocompleteTraceEvent) -> Bool {
        event.type == .appPaused
            || event.type == .fieldPaused
            || event.type == .appDisabled
    }

    private func sameSurface(_ lhs: AutocompleteTraceEvent, _ rhs: AutocompleteTraceEvent) -> Bool {
        lhs.appBundleIdentifier == rhs.appBundleIdentifier
            && lhs.fieldIdentity == rhs.fieldIdentity
            && lhs.requestMode == rhs.requestMode
    }

    private func uniqueAcceptanceKeys(in events: [AutocompleteTraceEvent]) -> Set<String> {
        Set(events.map(acceptanceKey))
    }

    private func suggestionKey(_ event: AutocompleteTraceEvent) -> String {
        if !event.suggestionID.isEmpty {
            return event.suggestionID
        }
        return event.id
    }

    private func acceptanceKey(_ event: AutocompleteTraceEvent) -> String {
        if let acceptanceID = event.metadata["acceptanceID"], !acceptanceID.isEmpty {
            return acceptanceID
        }
        if !event.suggestionID.isEmpty {
            return event.suggestionID
        }
        return event.id
    }

    private func timestamp(for event: AutocompleteTraceEvent) -> Date {
        timestamp(event) ?? Date(timeIntervalSince1970: 0)
    }

    private func timestamp(_ event: AutocompleteTraceEvent) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: event.timestamp) {
            return date
        }
        return ISO8601DateFormatter().date(from: event.timestamp)
    }
}
