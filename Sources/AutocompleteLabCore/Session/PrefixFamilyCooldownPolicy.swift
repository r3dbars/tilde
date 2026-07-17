import Foundation

public enum PrefixFamilyCooldownReason: String, Codable, Equatable, Sendable {
    case typedOver
    case escapeDismissal = "escape-cooldown"
    case deletion
    case acceptedThenDeleted
}

public struct PrefixFamilyCooldownInput: Equatable, Sendable {
    public let appBundleIdentifier: String
    public let fieldIdentifier: String
    public let requestMode: CompletionRequestMode?
    public let textBeforeCursor: String

    public init(
        appBundleIdentifier: String,
        fieldIdentifier: String,
        requestMode: CompletionRequestMode?,
        textBeforeCursor: String
    ) {
        self.appBundleIdentifier = appBundleIdentifier
        self.fieldIdentifier = fieldIdentifier
        self.requestMode = requestMode
        self.textBeforeCursor = textBeforeCursor
    }
}

public struct PrefixFamilyCooldown: Equatable, Sendable {
    public let reason: PrefixFamilyCooldownReason
    public let until: Date
    public let durationMilliseconds: Int
    public let prefixTokenCount: Int
    public let isEscalated: Bool
    public let prefixFamilyFingerprintVersion: String?
    public let prefixFamilyHMACToken: String?

    public var metadata: [String: String] {
        var metadata = [
            "prefixCooldownReason": reason.rawValue,
            "prefixCooldownUntil": ISO8601DateFormatter().string(from: until),
            "prefixCooldownDurationMilliseconds": String(durationMilliseconds),
            "prefixFamilyTokenCount": String(prefixTokenCount),
            "prefixCooldownEscalated": String(isEscalated)
        ]
        if let prefixFamilyFingerprintVersion {
            metadata["prefixFamilyFingerprintVersion"] = prefixFamilyFingerprintVersion
        }
        if let prefixFamilyHMACToken {
            metadata["prefixFamilyHMACToken"] = prefixFamilyHMACToken
        }
        return metadata
    }
}

public struct PrefixFamilyEagernessAdjustment: Equatable, Sendable {
    public let typedOverScore: Double
    public let acceptedThenDeletedScore: Double
    public let repeatedTypedOverThreshold: Double
    public let repeatedAcceptedThenDeletedThreshold: Double
    public let thresholdAdjustment: Double
    public let prefixTokenCount: Int
    public let prefixFamilyFingerprintVersion: String?
    public let prefixFamilyHMACToken: String?

    public var isActive: Bool {
        thresholdAdjustment > 0
    }

    public var metadata: [String: String] {
        var metadata = [
            "prefixEagernessTypedOverScore": Self.format(typedOverScore),
            "prefixEagernessAcceptedThenDeletedScore": Self.format(acceptedThenDeletedScore),
            "prefixEagernessRepeatedTypedOverThreshold": Self.format(repeatedTypedOverThreshold),
            "prefixEagernessRepeatedAcceptedThenDeletedThreshold": Self.format(repeatedAcceptedThenDeletedThreshold),
            "prefixEagernessThresholdAdjustment": Self.format(thresholdAdjustment),
            "prefixEagernessApplied": String(isActive),
            "prefixFamilyTokenCount": String(prefixTokenCount)
        ]
        if let prefixFamilyFingerprintVersion {
            metadata["prefixFamilyFingerprintVersion"] = prefixFamilyFingerprintVersion
        }
        if let prefixFamilyHMACToken {
            metadata["prefixFamilyHMACToken"] = prefixFamilyHMACToken
        }
        return metadata
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}

public enum PrefixFamilyCooldownDecision: Equatable, Sendable {
    case allowed
    case coolingDown(PrefixFamilyCooldown)

    public var canRequest: Bool {
        self == .allowed
    }
}

public struct PrefixFamilyCooldownPolicy: Equatable, Sendable {
    public let typedOverCooldownMilliseconds: Int
    public let repeatedTypedOverCooldownMilliseconds: Int
    public let escapeCooldownMilliseconds: Int
    public let repeatedEscapeCooldownMilliseconds: Int
    public let deletionCooldownMilliseconds: Int
    public let acceptedThenDeletedCooldownMilliseconds: Int
    public let repeatedAcceptedThenDeletedCooldownMilliseconds: Int
    public let prefixFamilyTokenLimit: Int
    public let typedOverEagernessThreshold: Double
    public let typedOverEagernessHalfLifeSeconds: TimeInterval
    public let acceptedThenDeletedEagernessThreshold: Double
    public let acceptedThenDeletedEagernessHalfLifeSeconds: TimeInterval
    public let traceFingerprintSecret: Data

