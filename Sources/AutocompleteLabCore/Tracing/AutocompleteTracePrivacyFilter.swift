import Foundation

public enum AutocompleteTracePrivacyFilter {
    public static func textValue(_ value: String, rawContentEnabled: Bool) -> String {
        guard !rawContentEnabled, !value.isEmpty else {
            return value
        }

        return DiagnosticValueRedactor.stringSummary(length: value.count)
    }

    public static func traceSignalValue(_ value: String, rawContentEnabled: Bool) -> String {
        guard !rawContentEnabled else {
            return value
        }

        return redactedTraceSignalValue(value)
    }

    public static func metadata(_ metadata: [String: String], rawContentEnabled: Bool) -> [String: String] {
        guard !rawContentEnabled else {
            return metadata
        }

        var filtered: [String: String] = [:]
        for (key, value) in metadata {
            filtered[key] = metadataValue(forKey: key, value: value)
        }

        return filtered
    }

    static func metadataValue(forKey key: String, value: String) -> String {
        let logSafeValue = DiagnosticsMetadataRedactor.logSafeValue(forKey: key, value: value)
        guard isTraceSignalMetadataKey(key) else {
            return logSafeValue
        }

        return redactedTraceSignalValue(logSafeValue, originalLength: value.count)
    }

    static func isTraceSignalMetadataKey(_ key: String) -> Bool {
        let normalized = key.lowercased()
        return normalized.contains("reason")
            || normalized.contains("outcome")
    }

    private static func redactedTraceSignalValue(
        _ value: String,
        originalLength: Int? = nil
    ) -> String {
        let flattened = flattenedTraceSignalValue(value)
        guard !flattened.isEmpty else {
            return ""
        }

        guard isKnownSafeTraceSignal(flattened) else {
            return DiagnosticValueRedactor.stringSummary(length: originalLength ?? value.count)
        }

        return flattened
    }

