import Foundation

public enum AutocompleteTracePrivacyFilter {
    public static func textValue(_ value: String, rawContentEnabled: Bool) -> String {
        guard !rawContentEnabled, !value.isEmpty else {
            return value
        }

        return DiagnosticValueRedactor.stringSummary(length: value.count)
    }

    public static func metadata(_ metadata: [String: String], rawContentEnabled: Bool) -> [String: String] {
        guard !rawContentEnabled else {
            return metadata
        }

        var filtered: [String: String] = [:]
        for (key, value) in metadata {
            filtered[key] = DiagnosticsMetadataRedactor.logSafeValue(forKey: key, value: value)
        }

        return filtered
    }
}
