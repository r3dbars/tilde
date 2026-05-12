import Foundation

public enum DiagnosticsMetadataRedactor {
    public static func logSafeValue(forKey key: String, value: String) -> String {
        let flattened = flattenedValue(value)

        if isAlreadyRedactedSummary(flattened) {
            return flattened
        }

        if shouldRedactValue(forKey: key, value: flattened) {
            return DiagnosticValueRedactor.stringSummary(length: value.count)
        }

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
            "document",
            "directory",
            "email",
            "filename",
            "fileurl",
            "folder",
            "path",
            "recipient",
            "suggestion",
            "selected",
            "subject",
            "title",
            "typed",
            "url",
            "uri",
            "value"
        ].contains { normalized.contains($0) }
    }

    private static func isShapeKey(_ key: String) -> Bool {
        let normalized = key.lowercased()
        return normalized.hasSuffix("chars")
            || normalized.hasSuffix("count")
            || normalized.hasSuffix("length")
            || normalized.hasSuffix("milliseconds")
            || normalized.hasSuffix("rect")
            || normalized.hasSuffix("frame")
            || normalized.hasPrefix("has")
            || normalized.contains("hmac")
            || (normalized.hasPrefix("acceptedtext") && normalized.contains("fingerprint"))
    }

    private static func shouldRedactValue(forKey key: String, value: String) -> Bool {
        guard !isShapeKey(key) else {
            return false
        }

        if containsLocalPath(value) {
            return true
        }

        return isReasonLikeKey(key) && !isKnownSafeReasonValue(value)
    }

    private static func containsLocalPath(_ value: String) -> Bool {
        let patterns = [
            #"(^|[\s"'=:(])/(Users|private|tmp|var|Volumes|Applications|Library|System|bin|sbin|usr|opt|dev)/[^\s"']+"#,
            #"(^|[\s"'=:(])~(/[^\s"']*)"#,
            #"file://[^\s"']+"#,
            #"[A-Za-z]:\\[^\s"']+"#
        ]

        return patterns.contains { pattern in
            value.range(of: pattern, options: .regularExpression) != nil
        }
    }

    private static func isReasonLikeKey(_ key: String) -> Bool {
        key.lowercased().contains("reason")
    }

    private static func isKnownSafeReasonValue(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return true
        }

        let pattern = #"^[A-Za-z0-9][A-Za-z0-9_.:-]{0,96}$"#
        return trimmed.range(of: pattern, options: .regularExpression) != nil
    }

    private static func flattenedValue(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
    }

    private static func isAlreadyRedactedSummary(_ value: String) -> Bool {
        (value.hasPrefix("String(") && value.hasSuffix(" chars)"))
            || (value.hasPrefix("AttributedString(") && value.hasSuffix(" chars)"))
            || (value.hasPrefix("Array(") && value.hasSuffix(" items)"))
            || value.hasSuffix("(redacted)")
    }
}
