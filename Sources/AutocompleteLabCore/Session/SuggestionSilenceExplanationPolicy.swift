import Foundation

public struct SuggestionSilenceExplanationPolicy: Equatable, Sendable {
    public init() {}

    public func explanation(
        for decision: CompletionActivationDecision,
        fieldKind: AXFieldKind
    ) -> String? {
        guard case let .block(reason) = decision else {
            return nil
        }

        return explanation(for: reason, fieldKind: fieldKind)
    }

    public func explanation(
        for reason: CompletionActivationBlockReason,
        fieldKind: AXFieldKind
    ) -> String {
        switch reason {
        case .secureField:
            return "secure fields stay quiet"
        case .suppressedField:
            return "silenced until focus changes"
        case .blockedFieldKind:
            return blockedFieldKindExplanation(fieldKind)
        case .sensitiveContent:
            return "sensitive text detected"
        case .markdownCodeContext:
            return "code context"
        case .selectedText:
            return "selected text is protected"
        case .terminalSentenceBoundary:
            return "waiting for a new thought"
        case .tooLittleContext:
            return "waiting for more context"
        case .middleOfLine:
            return "cursor is in existing text"
        case .unfinishedWord:
            return "word still forming"
        }
    }

    private func blockedFieldKindExplanation(_ fieldKind: AXFieldKind) -> String {
        switch fieldKind {
        case .search:
            return "search fields stay quiet"
        case .form:
            return "forms stay quiet"
        case .secure:
            return "secure fields stay quiet"
        case .url:
            return "URL and address fields stay quiet"
        case .unprovenSurface:
            return "surface needs proof first"
        case .unknown:
            return "unknown field needs proof first"
        case .multilineCompose, .singlelineCompose:
            return "field needs proof first"
        }
    }
}
