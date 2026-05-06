import Foundation

public enum DiagnosticsMetadataRedactor {
    public static func logSafeValue(forKey key: String, value: String) -> String {
        let flattened = flattenedValue(value)

        guard isSensitiveKey(key), !isShapeKey(key) else {
            return flattened
        }

        return DiagnosticValueRedactor.stringSummary(length: value.count)
    }

    public static func isSensitiveKey(_ key: String) -> Bool {
        let normalized = key.lowercased()
        return [
            "text",
            "prompt",
            "output",
            "completion",
            "suggestion",
            "selected",
            "typed",
            "value"
        ].contains { normalized.contains($0) }
    }

    private static func isShapeKey(_ key: String) -> Bool {
        let normalized = key.lowercased()
        return normalized.hasSuffix("chars")
            || normalized.hasSuffix("count")
            || normalized.hasSuffix("length")
            || normalized.hasSuffix("milliseconds")
            || normalized.hasPrefix("has")
    }

    private static func flattenedValue(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
    }
}
