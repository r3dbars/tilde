import Foundation

public enum SensitiveFieldProofCategory: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case password
    case otp
    case payment
    case login
    case search
    case urlAddress = "url-address"
    case address
    case governmentID = "government-id"
    case dateOfBirth = "date-of-birth"
    case tax
    case insurance
    case medical
    case cryptoWallet = "crypto-wallet"
    case commandLine = "command-line"
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
            "private prompt", "private chat", "confidential prompt",
            "confidential instructions", "internal only prompt", "private note"
        ]),
        (.privateSearch, [
            "private search", "incognito search", "private browsing search"
        ]),
        (.cryptoWallet, [
            "seed phrase", "wallet seed", "mnemonic phrase", "crypto wallet",
            "wallet address", "recovery seed", "secret recovery phrase",
            "metamask", "coinbase wallet", "phantom wallet"
        ]),
        (.password, [
            "password", "passkey", "passcode", "passphrase", "pin",
            "recovery key", "recovery phrase",
            "private key", "ssh private key", "secret key",
            "client secret"
        ]),
        (.otp, [
            "2fa", "mfa", "otp", "auth code", "authentication code",
            "one time code", "one time password", "verification code",
            "security code", "sign in code", "sso code", "oauth code"
        ]),
        (.payment, [
            "card number", "credit card", "debit card", "cvc", "cvv",
            "expiration", "expiry", "payment", "billing", "apple pay",
            "paypal", "iban", "routing number", "bank account", "account number"
        ]),
        (.login, [
            "login", "sign in", "sign in with", "sign-in", "signin",
            "username", "account password", "oauth", "sso"
        ]),
        (.urlAddress, [
            "url", "address bar", "location bar", "web address", "website"
        ]),
        (.address, [
            "street address", "shipping address", "mailing address", "home address",
            "work address", "address line", "address line 2", "city state zip",
            "postal code", "zip code", "email address", "phone number"
        ]),
        (.tax, [
            "tax id", "tax identification", "tax return", "tax form",
            "taxpayer id", "irs", "w2", "w 2", "w9", "w 9", "1099",
            "ein", "itin", "tin"
        ]),
        (.governmentID, [
            "ssn", "social security", "social security number",
            "passport", "passport number", "drivers license", "driver license",
            "driver license number", "license number", "state id",
            "government id", "national id", "identity number"
        ]),
        (.dateOfBirth, [
            "date of birth", "birth date", "birthday", "dob"
        ]),
        (.insurance, [
            "insurance", "insurance id", "insurance number", "policy number",
            "member id", "group number", "subscriber id", "rxbin", "rx bin"
        ]),
        (.medical, [
            "medical", "health record", "medical record", "patient id",
            "patient number", "diagnosis", "prescription", "medication",
            "allergies", "hipaa", "health history"
        ]),
        (.commandLine, [
            "command line", "command-line", "terminal command", "shell command",
            "shell prompt", "bash prompt", "zsh prompt", "powershell prompt",
            "console input", "sudo command", "ssh command", "web terminal",
            "dev terminal", "codespaces", "github dev", "replit", "stackblitz"
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
