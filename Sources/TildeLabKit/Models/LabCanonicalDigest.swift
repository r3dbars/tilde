import CryptoKit
import Foundation

/// JSONEncoder sorts object keys but intentionally does not canonicalize Set
/// iteration order. Durable research identities normalize only the known
/// set-valued fields; semantically ordered arrays keep their original order.
enum LabCanonicalDigest {
    private static let unorderedArrayKeys: Set<String> = [
        "enabledBenches", "hosts", "intents", "tones",
    ]

    static func sha256<T: Encodable>(
        _ value: T,
        dateEncodingStrategy: JSONEncoder.DateEncodingStrategy = .deferredToDate
    ) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = dateEncodingStrategy
        let encoded = try encoder.encode(value)
        let object = try JSONSerialization.jsonObject(with: encoded)
        let canonical = try canonicalized(object, key: nil)
        let bytes = try JSONSerialization.data(
            withJSONObject: canonical,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
        return SHA256.hash(data: bytes)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static func canonicalized(_ value: Any, key: String?) throws -> Any {
        if let dictionary = value as? [String: Any] {
            return try Dictionary(uniqueKeysWithValues: dictionary.map { entry in
                (entry.key, try canonicalized(entry.value, key: entry.key))
            })
        }
        if let array = value as? [Any] {
            let values = try array.map { try canonicalized($0, key: nil) }
            guard let key, unorderedArrayKeys.contains(key) else { return values }
            guard values.allSatisfy({ $0 is String }) else {
                throw LabCanonicalDigestError.invalidSetEncoding(key)
            }
            return values.sorted { ($0 as! String) < ($1 as! String) }
        }
        return value
    }
}

enum LabCanonicalDigestError: Error, Equatable {
    case invalidSetEncoding(String)
}
