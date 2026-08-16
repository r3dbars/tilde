import Foundation

public enum DiagnosticsMetadataRedactor {
    private static let enumValues: Set<String> = [
        "launch-failed", "assets-missing", "port-in-use", "health-timeout", "directory",
        "already-running",
        "unsafeHiddenOrControlCharacter", "emptyOutput", "noSuggestionSentinel",
        "promptInstructionEcho", "emptyAfterPrefixTrimming", "replaysContext",
        "notRegistered", "enabled", "requiresApproval", "notFound", "unknown",
        "store-corrupt", "key-unavailable", "storage-unavailable", "internal-error",
        // Screen Memory's `screen-capture-skipped` reason vocabulary
        // (ScreenCaptureService.describe / CaptureOutcome) — fixed enum
        // cases with no user data, so they belong in this allowlist same as
        // everything else here. Without an entry, a value falls through to
        // `redacted(value)` and prints as e.g. "String(8 chars)" instead of
        // the literal reason, which is what made every skip look identical
        // in the log regardless of cause.
        "disabled", "dev-flag-off", "no-permission", "screen-locked", "secure-input",
        "no-active-session", "below-threshold", "excluded-app", "cadence",
        "enumeration-failed", "no-display",
    ]

    public static func logSafeEvent(_ event: String) -> String {
        matches(event, #"^[a-z][a-z0-9-]{0,63}$"#) ? event : "event-redacted"
    }

    public static func logSafeField(forKey key: String, value: String) -> String {
        let safe: Bool
        switch key {
        case "totalMilliseconds", "cleanedChars", "chars":
            safe = matches(value, #"^(?:[0-9]+(?:\.[0-9]+)?|none|unknown)$"#)
        case "willRestart", "firstInstall":
            safe = value == "true" || value == "false"
        case "reason", "status":
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