    private static func flattenedTraceSignalValue(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isKnownSafeTraceSignal(_ value: String) -> Bool {
        isAlreadyRedactedSummary(value)
            || isScalarTraceSignal(value)
            || safeTraceSignalValues.contains(value)
            || isKnownSafeCounterList(value)
    }

    private static func isAlreadyRedactedSummary(_ value: String) -> Bool {
        (value.hasPrefix("String(") && value.hasSuffix(" chars)"))
            || (value.hasPrefix("AttributedString(") && value.hasSuffix(" chars)"))
            || (value.hasPrefix("Array(") && value.hasSuffix(" items)"))
            || value.hasSuffix("(redacted)")
    }

    private static func isScalarTraceSignal(_ value: String) -> Bool {
        let normalized = value.lowercased()
        if normalized == "true" || normalized == "false" {
            return true
        }

        if Int(value) != nil {
            return true
        }

        guard value.contains(".") else {
            return false
        }

        return Double(value) != nil
            && value.allSatisfy { character in
                character.isNumber || character == "." || character == "-"
            }
    }

    private static func isKnownSafeCounterList(_ value: String) -> Bool {
        let items = value.split(separator: ",", omittingEmptySubsequences: false)
        guard !items.isEmpty else {
            return false
        }

        return items.allSatisfy { item in
            let parts = item.split(separator: ":", omittingEmptySubsequences: false)
            guard parts.count == 2,
                  let count = Int(parts[1]),
                  count >= 0 else {
                return false
            }

            return safeTraceSignalValues.contains(String(parts[0]))
        }
    }

    private static let safeTraceSignalValues: Set<String> = [
        "2s",
        "10s",
        "30s",
        "1m",
        "5m",
        "accepted",
        "accepted-all",
        "accepted-insertion-undone",
        "accepted-next-word-recompute",
        "accepted-text-prompt-action-word",
        "accepted-text-prompt-command-prefix",
        "accepted-text-prompt-shell-metacharacter",
        "acceptedThenDeleted",
        "accepted-then-deleted",
        "acceptAllVisible",
        "acceptNextWord",
        "acceptance-proof-failed",
        "acceptance-recheck-failed",
        "acceptance-safety-blocked",
        "aggressiveness-changed",
        "already-running",
        "anchor-outside-active-display",
        "apiKeyLikeFingerprint",
        "app-changed-before-accept",
        "app-disabled",
        "app-owned-runtime-missing",
        "below-threshold",
        "blocked-field-kind",
        "blockedFieldKind",
        "cadence-policy",
        "caret-changed",
        "caret-outside-focused-bounds",
        "caretGeometryFailed",
        "clamped-to-safe-range",
        "codex-proof-marker",
        "codex-textarea-fast-path",
        "comboBoxRole",
        "copy-only",
        "deletion",
        "detached-suggestion-disabled",
        "diagnostics-only-profile",
        "disabled",
        "dismissed",
        "display",
        "display-score",
        "duplicate insertion",
        "duplicate text",
        "empty-model-result",
        "empty-suggestion",
        "engine-error",
        "escape",
        "escape-dismissed",
        "escapeDismissal",
        "exactKept",
        "excessive-outlier",
        "expired",
        "expected-rect-outside-capture",
        "field-blur-finalized",
        "field-changed",
        "field-changed-before-accept",
        "field-send-finalized",
        "field-silenced",
        "fieldSend",
        "focus-changed",
        "focus steal",
        "focus-steal",
        "formHint",
        "frame-unusable",
        "fresh-visible-suggestion",
        "generic-prompt-geometry",
        "generic-prompt-not-composer",
        "global-pause",
        "healthy",
        "hidden",
        "high-instability",
        "high-repetition",
        "high-risk",
        "ignored",
        "image-unreadable",
        "in-flight",
        "inline-available",
        "inline-caret-unavailable-fell-back",
        "inline-room-too-small",
        "insert-failed",
        "insert-missing-compatibility-profile",
        "insert-unsafe-accepted-text",
        "insert-verification-failed",
        "insufficient-evidence",
        "insufficient-search-area",
        "insufficient-signal",
        "invalid-anchor",
        "invalid-caret",
        "invalid-input",
        "late-suggestion-hidden",
        "low-accepted-and-kept-probability",
        "low-confidence",
        "low-confidence-placement",
        "low-contrast",
        "low-score-margin",
        "manual",
        "manual-field",
        "manual-visual-nudge",
        "marked-text-area-not-found",
        "max-visible-words-changed",
        "missing-anchor",
        "missing-accepted-text",
        "missing-baseline",
        "missing-caret",
        "missing-compatibility-profile",
        "missing-current-snapshot-before-accept",
        "missing-floating-fallback",
        "missing-focused-context",
        "missing-frontmost-app",
        "missing-geometry",
        "missing-inline-capabilities",
        "missing-prompt-bounds",
        "missing-prompt-fingerprint",
        "missing-profile",
        "missing-shown-snapshot-before-accept",
        "model-install-completed",
        "multipleLines",
        "new-request",
        "no-eligible-app",
        "no-fast-word-candidate",
        "no-prior-request",
        "noSensitiveHint",
        "none",
        "non-dogfood-profile",
        "non-finite-input",
        "non-prompt-role",
        "not-prompt-like",
        "one-minute-finalized",
        "panel-frame-unusable",
        "pass-through",
        "pasteboard-set-failed",
        "pause",
        "pause-until-tomorrow",
        "placement-caret-outside-focused-bounds",
        "placement-detached-suggestion-disabled",
        "placement-invalid-anchor",
        "placement-invalid-caret",
        "placement-low-confidence-placement",
        "placement-missing-anchor",
        "placement-missing-caret",
        "placement-missing-floating-fallback",
        "placement-untrusted-detached-anchor",
        "placement-untrusted-synthetic-caret",
        "precondition-failed",
        "predictive-phrase-fallback",
        "prefix-family-cooldown",
        "profile-diagnostics-only",
        "prompt-fingerprint",
        "prompt-fingerprint-geometry",
        "prompt-fingerprint-not-composer",
        "prompt-geometry",
        "prompt-mutation-outside-accepted-span",
        "prompt-target-changed-before-accept",
        "quiet-mode-started",
        "read-duration",
        "rejectedAfterAccept",
        "render-mode-changed",
        "repeated-miss",
        "restore-failed",
        "runtime-became-ready",
        "runtime-not-ready",
        "same-field-stale-selection",
        "sample-window",
        "screen-changed",
        "screen-layout-changed",
        "screen-recording-permission",
        "searchRole",
        "secureAXFlag",
        "secureAXRole",
        "secure-field",
        "secure-field-before-accept",
        "secureRole",
        "selected-text-changed-before-accept",
        "send-key-collision",
        "set-value-failed",
        "shortTextField",
        "singlelineComposeHint",
        "scope-matched",
        "stale-after-keydown",
        "stale-field",
        "stale-focus",
        "stale-geometry-screen-layout-changed",
        "stale-request",
        "stale-text",
        "subpixel-noise",
        "suggestion-presented",
        "suppressed-autorepeat",
        "suppressed-field-before-accept",
        "tab",
        "tab conflict",
        "tab-conflict",
        "tab-literal-tab",
        "tab-word",
        "target-fingerprint-changed",
        "target-fingerprint-changed-before-accept",
        "target-recheck-failed",
        "terminate",
        "text-after-cursor-changed-before-accept",
        "text-area-not-found",
        "text-before-cursor-changed-before-accept",
        "text-line-changed",
        "textAreaRole",
        "five-minute-finalized",
        "thirty-second-finalized",
        "thirty-second-retention-expiry",
        "timed-pause",
        "timeout",
        "too-slow-to-display",
        "transient-empty-context",
        "typed-against-visible-suggestion",
        "typed-over",
        "typed-through",
        "typedOver",
        "typing",
        "typing-burst",
        "undone",
        "unknown",
        "unsupported-app",
        "unsupported-full",
        "unsupported-one-word",
        "unsupported-profile",
        "untrusted-detached-anchor",
        "untrusted-placement",
        "untrusted-synthetic-caret",
        "urlRole",
        "value-set-failed",
        "verified",
        "visible-page-context-changed",
        "visible-prefix-advanced",
        "webAreaWithoutComposeHint",
        "webComposeHint",
        "workspace-app-activated",
        "workspace-app-deactivated",
        "wrong-app-or-field-before-accept",
        "wrong-context"
    ]
}
