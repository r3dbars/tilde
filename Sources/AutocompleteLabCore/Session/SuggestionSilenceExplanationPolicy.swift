import Foundation

public enum SuggestionSilenceReasonCode: String, CaseIterable, Equatable, Sendable {
    case safety
    case latency
    case confidence
    case displayScore = "display-score"
    case repetition
    case prefixCooldown = "prefix-cooldown"
    case quietMode = "quiet-mode"
    case learnedRestraint = "learned-restraint"
    case noUsefulSuggestion = "no-useful-suggestion"
    case placement
    case staleContext = "stale-context"
    case modelError = "model-error"
    case typingCadence = "typing-cadence"
    case settingsOrRuntime = "settings-or-runtime"
    case unknown

    public var userFacingReason: String {
        switch self {
        case .safety:
            "safety gate"
        case .latency:
            "too slow"
        case .confidence:
            "low confidence"
        case .displayScore:
            "display score"
        case .repetition:
            "repeated miss"
        case .prefixCooldown:
            "recent prefix cooldown"
        case .quietMode:
            "quiet mode"
        case .learnedRestraint:
            "recent rejects"
        case .noUsefulSuggestion:
            "no useful suggestion"
        case .placement:
            "cursor placement"
        case .staleContext:
            "stale text"
        case .modelError:
            "model error"
        case .typingCadence:
            "typing fast"
        case .settingsOrRuntime:
            "suggestions unavailable"
        case .unknown:
            "unknown reason"
        }
    }
}

public struct SuggestionSilenceExplanationPolicy: Equatable, Sendable {
    public static let traceReasonCodeMetadataKey = "suggestionSilenceReasonCode"

    public init() {}

    public func focusedTextUnavailable(isSecure: Bool) -> String {
        isSecure ? "secure field" : "no editable text field"
    }

    public func activationBlockReason(
        _ reason: CompletionActivationBlockReason,
        fieldKind: AXFieldKind
    ) -> String {
        switch reason {
        case .secureField:
            return "secure field"
        case .suppressedField:
            return "field silenced"
        case .blockedFieldKind:
            return blockedFieldKindReason(fieldKind)
        case .sensitiveContent:
            return "sensitive content stays quiet"
        case .markdownCodeContext:
            return "code blocks stay quiet"
        case .selectedText:
            return "selected text stays quiet"
        case .terminalSentenceBoundary:
            return "sentence already ended"
        case .tooLittleContext:
            return "waiting for more context"
        case .middleOfLine:
            return "middle of line stays quiet"
        case .unfinishedWord:
            return "word still forming"
        }
    }

    public func reasonCode(
        forTraceReason reason: String,
        metadata: [String: String] = [:],
        triggerReason: String = ""
    ) -> SuggestionSilenceReasonCode {
        if let existingCode = metadata[Self.traceReasonCodeMetadataKey],
           let code = SuggestionSilenceReasonCode(rawValue: existingCode) {
            return code
        }

        if let displayReason = metadata["displayScoreSuppressionReason"] {
            return reasonCode(forDisplayScoreReason: displayReason)
        }

        if metadata["prefixCooldownReason"] != nil || reason == "prefix-family-cooldown" {
            return .prefixCooldown
        }

        if let quietMode = metadata["quietMode"],
           quietMode != "normal",
           !quietMode.isEmpty {
            return .quietMode
        }

        let normalizedReason = normalize(reason)
        let normalizedTrigger = normalize(triggerReason)

        if normalizedReason.contains("quietmode") || normalizedTrigger.contains("quietmode") {
            return .quietMode
        }

        if normalizedReason.contains("prefixcooldown")
            || normalizedTrigger.contains("prefixcooldown")
            || normalizedReason.contains("prefixfamilycooldown") {
            return .prefixCooldown
        }

        if normalizedReason == "repeatedmiss"
            || normalizedReason == "highrepetition"
            || metadata["repetitionMissSuppressed"] == "true" {
            return .repetition
        }

        if normalizedReason == "fastphraselearningrestraint"
            || normalizedReason == "lowacceptedandkeptprobability"
            || metadata["fastPhraseFallbackLearningSuppressed"] == "true" {
            return .learnedRestraint
        }

        if normalizedReason.contains("tooslow")
            || normalizedReason.contains("latency")
            || metadata["displayScoreMaxAggressiveLatencyBudgetExceeded"] == "true" {
            return .latency
        }

        if normalizedReason.contains("lowconfidence")
            || metadata["completionConfidenceBucket"] == "low" {
            return .confidence
        }

        if isSafetyReason(normalizedReason, metadata: metadata) {
            return .safety
        }

        if isNoUsefulSuggestionReason(normalizedReason) {
            return .noUsefulSuggestion
        }

        if normalizedReason.contains("placement")
            || normalizedReason.contains("anchor")
            || metadata["placementHealthReason"] != nil {
            return .placement
        }

        if normalizedReason.contains("stale") || normalizedReason.contains("focuschanged") {
            return .staleContext
        }

        if normalizedReason.contains("engineerror") || normalizedReason.contains("modelerror") {
            return .modelError
        }

        if normalizedReason.contains("typingburst") || normalizedTrigger.contains("typingburst") {
            return .typingCadence
        }

        if isSettingsOrRuntimeReason(normalizedReason) {
            return .settingsOrRuntime
        }

        if DisplayScoreSuppressionReason(rawValue: reason) != nil {
            return reasonCode(forDisplayScoreReason: reason)
        }

        return .unknown
    }

