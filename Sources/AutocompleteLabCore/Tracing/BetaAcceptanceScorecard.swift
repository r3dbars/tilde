import Foundation

/// A compact, decision-oriented rollup of the rich `AutocompleteTraceSummary` into the few
/// numbers a human reviewing a beta actually acts on: for each app, how often suggestions
/// were shown, how often they were accepted, and — the north star — how often they were
/// accepted *and kept*. Each app gets a one-word health verdict so a reviewer can tell where
/// to look without reading the full analyzer dump.
///
/// This type performs no I/O and stores no raw text; it consumes an already privacy-filtered
/// `AutocompleteTraceSummary`. It is the "turn data into a decision" layer on top of
/// `AutocompleteTraceAnalyzer`: the analyzer answers "what happened", this answers "is it good,
/// and where is it not".
public struct BetaAcceptanceScorecard: Equatable, Sendable {
    /// Per-app and overall health, in priority order of what a reviewer should fix first.
    public enum Verdict: String, Equatable, Sendable, CaseIterable {
        /// Not enough shown suggestions to judge.
        case insufficientData = "insufficient-data"
        /// Cold first-visible latency is over budget; feel is broken regardless of quality.
        case slow
        /// Shown often but rarely accepted — interrupts without a payoff.
        case noisy
        /// Accepted but frequently deleted right after — the completion was wrong/unwanted.
        case lowQuality = "low-quality"
        /// Accepted and kept at a healthy rate.
        case healthy

        public var headline: String {
            switch self {
            case .insufficientData: "Not enough data yet"
            case .slow: "Too slow to feel good"
            case .noisy: "Shown a lot, accepted little"
            case .lowQuality: "Accepted then deleted"
            case .healthy: "Healthy"
            }
        }
    }

    public struct Thresholds: Equatable, Sendable {
        /// Minimum shown suggestions before an app (or the whole set) is judged.
        public let minimumSample: Int
        /// Accept rate (accepted / shown) below this reads as noisy.
        public let noisyAcceptRate: Double
        /// Fraction of accepted suggestions that must survive ("kept given accepted").
        /// Below this reads as low quality (accept-then-delete).
        public let keptGivenAcceptedFloor: Double
        /// p95 first-visible latency ceiling. Above this the overall verdict is `slow`.
        public let firstVisibleBudgetMilliseconds: Int

        public init(
            minimumSample: Int,
            noisyAcceptRate: Double,
            keptGivenAcceptedFloor: Double,
            firstVisibleBudgetMilliseconds: Int
        ) {
            self.minimumSample = max(1, minimumSample)
            self.noisyAcceptRate = noisyAcceptRate
            self.keptGivenAcceptedFloor = keptGivenAcceptedFloor
            self.firstVisibleBudgetMilliseconds = max(1, firstVisibleBudgetMilliseconds)
        }

        /// Defaults tuned for a private beta. `firstVisibleBudgetMilliseconds` mirrors the
        /// cold first-visible model budget locked in `SuggestionRequestSchedulingPolicy`.
        public static let beta = Thresholds(
            minimumSample: 20,
            noisyAcceptRate: 0.10,
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

        /// Fraction of accepted suggestions that survived ("kept given accepted").
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
    public let p50LatencyMilliseconds: Int?
    public let p95LatencyMilliseconds: Int?
    public let rows: [AppRow]
    public let topSuppressionReasons: [SuppressionReasonCount]
    public let overallVerdict: Verdict

    /// Fraction of accepted suggestions that survived, across all apps.
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
            p95LatencyMilliseconds: summary.p95LatencyMilliseconds,
            thresholds: thresholds
        )
    }

    /// Quality-only verdict for a single app. Latency is judged once, at the overall level,
    /// because the summary does not carry per-app latency percentiles.
    static func appVerdict(
        shown: Int,
        acceptRate: Double,
        acceptedAndKeptRate: Double,
        thresholds: Thresholds
    ) -> Verdict {
        guard shown >= thresholds.minimumSample else {
            return .insufficientData
        }

        if acceptRate < thresholds.noisyAcceptRate {
            return .noisy
        }

        let keptGivenAccepted = acceptRate <= 0 ? 0 : acceptedAndKeptRate / acceptRate
        if keptGivenAccepted < thresholds.keptGivenAcceptedFloor {
            return .lowQuality
        }

        return .healthy
    }

    static func overallVerdict(
        shown: Int,
        acceptRate: Double,
        acceptedAndKeptRate: Double,
        p95LatencyMilliseconds: Int?,
        thresholds: Thresholds
    ) -> Verdict {
        guard shown >= thresholds.minimumSample else {
            return .insufficientData
        }

        // Latency dominates: if the cold first paint is over budget it does not matter how
        // good the completions are, so surface that first.
        if let p95 = p95LatencyMilliseconds, p95 > thresholds.firstVisibleBudgetMilliseconds {
            return .slow
        }

        return appVerdict(
            shown: shown,
            acceptRate: acceptRate,
            acceptedAndKeptRate: acceptedAndKeptRate,
            thresholds: thresholds
        )
    }

    public var markdown: String {
        var lines: [String] = [
            "## Beta Acceptance Scorecard",
            "",
            "- overall: \(overallVerdict.rawValue) — \(overallVerdict.headline)",
            "- shown: \(totalShown)",
            "- accept rate: \(Self.percent(overallAcceptRate))",
            "- accepted-and-kept rate: \(Self.percent(overallAcceptedAndKeptRate)) "
                + "(kept-given-accepted \(Self.percent(overallKeptGivenAccepted)))",
            "- latency: p50 \(Self.ms(p50LatencyMilliseconds)), p95 \(Self.ms(p95LatencyMilliseconds)) "
                + "(budget \(thresholds.firstVisibleBudgetMilliseconds)ms)",
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
