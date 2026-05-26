import Foundation

public struct SuggestionSilenceExplanationPolicy: Equatable, Sendable {
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
}
