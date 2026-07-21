import Foundation

/// A privacy-safe decision layer over `AutocompleteTraceSummary` that keeps yield,
/// speed, stability, placement, and safety separate.
public struct TypingYieldScorecard: Equatable, Sendable {
    /// Per-app and overall health, in priority order of what a reviewer should fix first.
    public enum Verdict: String, Equatable, Sendable, CaseIterable {
        /// Not enough shown suggestions to judge.
        case insufficientData = "insufficient-data"
        /// A wrong-field insert, duplicate, or other hard trust failure occurred.
        case unsafe
        /// The caret or panel geometry is unreliable.
        case misplaced
        /// Suggestions were stale or belonged to the wrong context.
        case unstable
        /// Cold first-visible latency is over budget; feel is broken regardless of quality.
        case slow
        /// Shown often but rarely accepted or typed through — interrupts without a payoff.
        case noisy
        /// Accepted but frequently deleted right after — the completion was wrong/unwanted.
        case lowQuality = "low-quality"
        /// Accepted and kept at a healthy rate.
        case healthy

        public var headline: String {
            switch self {
            case .insufficientData: "Not enough data yet"
            case .unsafe: "A hard trust failure occurred"
            case .misplaced: "Ghost placement is unreliable"
            case .unstable: "Suggestions are stale or unstable"
            case .slow: "Too slow to feel good"
            case .noisy: "Shown a lot, helped little"
            case .lowQuality: "Accepted then deleted"
            case .healthy: "Healthy"
            }
        }
    }

    public struct Thresholds: Equatable, Sendable {
        /// Minimum shown suggestions before an app (or the whole set) is judged.
        public let minimumSample: Int
        /// Useful rate (accepted or typed through / shown) below this reads as noisy.
        public let noisyUsefulRate: Double
        /// Fraction of accepted suggestions that must survive ("kept given accepted").
        /// Below this reads as low quality (accept-then-delete).
        public let keptGivenAcceptedFloor: Double
        /// p95 first-visible latency ceiling. Above this the overall verdict is `slow`.
        public let firstVisibleBudgetMilliseconds: Int
        public let caretGeometryFailureRateCeiling: Double
        public let staleOrWrongContextRateCeiling: Double

        public init(
            minimumSample: Int,
            noisyUsefulRate: Double,
            keptGivenAcceptedFloor: Double,
            firstVisibleBudgetMilliseconds: Int,
            caretGeometryFailureRateCeiling: Double = 0.02,
            staleOrWrongContextRateCeiling: Double = 0.01
        ) {
            self.minimumSample = max(1, minimumSample)
            self.noisyUsefulRate = noisyUsefulRate
            self.keptGivenAcceptedFloor = keptGivenAcceptedFloor
            self.firstVisibleBudgetMilliseconds = max(1, firstVisibleBudgetMilliseconds)
            self.caretGeometryFailureRateCeiling = max(0, caretGeometryFailureRateCeiling)
            self.staleOrWrongContextRateCeiling = max(0, staleOrWrongContextRateCeiling)
        }

        /// Defaults tuned for a private beta. `firstVisibleBudgetMilliseconds` mirrors the
        /// cold first-visible model budget locked in `SuggestionRequestSchedulingPolicy`.
        public static let beta = Thresholds(
            minimumSample: 20,
            noisyUsefulRate: 0.10,
            keptGivenAcceptedFloor: 0.50,
            firstVisibleBudgetMilliseconds: 450
        )
    }

    public struct AppRow: Equatable, Sendable, Identifiable {
        public let appBundleIdentifier: String
        public let shown: Int
        public let acceptRate: Double
        public let acceptedAndKeptRate: Double
        public let usefulRate: Double
        public let actionableSuppressed: Int
        public let verdict: Verdict

        public var id: String { appBundleIdentifier }

        public var keptGivenAccepted: Double {
            acceptRate <= 0 ? 0 : min(1, acceptedAndKeptRate / acceptRate)
        }

        public init(
            appBundleIdentifier: String,
            shown: Int,
            acceptRate: Double,
            acceptedAndKeptRate: Double,
            usefulRate: Double,
            actionableSuppressed: Int,
            verdict: Verdict
        ) {
            self.appBundleIdentifier = appBundleIdentifier
            self.shown = shown
            self.acceptRate = acceptRate
            self.acceptedAndKeptRate = acceptedAndKeptRate
            self.usefulRate = usefulRate
            self.actionableSuppressed = actionableSuppressed
            self.verdict = verdict
        }
    }

