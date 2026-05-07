import CryptoKit
import Foundation

public enum TracePrivacyFingerprint {
    public static let version = "hmac-sha256-v1"

    public static func metadata(for text: String, secret: Data) -> [String: String] {
        let tokens = AcceptanceSurvivalClassifier.looseTokens(in: text)
        guard !tokens.isEmpty, !secret.isEmpty else {
            return [:]
        }

        let joined = tokens.joined(separator: " ")
        var metadata = [
            "acceptedTextFingerprintVersion": version,
            "acceptedTextHMACToken": hmacHex(joined, secret: secret),
            "acceptedTokenCount": String(tokens.count)
        ]
        let grams = threeGrams(tokens)
            .map { hmacHex($0.joined(separator: " "), secret: secret, prefixBytes: 12) }
        if !grams.isEmpty {
            metadata["acceptedText3GramFingerprints"] = grams.joined(separator: ",")
            metadata["acceptedText3GramCount"] = String(grams.count)
        }

        return metadata
    }

    private static func threeGrams(_ tokens: [String]) -> [[String]] {
        guard tokens.count >= 3 else {
            return tokens.isEmpty ? [] : [tokens]
        }

        return (0...(tokens.count - 3)).map { index in
            Array(tokens[index..<(index + 3)])
        }
    }

    private static func hmacHex(
        _ value: String,
        secret: Data,
        prefixBytes: Int? = nil
    ) -> String {
        let key = SymmetricKey(data: secret)
        let digest = HMAC<SHA256>.authenticationCode(for: Data(value.utf8), using: key)
        let bytes = Array(digest)
        let selectedBytes = prefixBytes.map { Array(bytes.prefix($0)) } ?? bytes
        return selectedBytes.map { String(format: "%02x", $0) }.joined()
    }
}

public struct TraceSessionRotation: Equatable, Sendable {
    public let sessionID: String
    public let day: String
    public let rotated: Bool
}

public enum TraceSessionRotator {
    public static func session(
        existingID: String?,
        existingDay: String?,
        now: Date,
        generateID: () -> String
    ) -> TraceSessionRotation {
        let day = dayKey(for: now)
        if let existingID,
           let existingDay,
           existingDay == day,
           !existingID.isEmpty {
            return TraceSessionRotation(sessionID: existingID, day: day, rotated: false)
        }

        return TraceSessionRotation(sessionID: generateID(), day: day, rotated: true)
    }

    public static func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
