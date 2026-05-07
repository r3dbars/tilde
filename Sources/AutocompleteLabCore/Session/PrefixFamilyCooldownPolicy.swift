import Foundation

public enum PrefixFamilyCooldownReason: String, Codable, Equatable, Sendable {
    case typedOver
    case escapeDismissal
    case deletion
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

    public var metadata: [String: String] {
        [
            "prefixCooldownReason": reason.rawValue,
            "prefixCooldownUntil": ISO8601DateFormatter().string(from: until),
            "prefixCooldownDurationMilliseconds": String(durationMilliseconds),
            "prefixFamilyTokenCount": String(prefixTokenCount)
        ]
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
    public let escapeCooldownMilliseconds: Int
    public let deletionCooldownMilliseconds: Int
    public let prefixFamilyTokenLimit: Int

    private var cooldowns: [PrefixFamilyCooldownKey: PrefixFamilyCooldown] = [:]

    public init(
        typedOverCooldownMilliseconds: Int = 5_000,
        escapeCooldownMilliseconds: Int = 15_000,
        deletionCooldownMilliseconds: Int = 250,
        prefixFamilyTokenLimit: Int = 3
    ) {
        self.typedOverCooldownMilliseconds = max(0, typedOverCooldownMilliseconds)
        self.escapeCooldownMilliseconds = max(0, escapeCooldownMilliseconds)
        self.deletionCooldownMilliseconds = max(0, deletionCooldownMilliseconds)
        self.prefixFamilyTokenLimit = max(1, prefixFamilyTokenLimit)
    }

    public mutating func record(
        _ reason: PrefixFamilyCooldownReason,
        input: PrefixFamilyCooldownInput,
        now: Date = Date()
    ) -> PrefixFamilyCooldown? {
        let durationMilliseconds = duration(for: reason)
        guard durationMilliseconds > 0 else {
            return nil
        }

        let key = key(for: input)
        let cooldown = PrefixFamilyCooldown(
            reason: reason,
            until: now.addingTimeInterval(TimeInterval(durationMilliseconds) / 1_000),
            durationMilliseconds: durationMilliseconds,
            prefixTokenCount: key.prefixTokenCount
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
        }
    }

    private func key(for input: PrefixFamilyCooldownInput) -> PrefixFamilyCooldownKey {
        let tokens = AcceptanceSurvivalClassifier.looseTokens(in: input.textBeforeCursor)
        let familyTokens = Array(tokens.suffix(prefixFamilyTokenLimit))
        let family = familyTokens.isEmpty ? "<empty>" : familyTokens.joined(separator: " ")
        return PrefixFamilyCooldownKey(
            appBundleIdentifier: input.appBundleIdentifier,
            fieldIdentifier: input.fieldIdentifier,
            requestMode: input.requestMode?.rawValue ?? "unknown",
            prefixFamily: family,
            prefixTokenCount: familyTokens.count
        )
    }
}

private struct PrefixFamilyCooldownKey: Hashable, Sendable {
    let appBundleIdentifier: String
    let fieldIdentifier: String
    let requestMode: String
    let prefixFamily: String
    let prefixTokenCount: Int
}
