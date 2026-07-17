import Foundation

public enum FocusedTextAXHealthSlowReason: String, Equatable, Sendable {
    case queueDelay = "queue-delay"
    case readDuration = "read-duration"
}

public struct FocusedTextAXHealthCooldown: Equatable, Sendable {
    public let bundleIdentifier: String
    public let reason: FocusedTextAXHealthSlowReason
    public let slowReadCount: Int
    public let cooldownMilliseconds: Int
    public let remainingMilliseconds: Int
    public let cooldownUntil: Date

    public init(
        bundleIdentifier: String,
        reason: FocusedTextAXHealthSlowReason,
        slowReadCount: Int,
        cooldownMilliseconds: Int,
        remainingMilliseconds: Int,
        cooldownUntil: Date
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.reason = reason
        self.slowReadCount = max(0, slowReadCount)
        self.cooldownMilliseconds = max(0, cooldownMilliseconds)
        self.remainingMilliseconds = max(0, remainingMilliseconds)
        self.cooldownUntil = cooldownUntil
    }
}

public struct FocusedTextAXHealthRecovery: Equatable, Sendable {
    public let bundleIdentifier: String
    public let reason: FocusedTextAXHealthSlowReason
    public let cooldownMilliseconds: Int
}

public enum FocusedTextAXHealthPollDecision: Equatable, Sendable {
    case allowed(recovery: FocusedTextAXHealthRecovery?)
    case coolingDown(FocusedTextAXHealthCooldown)
}

public struct FocusedTextAXHealthObservation: Equatable, Sendable {
    public let slowReason: FocusedTextAXHealthSlowReason?
    public let slowReadCount: Int
    public let cooldown: FocusedTextAXHealthCooldown?
    public let didStartCooldown: Bool

    public var isSlow: Bool {
        slowReason != nil
    }
}

public struct FocusedTextAXHealthState: Equatable, Sendable {
    fileprivate var apps: [String: FocusedTextAXAppHealth]

    public init() {
        apps = [:]
    }
}

public struct FocusedTextAXHealthPolicy: Equatable, Sendable {
    public static let typingResponsiveness = FocusedTextAXHealthPolicy()

    public let automaticCooldownEnabled: Bool
    public let slowQueueDelayMilliseconds: Int
    public let slowReadDurationMilliseconds: Int
    public let repeatedSlowReadCount: Int
    public let missingContextSlowReadCount: Int
    public let slowReadWindowMilliseconds: Int
    public let cooldownMilliseconds: Int
    public let maximumTrackedApps: Int

    public init(
        automaticCooldownEnabled: Bool = false,
        slowQueueDelayMilliseconds: Int = 80,
        slowReadDurationMilliseconds: Int = 80,
        repeatedSlowReadCount: Int = 2,
        missingContextSlowReadCount: Int = 1,
        slowReadWindowMilliseconds: Int = 1_000,
        cooldownMilliseconds: Int = 750,
        maximumTrackedApps: Int = 16
    ) {
        self.automaticCooldownEnabled = automaticCooldownEnabled
        self.slowQueueDelayMilliseconds = max(0, slowQueueDelayMilliseconds)
        self.slowReadDurationMilliseconds = max(0, slowReadDurationMilliseconds)
        self.repeatedSlowReadCount = max(1, repeatedSlowReadCount)
        self.missingContextSlowReadCount = max(1, missingContextSlowReadCount)
        self.slowReadWindowMilliseconds = max(0, slowReadWindowMilliseconds)
        self.cooldownMilliseconds = max(0, cooldownMilliseconds)
        self.maximumTrackedApps = max(1, maximumTrackedApps)
    }

    public func pollDecision(
        for bundleIdentifier: String,
        now: Date,
        state: inout FocusedTextAXHealthState
    ) -> FocusedTextAXHealthPollDecision {
        guard automaticCooldownEnabled else {
            state.apps.removeValue(forKey: bundleIdentifier)
            return .allowed(recovery: nil)
        }

        guard !bundleIdentifier.isEmpty,
              let health = state.apps[bundleIdentifier],
              let cooldownUntil = health.cooldownUntil,
              let reason = health.cooldownReason else {
            return .allowed(recovery: nil)
        }

        if cooldownUntil > now {
            return .coolingDown(
                cooldown(
                    bundleIdentifier: bundleIdentifier,
                    reason: reason,
                    slowReadCount: health.slowReadCount,
                    cooldownUntil: cooldownUntil,
                    now: now
                )
            )
        }

        state.apps.removeValue(forKey: bundleIdentifier)
        return .allowed(
            recovery: FocusedTextAXHealthRecovery(
                bundleIdentifier: bundleIdentifier,
                reason: reason,
                cooldownMilliseconds: milliseconds(from: health.cooldownStartedAt ?? now, to: cooldownUntil)
            )
        )
    }

