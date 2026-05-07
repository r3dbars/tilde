import Foundation

public struct SensitiveTextFieldPolicy: Equatable, Sendable {
    public init() {}

    public func isSensitive(
        role: String?,
        subrole: String?,
        fingerprint: FocusedElementFingerprint
    ) -> Bool {
        if subrole == "AXSecureTextField" {
            return true
        }

        let searchable = normalizedSearchableText(for: fingerprint)
        guard !searchable.isEmpty else {
            return false
        }

        return Self.sensitivePhrases.contains { phrase in
            searchable.contains(" \(phrase) ")
        }
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

    private static let sensitivePhrases: Set<String> = [
        "2fa",
        "api key",
        "auth code",
        "authentication code",
        "card number",
        "credit card",
        "cvc",
        "cvv",
        "mfa",
        "one time code",
        "one time password",
        "otp",
        "passcode",
        "passphrase",
        "password",
        "pin",
        "private key",
        "recovery phrase",
        "secret",
        "security code",
        "seed phrase",
        "social security",
        "ssn",
        "token",
        "verification code"
    ]
}