    public func traceMetadata(
        forTraceReason reason: String,
        metadata: [String: String] = [:],
        triggerReason: String = ""
    ) -> [String: String] {
        [
            Self.traceReasonCodeMetadataKey: reasonCode(
                forTraceReason: reason,
                metadata: metadata,
                triggerReason: triggerReason
            ).rawValue
        ]
    }

    public func userFacingReason(
        forTraceReason reason: String,
        metadata: [String: String] = [:],
        triggerReason: String = ""
    ) -> String {
        reasonCode(
            forTraceReason: reason,
            metadata: metadata,
            triggerReason: triggerReason
        ).userFacingReason
    }

    private func blockedFieldKindReason(_ fieldKind: AXFieldKind) -> String {
        switch fieldKind {
        case .search:
            return "search fields stay quiet"
        case .url:
            return "URL and address fields stay quiet"
        case .form:
            return "forms stay quiet"
        case .secure:
            return "secure field"
        case .unprovenSurface:
            return "surface needs proof first"
        case .unknown:
            return "unknown field needs proof first"
        case .multilineCompose, .singlelineCompose:
            return "field needs proof first"
        }
    }

    private func reasonCode(forDisplayScoreReason reason: String) -> SuggestionSilenceReasonCode {
        switch DisplayScoreSuppressionReason(rawValue: reason) {
        case .tooSlowToDisplay:
            return .latency
        case .lowConfidence:
            return .confidence
        case .highRepetition:
            return .repetition
        case .learnedRestraint, .lowAcceptedAndKeptProbability:
            return .learnedRestraint
        case .highRisk:
            return .safety
        case .highInstability, .belowThreshold:
            return .displayScore
        case .none:
            return .displayScore
        }
    }

    private func isSafetyReason(_ normalizedReason: String, metadata: [String: String]) -> Bool {
        if ["secure", "search", "url", "form", "unprovensurface"].contains(normalize(metadata["fieldKind"] ?? "")) {
            return true
        }

        return [
            "securefield",
            "sensitiveapp",
            "sensitivecontent",
            "blockedfieldkind",
            "suppressedfield",
            "promptappblocked",
            "browserhostedsurfaceblocked",
            "wrongapporfieldbeforeaccept",
            "insertunsafeacceptedtext",
            "acceptancesafetyblocked",
            "acceptedtextlinebreak",
            "acceptedtexttab",
            "acceptedtexthiddencontrolcharacter",
            "acceptedtextcontrolcharacter"
        ].contains(normalizedReason)
    }

    private func isNoUsefulSuggestionReason(_ normalizedReason: String) -> Bool {
        [
            "emptysuggestion",
            "nosuggestion",
            "nocandidates",
            "lowtopscore",
            "nofastwordcandidate",
            "instantwordnolocalcandidate"
        ].contains(normalizedReason)
    }

    private func isSettingsOrRuntimeReason(_ normalizedReason: String) -> Bool {
        [
            "unsupportedapp",
            "appdisabled",
            "profiledisabled",
            "profilediagnosticsonly",
            "runtimenotready",
            "runtime",
            "proofwordcompletiondisabled",
            "proofphrasecontinuationdisabled",
            "fastwordcompletiondisabled",
            "suggestionspaused",
            "accessibilitypermissionlost",
            "keyboardcaptureunavailable"
        ].contains(normalizedReason)
    }

    private func normalize(_ value: String) -> String {
        value
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }
}