    private var cooldowns: [PrefixFamilyCooldownKey: PrefixFamilyCooldown] = [:]
    private var typedOverEagernessBuckets: [PrefixFamilyCooldownKey: PrefixFamilyEagernessBucket] = [:]
    private var acceptedThenDeletedEagernessBuckets: [PrefixFamilyCooldownKey: PrefixFamilyEagernessBucket] = [:]

    public init(
        typedOverCooldownMilliseconds: Int = 0,
        repeatedTypedOverCooldownMilliseconds: Int = 0,
        escapeCooldownMilliseconds: Int = 15_000,
        repeatedEscapeCooldownMilliseconds: Int = 60_000,
        deletionCooldownMilliseconds: Int = 250,
        acceptedThenDeletedCooldownMilliseconds: Int = 180_000,
        repeatedAcceptedThenDeletedCooldownMilliseconds: Int = 600_000,
        prefixFamilyTokenLimit: Int = 3,
        typedOverEagernessThreshold: Double = 1.5,
        typedOverEagernessHalfLifeSeconds: TimeInterval = 20 * 60,
        acceptedThenDeletedEagernessThreshold: Double = 1.5,
        acceptedThenDeletedEagernessHalfLifeSeconds: TimeInterval = 30 * 60,
        traceFingerprintSecret: Data = Data()
    ) {
        self.typedOverCooldownMilliseconds = max(0, typedOverCooldownMilliseconds)
        self.repeatedTypedOverCooldownMilliseconds = max(
            self.typedOverCooldownMilliseconds,
            repeatedTypedOverCooldownMilliseconds
        )
        self.escapeCooldownMilliseconds = max(0, escapeCooldownMilliseconds)
        self.repeatedEscapeCooldownMilliseconds = max(self.escapeCooldownMilliseconds, repeatedEscapeCooldownMilliseconds)
        self.deletionCooldownMilliseconds = max(0, deletionCooldownMilliseconds)
        self.acceptedThenDeletedCooldownMilliseconds = max(0, acceptedThenDeletedCooldownMilliseconds)
        self.repeatedAcceptedThenDeletedCooldownMilliseconds = max(
            self.acceptedThenDeletedCooldownMilliseconds,
            repeatedAcceptedThenDeletedCooldownMilliseconds
        )
        self.prefixFamilyTokenLimit = max(1, prefixFamilyTokenLimit)
        self.typedOverEagernessThreshold = max(1, typedOverEagernessThreshold)
        self.typedOverEagernessHalfLifeSeconds = max(1, typedOverEagernessHalfLifeSeconds)
        self.acceptedThenDeletedEagernessThreshold = max(1, acceptedThenDeletedEagernessThreshold)
        self.acceptedThenDeletedEagernessHalfLifeSeconds = max(1, acceptedThenDeletedEagernessHalfLifeSeconds)
        self.traceFingerprintSecret = traceFingerprintSecret
    }

    public mutating func record(
        _ reason: PrefixFamilyCooldownReason,
        input: PrefixFamilyCooldownInput,
        now: Date = Date()
    ) -> PrefixFamilyCooldown? {
        let key = key(for: input)
        if reason == .typedOver {
            recordTypedOverEagerness(for: key, now: now)
        } else if reason == .acceptedThenDeleted {
            recordAcceptedThenDeletedEagerness(for: key, now: now)
        }

        let isEscalated = shouldEscalate(reason, existing: cooldowns[key], now: now)
        let durationMilliseconds = isEscalated
            ? escalatedDuration(for: reason)
            : duration(for: reason)
        guard durationMilliseconds > 0 else {
            return nil
        }

        let cooldown = PrefixFamilyCooldown(
            reason: reason,
            until: now.addingTimeInterval(TimeInterval(durationMilliseconds) / 1_000),
            durationMilliseconds: durationMilliseconds,
            prefixTokenCount: key.prefixTokenCount,
            isEscalated: isEscalated,
            prefixFamilyFingerprintVersion: key.prefixFamilyFingerprintVersion,
            prefixFamilyHMACToken: key.prefixFamilyHMACToken
        )
        cooldowns[key] = cooldown
        return cooldown
    }