    public struct SuppressionReasonCount: Equatable, Sendable, Identifiable {
        public let reason: String
        public let count: Int
        public var id: String { reason }

        public init(reason: String, count: Int) {
            self.reason = reason
            self.count = count
        }
    }

    public let thresholds: Thresholds
    public let totalShown: Int
    public let overallAcceptRate: Double
    public let overallAcceptedAndKeptRate: Double
    public let overallUsefulRate: Double
    public let typeThroughRate: Double
    public let matchedTypedCharacterCount: Int
    public let typedOverRate: Double
    public let dismissalRate: Double
    public let staleOrWrongContextRate: Double
    public let caretGeometryFailureRate: Double
    public let doNotShipCount: Int
    public let p50LatencyMilliseconds: Int?
    public let p95LatencyMilliseconds: Int?
    public let rows: [AppRow]
    public let topSuppressionReasons: [SuppressionReasonCount]
    public let overallVerdict: Verdict

    public var overallKeptGivenAccepted: Double {
        overallAcceptRate <= 0 ? 0 : min(1, overallAcceptedAndKeptRate / overallAcceptRate)
    }

    public init(
        summary: AutocompleteTraceSummary,
        thresholds: Thresholds = .beta,
        maximumSuppressionReasons: Int = 8
    ) {
        self.thresholds = thresholds
        self.totalShown = summary.presentedCount
        self.overallAcceptRate = summary.acceptRate
        self.overallAcceptedAndKeptRate = summary.acceptedAndKeptRateShown
        self.overallUsefulRate = summary.usefulRate
        self.typeThroughRate = summary.typeThroughSurvivalRate
        self.matchedTypedCharacterCount = summary.typedThroughCharacterCount
        self.typedOverRate = summary.typedOverRate
        self.dismissalRate = summary.explicitDismissalsPerShown
        self.staleOrWrongContextRate = summary.staleOrWrongContextRate
        self.caretGeometryFailureRate = summary.caretGeometryFailureRate
        self.doNotShipCount = summary.doNotShipCounters.values.reduce(0, +)
        self.p50LatencyMilliseconds = summary.p50LatencyMilliseconds
        self.p95LatencyMilliseconds = summary.p95LatencyMilliseconds

        self.rows = summary.presentedByApp
            .map { app, shown in
                let acceptRate = summary.acceptRateByApp[app] ?? 0
                let acceptedAndKeptRate = summary.acceptedAndKeptRateByApp[app] ?? 0
                let usefulRate = summary.usefulRateByApp[app] ?? 0
                return AppRow(
                    appBundleIdentifier: app,
                    shown: shown,
                    acceptRate: acceptRate,
                    acceptedAndKeptRate: acceptedAndKeptRate,
                    usefulRate: usefulRate,
                    actionableSuppressed: summary.actionableSuppressedByApp[app] ?? 0,
                    verdict: Self.appVerdict(
                        shown: shown,
                        acceptRate: acceptRate,
                        acceptedAndKeptRate: acceptedAndKeptRate,
                        usefulRate: usefulRate,
                        thresholds: thresholds
                    )
                )
            }
            .sorted { lhs, rhs in
                if lhs.shown == rhs.shown {
                    return lhs.appBundleIdentifier < rhs.appBundleIdentifier
                }
                return lhs.shown > rhs.shown
            }

        self.topSuppressionReasons = summary.suppressedByReason
            .map { SuppressionReasonCount(reason: $0.key, count: $0.value) }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count {
                    return lhs.reason < rhs.reason
                }
                return lhs.count > rhs.count
            }
            .prefix(max(0, maximumSuppressionReasons))
            .map { $0 }

