import Foundation

public enum SensitiveFieldProofCategory: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case password
    case otp
    case payment
    case login
    case search
    case urlAddress = "url-address"
    case apiKeyLikeText = "api-key-like-text"
    case passwordManager = "password-manager"
    case privatePrompt = "private-prompt"
    case privateSearch = "private-search"
}

public struct SensitiveTextFieldAssessment: Equatable, Sendable {
    public let isSensitive: Bool
    public let category: SensitiveFieldProofCategory?
    public let reason: String

    public init(
        isSensitive: Bool,
        category: SensitiveFieldProofCategory?,
        reason: String
    ) {
        self.isSensitive = isSensitive
        self.category = category
        self.reason = reason
    }

    public var traceMetadata: [String: String] {
        guard let category else {
            return [
                "sensitiveSuppressionDecision": "allowed",
                "sensitiveSuppressionReason": reason
            ]
        }

        return [
            "sensitiveSuppressionCategory": category.rawValue,
            "sensitiveSuppressionDecision": isSensitive ? "blocked" : "allowed",
            "sensitiveSuppressionReason": reason
        ]
    }
}

public struct SensitiveTextFieldPolicy: Equatable, Sendable {
    public init() {}

    public func isSensitive(
        role: String?,
        subrole: String?,
        fingerprint: FocusedElementFingerprint
    ) -> Bool {
        assessment(role: role, subrole: subrole, fingerprint: fingerprint).isSensitive
    }

    public func assessment(
        role: String?,
        subrole: String?,
        fingerprint: FocusedElementFingerprint
    ) -> SensitiveTextFieldAssessment {
        if (role ?? "").caseInsensitiveCompare("AXSecureTextField") == .orderedSame
            || (subrole ?? "").caseInsensitiveCompare("AXSecureTextField") == .orderedSame {
            return SensitiveTextFieldAssessment(
                isSensitive: true,
                category: .password,
                reason: "secureAXRole"
            )
        }

        let rawSearchable = fingerprint.searchableText.lowercased()
        let searchable = normalizedSearchableText(for: fingerprint)
        guard !searchable.isEmpty else {
            return SensitiveTextFieldAssessment(isSensitive: false, category: nil, reason: "noSensitiveHint")
        }

        if looksLikeAPIKey(rawSearchable) {
            return SensitiveTextFieldAssessment(
                isSensitive: true,
                category: .apiKeyLikeText,
                reason: "apiKeyLikeFingerprint"
            )
        }

        if let category = category(for: searchable) {
            return SensitiveTextFieldAssessment(
                isSensitive: true,
                category: category,
                reason: "sensitiveHint:\(category.rawValue)"
            )
        }

        return SensitiveTextFieldAssessment(isSensitive: false, category: nil, reason: "noSensitiveHint")
    }

    private func normalizedSearchableText(for fingerprint: FocusedElementFingerprint) -> String {
        let raw = fingerprint.searchableText.lowercased()
        let normalized = raw.unicodeScalars.map { scalar in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : " "
        }

        return " " + String(normalized)
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ") + " "
    }

    private func category(for searchable: String) -> SensitiveFieldProofCategory? {
        for (category, phrases) in Self.sensitivePhrasesByCategory {
            if phrases.contains(where: { searchable.contains(" \($0) ") }) {
                return category
            }
        }

        return nil
    }

    private func looksLikeAPIKey(_ text: String) -> Bool {
        text.range(
            of: #"\b(sk-[a-z0-9_-]{12,}|gh[pousr]_[a-z0-9_]{12,}|xox[baprs]-[a-z0-9-]{12,}|akia[0-9a-z]{12,})\b"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    private static let sensitivePhrasesByCategory: [(SensitiveFieldProofCategory, Set<String>)] = [
        (.passwordManager, [
            "1password", "bitwarden", "dashlane", "lastpass", "password manager"
        ]),
        (.privatePrompt, [
            "private prompt", "private chat", "confidential prompt", "private note"
        ]),
        (.privateSearch, [
            "private search", "incognito search", "private browsing search"
        ]),
        (.password, [
            "password", "passcode", "passphrase", "pin", "recovery phrase",
            "seed phrase", "private key", "secret key", "client secret"
        ]),
        (.otp, [
            "2fa", "mfa", "otp", "auth code", "authentication code",
            "one time code", "one time password", "verification code",
            "security code"
        ]),
        (.payment, [
            "card number", "credit card", "debit card", "cvc", "cvv",
            "expiration", "expiry", "payment", "billing"
        ]),
        (.login, [
            "login", "sign in", "signin", "username", "account password"
        ]),
        (.urlAddress, [
            "url", "address bar", "location bar", "web address", "website"
        ]),
        (.search, [
            "search", "search query", "find", "filter"
        ]),
        (.apiKeyLikeText, [
            "api key", "apikey", "access token", "auth token", "bearer token",
            "personal access token", "token", "secret"
        ])
    ]
}
