import Foundation

public enum AnnoyanceSignal: String, Codable, Equatable, Sendable {
    case wrongInsertion
    case duplicateText
    case focusStealing
    case tabConflict
    case rapidEscDismissal
    case typedOver
    case acceptedThenDeleted
    case searchOrFormLeakage
    case overlayFlicker
    case repeatedRejection
    case manualPause
    case appDisable
    case caretGeometryFailed
    case accepted
    case acceptedAndKept
    case typedThrough
}

public struct AnnoyanceContext: Equatable, Sendable {
    public let appBundleIdentifier: String
    public let fieldIdentifier: String
    public let requestMode: CompletionRequestMode?
    public let fieldKind: AXFieldKind

    public init(
        appBundleIdentifier: String,
        fieldIdentifier: String,
        requestMode: CompletionRequestMode? = nil,
        fieldKind: AXFieldKind = .unknown
    ) {
        self.appBundleIdentifier = appBundleIdentifier
        self.fieldIdentifier = fieldIdentifier
        self.requestMode = requestMode
        self.fieldKind = fieldKind
    }
}

public enum QuietMode: Equatable, Sendable {
    case normal
    case field(until: Date, reason: AnnoyanceSignal, score: Double)
    case app(until: Date, reason: AnnoyanceSignal, score: Double)
    case global(until: Date, reason: AnnoyanceSignal, score: Double)

    public var isActive: Bool {
        self != .normal
    }

    public var traceReason: String {
        switch self {
        case .normal:
            "normal"
        case .field:
            "quiet-mode-field"
        case .app:
            "quiet-mode-app"
        case .global:
            "quiet-mode-global"
        }
    }

    public var summary: String {
        switch self {
        case .normal:
            "normal"
        case let .field(until, reason, score):
            "field quiet until \(Self.format(until)) after \(reason.rawValue) score \(Self.format(score))"
        case let .app(until, reason, score):
            "app quiet until \(Self.format(until)) after \(reason.rawValue) score \(Self.format(score))"
        case let .global(until, reason, score):
            "global quiet until \(Self.format(until)) after \(reason.rawValue) score \(Self.format(score))"
        }
    }

    public var metadata: [String: String] {
        switch self {
        case .normal:
            ["quietMode": "normal"]
        case let .field(until, reason, score):
            quietMetadata(scope: "field", until: until, reason: reason, score: score)
        case let .app(until, reason, score):
            quietMetadata(scope: "app", until: until, reason: reason, score: score)
        case let .global(until, reason, score):
            quietMetadata(scope: "global", until: until, reason: reason, score: score)
        }
    }

    private func quietMetadata(
        scope: String,
        until: Date,
        reason: AnnoyanceSignal,
        score: Double
    ) -> [String: String] {
        [
            "quietMode": scope,
            "quietUntil": ISO8601DateFormatter().string(from: until),
            "quietReason": reason.rawValue,
            "quietScore": Self.format(score)
        ]
    }

    private static func format(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.3f", value)
    }
}

public struct AnnoyanceUpdate: Equatable, Sendable {
    public let signal: AnnoyanceSignal
    public let fieldScore: Double
    public let appScore: Double
    public let globalScore: Double
    public let startedQuietModes: [QuietMode]
}

public struct AnnoyanceSuppressor: Equatable, Sendable {
    public let halfLifeSeconds: TimeInterval
    public let fieldQuietDurationSeconds: TimeInterval
    public let appQuietDurationSeconds: TimeInterval
    public let globalQuietDurationSeconds: TimeInterval
    public let fieldQuietThreshold: Double
    public let appQuietThreshold: Double
    public let globalQuietThreshold: Double

    private var fieldBuckets: [String: ScoreBucket] = [:]
    private var appBuckets: [String: ScoreBucket] = [:]
    private var globalBucket = ScoreBucket()
    private var fieldQuietModes: [String: QuietMode] = [:]
    private var appQuietModes: [String: QuietMode] = [:]
    private var globalQuietMode: QuietMode = .normal
    private var severeEventCountsByAppDay: [String: Int] = [:]

    public init(
        halfLifeSeconds: TimeInterval = 20 * 60,
        fieldQuietDurationSeconds: TimeInterval = 15 * 60,
        appQuietDurationSeconds: TimeInterval = 30 * 60,
        globalQuietDurationSeconds: TimeInterval = 5 * 60,
        fieldQuietThreshold: Double = 0.5,
        appQuietThreshold: Double = 1.5,
        globalQuietThreshold: Double = 2.5
    ) {
        self.halfLifeSeconds = halfLifeSeconds
        self.fieldQuietDurationSeconds = fieldQuietDurationSeconds
        self.appQuietDurationSeconds = appQuietDurationSeconds
        self.globalQuietDurationSeconds = globalQuietDurationSeconds
        self.fieldQuietThreshold = fieldQuietThreshold
        self.appQuietThreshold = appQuietThreshold
        self.globalQuietThreshold = globalQuietThreshold
    }

