import Foundation

public enum DiagnosticsMetadataRedactor {
    private static let enumValues: Set<String> = [
        "launch-failed", "assets-missing", "port-in-use", "health-timeout", "directory",
        "already-running",
        "unsafeHiddenOrControlCharacter", "emptyOutput", "noSuggestionSentinel",
        "promptInstructionEcho", "emptyAfterPrefixTrimming", "replaysContext", "replaysScene",
        "notRegistered", "enabled", "requiresApproval", "notFound", "unknown",
        "store-corrupt", "key-unavailable", "storage-unavailable", "internal-error",
        // Screen Memory's `screen-capture-skipped` reason vocabulary
        // (ScreenCaptureService.describe / CaptureOutcome) — fixed enum
        // cases with no user data, so they belong in this allowlist same as
        // everything else here. Without an entry, a value falls through to
        // `redacted(value)` and prints as e.g. "String(8 chars)" instead of
        // the literal reason, which is what made every skip look identical
        // in the log regardless of cause.
        "disabled", "no-permission", "screen-locked", "secure-input", "no-active-text-field",
        "no-active-session", "below-threshold", "excluded-app", "cadence",
        "enumeration-failed", "no-display",
        // The 2026-08-16 first-launch Screen Recording permission prompt's
        // outcome vocabulary from the setup permission flow.
        "requested", "settings-opened", "dismissed",
        // `ScreenScene.Mode`'s raw values, logged by the `scene-classified`
        // diagnostic (`ScreenCaptureService.freshScene`) so a classification
        // is never opaque — mode only, never any of the OCR'd text itself.
        "replying", "referencing", "composing",
        // `SensitiveScenePolicy`'s suppression reason, logged by the
        // `suggestion-suppressed` diagnostic (`GhostBrainServerHost`) —
        // count-only, never the matched category or any scene text.
        "sensitive-scene",
        // `PersonalSuggestionSource`'s fixed vocabulary, logged as the
        // `source` field on `suggestion-served` only when the "Personal
        // suggestions (experimental)" toggle is on
        // (`PersonalSuggestionPolicy.apply`, `GhostBrainServerHost`) — which
        // engine's word actually reached the user, never the word itself.
        "base", "personal", "agreed",
        // `screen-capture-completed`/`screen-capture-failed`'s `kind` field
        // (`ScreenCaptureService.performWindowCapture`/`performFullDisplayCapture`)
        // — which capture path ran, never any captured text.
        "window", "display", "ax",
        // `screen-capture-completed`'s `ocrScope` field (incremental OCR,
        // `ScreenCaptureService.performWindowCapture`/`performFullDisplayCapture`,
        // backed by `CaptureChangeDetector`) — how much of the frame the OCR
        // pass actually covered this capture: the whole frame, a bounded
        // region, or none at all because nothing changed. Never any
        // captured text or the region's coordinates.
        "full", "region", "skipped",
        // "P99 at every section": `GhostBrainServerHost.awaitPersonalPrediction`'s
        // outcome vocabulary, logged as the `outcome` field on
        // `personal-lookup-timing` — which arm of the 250ms personal-brain
        // race actually decided the request, never the prediction itself.
        "resolved", "timeout",
    ]

    public static func logSafeEvent(_ event: String) -> String {
        matches(event, #"^[a-z][a-z0-9-]{0,63}$"#) ? event : "event-redacted"
    }

    public static func logSafeField(forKey key: String, value: String) -> String {
        let safe: Bool
        switch key {
        case "totalMilliseconds", "cleanedChars", "chars", "turns", "refs", "duration_ms", "blocks",
             // "P99 at every section" timing fields (2026-08-18): scene
             // classification (`milliseconds` on `scene-classified`), the
             // capture/OCR split (`ocrMilliseconds` on
             // `screen-capture-completed`), the personal-brain race
             // (`waitedMilliseconds` on `personal-lookup-timing`), and the
             // socket request total (`requestMilliseconds` on
             // `ghost-request-timing`) — all whole milliseconds, no text.
             "milliseconds", "ocrMilliseconds", "waitedMilliseconds", "requestMilliseconds",
             // Accept-to-parsed on `ghost-request-timing`: the peer
             // code-signature handshake plus the wire read, the segment that
             // runs before `requestMilliseconds` starts counting. A whole
             // millisecond count, no text.
             "handshakeMilliseconds",
             // Streaming split on `llama-completion-timing`: first token and
             // first complete-word partial, whole milliseconds, no text.
             "firstTokenMilliseconds", "firstPartialMilliseconds":
            safe = matches(value, #"^(?:[0-9]+(?:\.[0-9]+)?|none|unknown)$"#)
        case "willRestart", "firstInstall":
            safe = value == "true" || value == "false"
        case "reason", "status", "mode", "source", "kind", "outcome", "ocrScope":
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