    public mutating func decision(
        for input: PrefixFamilyCooldownInput,
        now: Date = Date()
    ) -> PrefixFamilyCooldownDecision {
        expireCooldowns(now: now)

        guard let cooldown = cooldowns[key(for: input)], cooldown.until > now else {
            return .allowed
        }

        return .coolingDown(cooldown)
    }

    public mutating func eagernessAdjustment(
        for input: PrefixFamilyCooldownInput,
        now: Date = Date()
    ) -> PrefixFamilyEagernessAdjustment {
        expireEagernessBuckets(now: now)
        let key = key(for: input)
        let typedOverScore = typedOverEagernessBuckets[key]?.score(
            at: now,
            halfLifeSeconds: typedOverEagernessHalfLifeSeconds
        ) ?? 0
        let acceptedThenDeletedScore = acceptedThenDeletedEagernessBuckets[key]?.score(
            at: now,
            halfLifeSeconds: acceptedThenDeletedEagernessHalfLifeSeconds
        ) ?? 0
        let typedOverAdjustment = thresholdAdjustment(
            for: input.requestMode,
            typedOverScore: typedOverScore
        )
        let acceptedThenDeletedAdjustment = acceptedThenDeletedThresholdAdjustment(
            for: input.requestMode,
            acceptedThenDeletedScore: acceptedThenDeletedScore
        )
        return PrefixFamilyEagernessAdjustment(
            typedOverScore: typedOverScore,
            acceptedThenDeletedScore: acceptedThenDeletedScore,
            repeatedTypedOverThreshold: typedOverEagernessThreshold,
            repeatedAcceptedThenDeletedThreshold: acceptedThenDeletedEagernessThreshold,
            thresholdAdjustment: max(typedOverAdjustment, acceptedThenDeletedAdjustment),
            prefixTokenCount: key.prefixTokenCount,
            prefixFamilyFingerprintVersion: key.prefixFamilyFingerprintVersion,
            prefixFamilyHMACToken: key.prefixFamilyHMACToken
        )
    }

    public mutating func expireCooldowns(now: Date = Date()) {
        cooldowns = cooldowns.filter { _, cooldown in
            cooldown.until > now
        }
    }

    private func duration(for reason: PrefixFamilyCooldownReason) -> Int {
        switch reason {
        case .typedOver:
            typedOverCooldownMilliseconds
        case .escapeDismissal:
            escapeCooldownMilliseconds
        case .deletion:
            deletionCooldownMilliseconds
        case .acceptedThenDeleted:
            acceptedThenDeletedCooldownMilliseconds
        }
    }

    private func escalatedDuration(for reason: PrefixFamilyCooldownReason) -> Int {
        switch reason {
        case .typedOver:
            repeatedTypedOverCooldownMilliseconds
        case .escapeDismissal:
            repeatedEscapeCooldownMilliseconds
        case .deletion:
            deletionCooldownMilliseconds
        case .acceptedThenDeleted:
            repeatedAcceptedThenDeletedCooldownMilliseconds
        }
    }

    private func shouldEscalate(
        _ reason: PrefixFamilyCooldownReason,
        existing: PrefixFamilyCooldown?,
        now: Date
    ) -> Bool {
        guard existing?.reason == reason,
              (existing?.until ?? now) > now else {
            return false
        }

        switch reason {
        case .typedOver, .escapeDismissal, .acceptedThenDeleted:
            return true
        case .deletion:
            return false
        }
    }

    private mutating func recordTypedOverEagerness(
        for key: PrefixFamilyCooldownKey,
        now: Date
    ) {
        let decayedScore = typedOverEagernessBuckets[key]?.score(
            at: now,
            halfLifeSeconds: typedOverEagernessHalfLifeSeconds
        ) ?? 0
        typedOverEagernessBuckets[key] = PrefixFamilyEagernessBucket(
            score: decayedScore + 1,
            updatedAt: now
        )
    }

