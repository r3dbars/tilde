import Foundation

public struct SuppressedSuggestionEntry: Codable, Equatable, Hashable, Sendable {
    public let fingerprintVersion: String
    public let hmacToken: String
    public let requestMode: String
    public let scope: String
    public let tokenCount: Int
    public let characterCount: Int
    public let source: String
    public let createdAt: String

    public init(
        fingerprintVersion: String = TracePrivacyFingerprint.version,
        hmacToken: String,
        requestMode: String,
        scope: String,
        tokenCount: Int,
        characterCount: Int,
        source: String,
        createdAt: String
    ) {
        self.fingerprintVersion = fingerprintVersion
        self.hmacToken = hmacToken
        self.requestMode = requestMode
        self.scope = Self.normalizedScope(scope)
        self.tokenCount = max(0, tokenCount)
        self.characterCount = max(0, characterCount)
        self.source = source
        self.createdAt = createdAt
    }

    public var traceMetadata: [String: String] {
        [
            "blockedFingerprintVersion": fingerprintVersion,
            "blockedHMACToken": hmacToken,
            "blockedTokenCount": String(tokenCount),
            "blockedTextChars": String(characterCount),
            "blockedRequestMode": requestMode,
            "blockedScope": scope,
            "blockedSource": source
        ]
    }

    var key: String {
        Self.key(
            hmacToken: hmacToken,
            requestMode: requestMode,
            scope: scope
        )
    }

    static func key(
        hmacToken: String,
        requestMode: String,
        scope: String
    ) -> String {
        [
            requestMode,
            normalizedScope(scope),
            hmacToken
        ].joined(separator: "|")
    }

    static func normalizedScope(_ scope: String) -> String {
        scope
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}

public struct SuppressedSuggestionStore: Equatable, Sendable {
    public static let exactSuggestionPurpose = "suppressed-suggestion-v1"

    private var entriesByKey: [String: SuppressedSuggestionEntry]

    public init(entries: [SuppressedSuggestionEntry] = []) {
        entriesByKey = [:]
        for entry in entries {
            entriesByKey[entry.key] = entry
        }
    }

    public var entries: [SuppressedSuggestionEntry] {
        entriesByKey.values.sorted {
            if $0.scope != $1.scope {
                return $0.scope < $1.scope
            }
            if $0.requestMode != $1.requestMode {
                return $0.requestMode < $1.requestMode
            }
            return $0.hmacToken < $1.hmacToken
        }
    }

    public var isEmpty: Bool {
        entriesByKey.isEmpty
    }

    public func match(
        _ text: String,
        mode: CompletionRequestMode,
        scope: String,
        secret: Data
    ) -> SuppressedSuggestionEntry? {
        guard let hmacToken = hmacToken(
            for: text,
            mode: mode,
            scope: scope,
            secret: secret
        ) else {
            return nil
        }

        return entriesByKey[SuppressedSuggestionEntry.key(
            hmacToken: hmacToken,
            requestMode: mode.rawValue,
            scope: scope
        )]
    }

    public func shouldSuppress(
        _ text: String,
        mode: CompletionRequestMode,
        scope: String,
        secret: Data
    ) -> Bool {
        match(text, mode: mode, scope: scope, secret: secret) != nil
    }

    @discardableResult
    public mutating func suppressExact(
        _ text: String,
        mode: CompletionRequestMode,
        scope: String,
        secret: Data,
        source: String = "user",
        createdAt: String? = nil
    ) -> SuppressedSuggestionEntry? {
        guard let hmacToken = hmacToken(
            for: text,
            mode: mode,
            scope: scope,
            secret: secret
        ) else {
            return nil
        }

        let entry = SuppressedSuggestionEntry(
            hmacToken: hmacToken,
            requestMode: mode.rawValue,
            scope: scope,
            tokenCount: TracePrivacyFingerprint.tokenCount(for: text),
            characterCount: text.count,
            source: source,
            createdAt: createdAt ?? Self.timestamp()
        )
        entriesByKey[entry.key] = entry
        return entry
    }

    public mutating func removeAll() {
        entriesByKey.removeAll()
    }

    private func hmacToken(
        for text: String,
        mode: CompletionRequestMode,
        scope: String,
        secret: Data
    ) -> String? {
        TracePrivacyFingerprint.textToken(
            for: text,
            purpose: Self.exactSuggestionPurpose,
            scope: scope,
            mode: mode.rawValue,
            secret: secret
        )
    }

    private static func timestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}
