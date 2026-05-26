import Foundation

public struct SuggestionSilenceExplanationPolicy: Equatable, Sendable {
    public init() {}

    public func activationBlockReason(
        for decision: CompletionActivationDecision,
        fieldClassification: AXFieldClassification
    ) -> String {
        switch decision {
        case .allow:
            return "allowed"
        case let .block(reason):
            return activationBlockReason(
                reason,
                fieldClassification: fieldClassification
            )
        }
    }

    public func activationBlockReason(
        _ reason: CompletionActivationBlockReason,
        fieldClassification: AXFieldClassification
    ) -> String {
        switch reason {
        case .secureField:
            return "secure field"
        case .suppressedField:
            return "field silenced"
        case .blockedFieldKind:
            return fieldKindReason(fieldClassification)
        case .sensitiveContent:
            return "sensitive text detected"
        case .markdownCodeContext:
            return "code context"
        case .selectedText:
            return "selected text active"
        case .terminalSentenceBoundary:
            return "sentence ended"
        case .tooLittleContext:
            return "waiting for more context"
        case .middleOfLine:
            return "middle of line"
        case .unfinishedWord:
            return "word still forming"
        }
    }

    private func fieldKindReason(_ fieldClassification: AXFieldClassification) -> String {
        switch fieldClassification.kind {
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
            return "field blocked by policy"
        }
    }
}