    public mutating func record(
        _ signal: AnnoyanceSignal,
        context: AnnoyanceContext,
        now: Date = Date()
    ) -> AnnoyanceUpdate {
        expireQuietModes(now: now)

        let delta = Self.weight(for: signal)
        let fieldBucket = updatedBucket(
            fieldBuckets[context.fieldIdentifier] ?? ScoreBucket(),
            delta: delta,
            multiplier: 1.0,
            now: now
        )
        fieldBuckets[context.fieldIdentifier] = fieldBucket

        let appBucket = updatedBucket(
            appBuckets[context.appBundleIdentifier] ?? ScoreBucket(),
            delta: delta,
            multiplier: 0.6,
            now: now
        )
        appBuckets[context.appBundleIdentifier] = appBucket

        globalBucket = updatedBucket(globalBucket, delta: delta, multiplier: 0.25, now: now)
        let fieldScore = fieldBucket.score
        let appScore = appBucket.score
        let globalScore = globalBucket.score

        var started: [QuietMode] = []
        if Self.hardStopsField(signal) || fieldScore >= fieldQuietThreshold {
            let mode = QuietMode.field(
                until: now.addingTimeInterval(fieldQuietDurationSeconds),
                reason: signal,
                score: fieldScore
            )
            fieldQuietModes[context.fieldIdentifier] = mode
            started.append(mode)
        }

        let severeEventCountToday = recordSevereEventIfNeeded(
            signal,
            appBundleIdentifier: context.appBundleIdentifier,
            now: now
        )

        if appScore >= appQuietThreshold || severeEventCountToday >= 2 {
            let mode = QuietMode.app(
                until: now.addingTimeInterval(appQuietDurationSeconds),
                reason: signal,
                score: max(appScore, Double(severeEventCountToday))
            )
            appQuietModes[context.appBundleIdentifier] = mode
            started.append(mode)
        }

        if globalScore >= globalQuietThreshold {
            let mode = QuietMode.global(
                until: now.addingTimeInterval(globalQuietDurationSeconds),
                reason: signal,
                score: globalScore
            )
            globalQuietMode = mode
            started.append(mode)
        }

        return AnnoyanceUpdate(
            signal: signal,
            fieldScore: fieldScore,
            appScore: appScore,
            globalScore: globalScore,
            startedQuietModes: started
        )
    }

    public mutating func quietMode(
        for context: AnnoyanceContext,
        now: Date = Date()
    ) -> QuietMode {
        expireQuietModes(now: now)

        if globalQuietMode.isActive {
            return globalQuietMode
        }

        if let appMode = appQuietModes[context.appBundleIdentifier], appMode.isActive {
            return appMode
        }

        if let fieldMode = fieldQuietModes[context.fieldIdentifier], fieldMode.isActive {
            return fieldMode
        }

        return .normal
    }

    public mutating func clearField(_ fieldIdentifier: String) {
        fieldBuckets[fieldIdentifier] = nil
        fieldQuietModes[fieldIdentifier] = nil
    }

    public mutating func score(
        for context: AnnoyanceContext,
        now: Date = Date()
    ) -> Double {
        expireQuietModes(now: now)
        return fieldBuckets[context.fieldIdentifier]?.score(at: now, halfLifeSeconds: halfLifeSeconds) ?? 0
    }

    private func updatedBucket(
        _ bucket: ScoreBucket,
        delta: Double,
        multiplier: Double,
        now: Date
    ) -> ScoreBucket {
        let score = max(0, bucket.score(at: now, halfLifeSeconds: halfLifeSeconds) + delta * multiplier)
        return ScoreBucket(score: score, updatedAt: now)
    }

    private mutating func expireQuietModes(now: Date) {
        fieldQuietModes = fieldQuietModes.filter { _, mode in mode.isActive(at: now) }
        appQuietModes = appQuietModes.filter { _, mode in mode.isActive(at: now) }
        if !globalQuietMode.isActive(at: now) {
            globalQuietMode = .normal
        }
    }

    private mutating func recordSevereEventIfNeeded(
        _ signal: AnnoyanceSignal,
        appBundleIdentifier: String,
        now: Date
    ) -> Int {
        guard Self.autoPausesAppAfterTwoEventsPerDay(signal) else {
            return 0
        }

        let key = "\(appBundleIdentifier)|\(Self.utcDay(for: now))"
        let count = (severeEventCountsByAppDay[key] ?? 0) + 1
        severeEventCountsByAppDay[key] = count
        return count
    }

    private static func hardStopsField(_ signal: AnnoyanceSignal) -> Bool {
        switch signal {
        case .wrongInsertion, .duplicateText, .focusStealing:
            true
        default:
            false
        }
    }

    private static func autoPausesAppAfterTwoEventsPerDay(_ signal: AnnoyanceSignal) -> Bool {
        switch signal {
        case .wrongInsertion, .duplicateText, .focusStealing, .tabConflict, .acceptedThenDeleted:
            true
        default:
            false
        }
    }

    private static func utcDay(for date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    private static func weight(for signal: AnnoyanceSignal) -> Double {
        switch signal {
        case .wrongInsertion, .duplicateText, .focusStealing, .manualPause:
            1.0
        case .appDisable:
            1.2
        case .tabConflict:
            0.8
        case .acceptedThenDeleted:
            0.7
        case .searchOrFormLeakage:
            0.6
        case .caretGeometryFailed:
            0.3
        case .rapidEscDismissal:
            0.5
        case .typedOver, .overlayFlicker, .repeatedRejection:
            0.4
        case .accepted:
            -0.25
        case .typedThrough:
            -0.15
        case .acceptedAndKept:
            -0.6
        }
    }
}

private struct ScoreBucket: Equatable, Sendable {
    var score: Double = 0
    var updatedAt: Date?

    func score(at now: Date, halfLifeSeconds: TimeInterval) -> Double {
        guard let updatedAt, halfLifeSeconds > 0 else {
            return score
        }

        let elapsedSeconds = max(0, now.timeIntervalSince(updatedAt))
        return score * pow(0.5, elapsedSeconds / halfLifeSeconds)
    }
}

private extension QuietMode {
    func isActive(at now: Date) -> Bool {
        switch self {
        case .normal:
            false
        case let .field(until, _, _),
             let .app(until, _, _),
             let .global(until, _, _):
            until > now
        }
    }
}