        self.overallVerdict = Self.overallVerdict(
            shown: summary.presentedCount,
            acceptRate: summary.acceptRate,
            acceptedAndKeptRate: summary.acceptedAndKeptRateShown,
            usefulRate: summary.usefulRate,
            p95LatencyMilliseconds: summary.p95LatencyMilliseconds,
            caretGeometryFailureRate: summary.caretGeometryFailureRate,
            staleOrWrongContextRate: summary.staleOrWrongContextRate,
            doNotShipCount: self.doNotShipCount,
            thresholds: thresholds
        )
    }

    /// Quality-only verdict for a single app. Latency is judged once, at the overall level,
    /// because the summary does not carry per-app latency percentiles.
    static func appVerdict(
        shown: Int,
        acceptRate: Double,
        acceptedAndKeptRate: Double,
        usefulRate: Double,
        thresholds: Thresholds
    ) -> Verdict {
        guard shown >= thresholds.minimumSample else {
            return .insufficientData
        }

        if usefulRate < thresholds.noisyUsefulRate {
            return .noisy
        }

        if acceptRate > 0, acceptedAndKeptRate / acceptRate < thresholds.keptGivenAcceptedFloor {
            return .lowQuality
        }

        return .healthy
    }

    static func overallVerdict(
        shown: Int,
        acceptRate: Double,
        acceptedAndKeptRate: Double,
        usefulRate: Double,
        p95LatencyMilliseconds: Int?,
        caretGeometryFailureRate: Double = 0,
        staleOrWrongContextRate: Double = 0,
        doNotShipCount: Int = 0,
        thresholds: Thresholds
    ) -> Verdict {
        if doNotShipCount > 0 {
            return .unsafe
        }

        guard shown >= thresholds.minimumSample else {
            return .insufficientData
        }

        if caretGeometryFailureRate > thresholds.caretGeometryFailureRateCeiling {
            return .misplaced
        }

        if staleOrWrongContextRate > thresholds.staleOrWrongContextRateCeiling {
            return .unstable
        }

        if let p95 = p95LatencyMilliseconds, p95 > thresholds.firstVisibleBudgetMilliseconds {
            return .slow
        }

        return appVerdict(
            shown: shown,
            acceptRate: acceptRate,
            acceptedAndKeptRate: acceptedAndKeptRate,
            usefulRate: usefulRate,
            thresholds: thresholds
        )
    }

    public var markdown: String {
        var lines: [String] = [
            "## Typing Yield Scorecard",
            "",
            "- overall: \(overallVerdict.rawValue) — \(overallVerdict.headline)",
            "- shown: \(totalShown)",
            "- useful rate: \(Self.percent(overallUsefulRate)) (accepted or typed through)",
            "- accept rate: \(Self.percent(overallAcceptRate))",
            "- typed-through rate: \(Self.percent(typeThroughRate)); matched characters: \(matchedTypedCharacterCount)",
            "- accepted-and-kept rate: \(Self.percent(overallAcceptedAndKeptRate)) "
                + "(kept-given-accepted \(Self.percent(overallKeptGivenAccepted)))",
            "- latency: p50 \(Self.ms(p50LatencyMilliseconds)), p95 \(Self.ms(p95LatencyMilliseconds)) "
                + "(budget \(thresholds.firstVisibleBudgetMilliseconds)ms)",
            "- stability: typed-over \(Self.percent(typedOverRate)), dismissed \(Self.percent(dismissalRate)), "
                + "stale/wrong-context \(Self.percent(staleOrWrongContextRate))",
            "- placement: caret failures \(Self.percent(caretGeometryFailureRate))",
            "- safety: do-not-ship events \(doNotShipCount)",
            "",
            "### By App"
        ]

        if rows.isEmpty {
            lines.append("- No shown suggestions recorded.")
        } else {
            lines += rows.map { row in
                "- \(row.appBundleIdentifier): \(row.verdict.rawValue) — shown \(row.shown), "
                    + "accept \(Self.percent(row.acceptRate)), "
                    + "kept \(Self.percent(row.acceptedAndKeptRate)), "
                    + "useful \(Self.percent(row.usefulRate)), "
                    + "suppressed \(row.actionableSuppressed)"
            }
        }

        if !topSuppressionReasons.isEmpty {
            lines.append("")
            lines.append("### Top Suppression Reasons")
            lines += topSuppressionReasons.map { "- \($0.reason): \($0.count)" }
        }

        return lines.joined(separator: "\n")
    }

    private static func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private static func ms(_ value: Int?) -> String {
        value.map { "\($0)ms" } ?? "n/a"
    }
}