    private mutating func recordAcceptedThenDeletedEagerness(
        for key: PrefixFamilyCooldownKey,
        now: Date
    ) {
        let decayedScore = acceptedThenDeletedEagernessBuckets[key]?.score(
            at: now,
            halfLifeSeconds: acceptedThenDeletedEagernessHalfLifeSeconds
        ) ?? 0
        acceptedThenDeletedEagernessBuckets[key] = PrefixFamilyEagernessBucket(
            score: decayedScore + 1,
            updatedAt: now
        )
    }

    private mutating func expireEagernessBuckets(now: Date) {
        typedOverEagernessBuckets = typedOverEagernessBuckets.filter { _, bucket in
            bucket.score(at: now, halfLifeSeconds: typedOverEagernessHalfLifeSeconds) >= 0.05
        }
        acceptedThenDeletedEagernessBuckets = acceptedThenDeletedEagernessBuckets.filter { _, bucket in
            bucket.score(at: now, halfLifeSeconds: acceptedThenDeletedEagernessHalfLifeSeconds) >= 0.05
        }
    }

    private func thresholdAdjustment(
        for mode: CompletionRequestMode?,
        typedOverScore: Double
    ) -> Double {
        guard typedOverScore + 0.0001 >= typedOverEagernessThreshold else {
            return 0
        }

        let maxAdjustment: Double
        switch mode {
        case .wordCompletion:
            maxAdjustment = 0.18
        case .sentenceContinuation:
            maxAdjustment = 0.40
        case .phraseContinuation, .none:
            maxAdjustment = 0.30
        }

        let excess = max(0, typedOverScore - typedOverEagernessThreshold)
        let pressure = min(1, 0.60 + (excess / typedOverEagernessThreshold * 0.40))
        return maxAdjustment * pressure
    }

    private func acceptedThenDeletedThresholdAdjustment(
        for mode: CompletionRequestMode?,
        acceptedThenDeletedScore: Double
    ) -> Double {
        guard acceptedThenDeletedScore + 0.0001 >= acceptedThenDeletedEagernessThreshold else {
            return 0
        }

        let maxAdjustment: Double
        switch mode {
        case .wordCompletion:
            maxAdjustment = 0.30
        case .sentenceContinuation:
            maxAdjustment = 0.55
        case .phraseContinuation, .none:
            maxAdjustment = 0.45
        }

        let excess = max(0, acceptedThenDeletedScore - acceptedThenDeletedEagernessThreshold)
        let pressure = min(1, 0.70 + (excess / acceptedThenDeletedEagernessThreshold * 0.30))
        return maxAdjustment * pressure
    }

    private func key(for input: PrefixFamilyCooldownInput) -> PrefixFamilyCooldownKey {
        let tokens = AcceptanceSurvivalClassifier.looseTokens(in: input.textBeforeCursor)
        let familyTokens = Array(tokens.suffix(prefixFamilyTokenLimit))
        let family = familyTokens.isEmpty ? "<empty>" : familyTokens.joined(separator: " ")
        let fingerprintMetadata = TracePrivacyFingerprint.prefixFamilyMetadata(
            for: familyTokens,
            secret: traceFingerprintSecret
        )
        return PrefixFamilyCooldownKey(
            appBundleIdentifier: input.appBundleIdentifier,
            fieldIdentifier: input.fieldIdentifier,
            requestMode: input.requestMode?.rawValue ?? "unknown",
            prefixFamily: family,
            prefixTokenCount: familyTokens.count,
            prefixFamilyFingerprintVersion: fingerprintMetadata["prefixFamilyFingerprintVersion"],
            prefixFamilyHMACToken: fingerprintMetadata["prefixFamilyHMACToken"]
        )
    }
}

private struct PrefixFamilyCooldownKey: Hashable, Sendable {
    let appBundleIdentifier: String
    let fieldIdentifier: String
    let requestMode: String
    let prefixFamily: String
    let prefixTokenCount: Int
    let prefixFamilyFingerprintVersion: String?
    let prefixFamilyHMACToken: String?
}

private struct PrefixFamilyEagernessBucket: Equatable, Sendable {
    let score: Double
    let updatedAt: Date

    func score(at now: Date, halfLifeSeconds: TimeInterval) -> Double {
        let elapsedSeconds = max(0, now.timeIntervalSince(updatedAt))
        return score * pow(0.5, elapsedSeconds / halfLifeSeconds)
    }
}