    public func recordRead(
        bundleIdentifier: String,
        queueDelayMilliseconds: Int,
        readDurationMilliseconds: Int,
        hasContext: Bool = true,
        now: Date,
        state: inout FocusedTextAXHealthState
    ) -> FocusedTextAXHealthObservation {
        guard !bundleIdentifier.isEmpty else {
            return FocusedTextAXHealthObservation(
                slowReason: nil,
                slowReadCount: 0,
                cooldown: nil,
                didStartCooldown: false
            )
        }

        guard let reason = slowReason(
            queueDelayMilliseconds: queueDelayMilliseconds,
            readDurationMilliseconds: readDurationMilliseconds
        ) else {
            state.apps.removeValue(forKey: bundleIdentifier)
            return FocusedTextAXHealthObservation(
                slowReason: nil,
                slowReadCount: 0,
                cooldown: nil,
                didStartCooldown: false
            )
        }

        var health = state.apps[bundleIdentifier] ?? FocusedTextAXAppHealth()
        if let cooldownUntil = health.cooldownUntil,
           let cooldownReason = health.cooldownReason,
           cooldownUntil > now {
            let activeCooldown = cooldown(
                bundleIdentifier: bundleIdentifier,
                reason: cooldownReason,
                slowReadCount: health.slowReadCount,
                cooldownUntil: cooldownUntil,
                now: now
            )
            return FocusedTextAXHealthObservation(
                slowReason: reason,
                slowReadCount: health.slowReadCount,
                cooldown: activeCooldown,
                didStartCooldown: false
            )
        }

        if let firstSlowReadAt = health.firstSlowReadAt,
           milliseconds(from: firstSlowReadAt, to: now) <= slowReadWindowMilliseconds {
            health.slowReadCount += 1
        } else {
            health.slowReadCount = 1
            health.firstSlowReadAt = now
        }

        health.lastObservedAt = now
        health.lastSlowReason = reason

        guard automaticCooldownEnabled else {
            state.apps[bundleIdentifier] = health
            trimTrackedApps(in: &state)
            return FocusedTextAXHealthObservation(
                slowReason: reason,
                slowReadCount: health.slowReadCount,
                cooldown: nil,
                didStartCooldown: false
            )
        }

        let requiredSlowReadCount = hasContext ? repeatedSlowReadCount : missingContextSlowReadCount
        if health.slowReadCount >= requiredSlowReadCount {
            let cooldownUntil = now.addingTimeInterval(TimeInterval(cooldownMilliseconds) / 1000)
            health.cooldownStartedAt = now
            health.cooldownUntil = cooldownUntil
            health.cooldownReason = reason
            state.apps[bundleIdentifier] = health
            trimTrackedApps(in: &state)
            let startedCooldown = cooldown(
                bundleIdentifier: bundleIdentifier,
                reason: reason,
                slowReadCount: health.slowReadCount,
                cooldownUntil: cooldownUntil,
                now: now
            )
            return FocusedTextAXHealthObservation(
                slowReason: reason,
                slowReadCount: health.slowReadCount,
                cooldown: startedCooldown,
                didStartCooldown: true
            )
        }

        state.apps[bundleIdentifier] = health
        trimTrackedApps(in: &state)
        return FocusedTextAXHealthObservation(
            slowReason: reason,
            slowReadCount: health.slowReadCount,
            cooldown: nil,
            didStartCooldown: false
        )
    }

    private func slowReason(
        queueDelayMilliseconds: Int,
        readDurationMilliseconds: Int
    ) -> FocusedTextAXHealthSlowReason? {
        let queueDelayMilliseconds = max(0, queueDelayMilliseconds)
        let readDurationMilliseconds = max(0, readDurationMilliseconds)
        let queueIsSlow = queueDelayMilliseconds >= slowQueueDelayMilliseconds
        let readIsSlow = readDurationMilliseconds >= slowReadDurationMilliseconds

        switch (queueIsSlow, readIsSlow) {
        case (true, true):
            return readDurationMilliseconds >= queueDelayMilliseconds ? .readDuration : .queueDelay
        case (true, false):
            return .queueDelay
        case (false, true):
            return .readDuration
        case (false, false):
            return nil
        }
    }

    private func cooldown(
        bundleIdentifier: String,
        reason: FocusedTextAXHealthSlowReason,
        slowReadCount: Int,
        cooldownUntil: Date,
        now: Date
    ) -> FocusedTextAXHealthCooldown {
        FocusedTextAXHealthCooldown(
            bundleIdentifier: bundleIdentifier,
            reason: reason,
            slowReadCount: slowReadCount,
            cooldownMilliseconds: cooldownMilliseconds,
            remainingMilliseconds: milliseconds(from: now, to: cooldownUntil),
            cooldownUntil: cooldownUntil
        )
    }

    private func trimTrackedApps(in state: inout FocusedTextAXHealthState) {
        guard state.apps.count > maximumTrackedApps,
              let oldestApp = state.apps.min(by: { lhs, rhs in
                  (lhs.value.lastObservedAt ?? .distantPast) < (rhs.value.lastObservedAt ?? .distantPast)
              })?.key else {
            return
        }

        state.apps.removeValue(forKey: oldestApp)
    }

    private func milliseconds(from start: Date, to end: Date) -> Int {
        max(0, Int((end.timeIntervalSince(start) * 1000).rounded()))
    }
}

private struct FocusedTextAXAppHealth: Equatable, Sendable {
    var slowReadCount: Int = 0
    var firstSlowReadAt: Date?
    var lastObservedAt: Date?
    var lastSlowReason: FocusedTextAXHealthSlowReason?
    var cooldownStartedAt: Date?
    var cooldownUntil: Date?
    var cooldownReason: FocusedTextAXHealthSlowReason?
}
