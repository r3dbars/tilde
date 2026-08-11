import Foundation

public enum DiagnosticsMetadataRedactor {
    private static let enumValues: Set<String> = [
        "binary-missing", "model-missing", "port-held-by-foreign-process", "launch-failed",
        "unsafeHiddenOrControlCharacter", "emptyOutput", "noSuggestionSentinel",
        "promptInstructionEcho", "emptyAfterPrefixTrimming", "replaysContext",
        "invalidWordCompletion", "phraseContinuation", "sentenceContinuation",
        "wordCompletion", "notRegistered", "enabled", "requiresApproval", "notFound", "unknown",
    ]

    public static func logSafeEvent(_ event: String) -> String {
        matches(event, #"^[a-z][a-z0-9-]{0,63}$"#) ? event : "event-redacted"
    }

    public static func logSafeField(forKey key: String, value: String) -> String {
        let safe: Bool
        switch key {
        case "firstTokenProbability", "threshold", "totalMilliseconds", "firstChunkMilliseconds",
             "promptTokensProcessed", "cleanedChars", "pid", "restart", "chars":
            safe = matches(value, #"^(?:[0-9]+(?:\.[0-9]+)?|none|unknown)$"#)
        case "willRestart", "firstInstall":
            safe = value == "true" || value == "false"
        case "reason", "mode", "status":
            safe = enumValues.contains(value)
        case "app":
            safe = value == "unknown"
                || matches(value, #"^[A-Za-z0-9][A-Za-z0-9-]*(?:\.[A-Za-z0-9][A-Za-z0-9-]*)+$"#)
        default:
            return "metadata=\(redacted(value))"
        }

        return "\(key)=\(safe ? value : redacted(value))"
    }

    private static func matches(_ value: String, _ pattern: String) -> Bool {
        value.range(of: pattern, options: .regularExpression) == value.startIndex..<value.endIndex
    }

    private static func redacted(_ value: String) -> String {
        "String(\(value.count) chars)"
    }
}
