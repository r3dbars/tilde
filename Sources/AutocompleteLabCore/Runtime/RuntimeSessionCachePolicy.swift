import Foundation

public struct RuntimeSessionCacheKey: Equatable, Hashable, Sendable {
    public let appBundleIdentifier: String
    public let fieldIdentityDescription: String
    public let fieldKind: AXFieldKind
    public let behaviorProfileID: AutocompleteBehaviorProfileID?
    public let mode: CompletionRequestMode

    public init(
        appBundleIdentifier: String,
        fieldIdentityDescription: String,
        fieldKind: AXFieldKind,
        behaviorProfileID: AutocompleteBehaviorProfileID?,
        mode: CompletionRequestMode
    ) {
        self.appBundleIdentifier = appBundleIdentifier
        self.fieldIdentityDescription = fieldIdentityDescription
        self.fieldKind = fieldKind
        self.behaviorProfileID = behaviorProfileID
        self.mode = mode
    }
}

public enum RuntimeSessionCacheResetReason: String, Equatable, Sendable {
    case noPriorRequest = "no-prior-request"
    case wordCompletion = "word-completion"
    case missingApp = "missing-app"
    case missingFieldIdentity = "missing-field-identity"
    case appChanged = "app-changed"
    case fieldChanged = "field-changed"
    case fieldKindChanged = "field-kind-changed"
    case behaviorProfileChanged = "behavior-profile-changed"
    case modeChanged = "mode-changed"
    case textDidNotGrow = "text-did-not-grow"
    case textAfterCursorChanged = "text-after-cursor-changed"
    case paragraphChanged = "paragraph-changed"
    case sentenceChanged = "sentence-changed"
}

public enum RuntimeSessionCacheDecision: Equatable, Sendable {
    case reuse(RuntimeSessionCacheKey)
    case reset(RuntimeSessionCacheResetReason)

    public var canReuse: Bool {
        switch self {
        case .reuse:
            return true
        case .reset:
            return false
        }
    }

    public var traceMetadata: [String: String] {
        switch self {
        case let .reuse(key):
            [
                "runtimeSessionCacheEligible": "true",
                "runtimeSessionCacheDecision": "reuse",
                "runtimeSessionCacheKey": key.traceDescription
            ]
        case let .reset(reason):
            [
                "runtimeSessionCacheEligible": "false",
                "runtimeSessionCacheDecision": "reset",
                "runtimeSessionCacheResetReason": reason.rawValue
            ]
        }
    }
}

public extension RuntimeSessionCacheKey {
    var traceDescription: String {
        [
            appBundleIdentifier,
            fieldIdentityDescription,
            fieldKind.rawValue,
            behaviorProfileID?.rawValue ?? "none",
            mode.rawValue
        ].joined(separator: "|")
    }
}

public struct RuntimeSessionCachePolicy: Equatable, Sendable {
    public init() {}

    public func decision(
        previous: CompletionRequest?,
        current: CompletionRequest
    ) -> RuntimeSessionCacheDecision {
        guard let previous else {
            return .reset(.noPriorRequest)
        }

        guard let currentApp = nonEmpty(current.appBundleIdentifier),
              let previousApp = nonEmpty(previous.appBundleIdentifier) else {
            return .reset(.missingApp)
        }

        guard let currentField = nonEmpty(current.fieldIdentityDescription),
              let previousField = nonEmpty(previous.fieldIdentityDescription) else {
            return .reset(.missingFieldIdentity)
        }

        guard currentApp == previousApp else {
            return .reset(.appChanged)
        }

        guard currentField == previousField else {
            return .reset(.fieldChanged)
        }

        guard current.fieldKind == previous.fieldKind else {
            return .reset(.fieldKindChanged)
        }

        guard current.behaviorProfileID == previous.behaviorProfileID else {
            return .reset(.behaviorProfileChanged)
        }

        guard current.mode == previous.mode else {
            return .reset(.modeChanged)
        }

        guard current.textAfterCursor == previous.textAfterCursor else {
            return .reset(.textAfterCursorChanged)
        }

        guard current.textBeforeCursor.hasPrefix(previous.textBeforeCursor),
              current.textBeforeCursor.count > previous.textBeforeCursor.count else {
            return .reset(.textDidNotGrow)
        }

        let previousParagraph = currentParagraph(in: previous.textBeforeCursor)
        let activeParagraph = currentParagraph(in: current.textBeforeCursor)
        guard activeParagraph.hasPrefix(previousParagraph) else {
            return .reset(.paragraphChanged)
        }

        let previousSentence = currentSentence(in: previous.textBeforeCursor)
        let activeSentence = currentSentence(in: current.textBeforeCursor)
        if current.mode == .phraseContinuation,
           !activeSentence.hasPrefix(previousSentence) {
            return .reset(.sentenceChanged)
        }

        return .reuse(RuntimeSessionCacheKey(
            appBundleIdentifier: currentApp,
            fieldIdentityDescription: currentField,
            fieldKind: current.fieldKind,
            behaviorProfileID: current.behaviorProfileID,
            mode: current.mode
        ))
    }

    private func nonEmpty(_ text: String?) -> String? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            return nil
        }
        return text
    }

    private func currentParagraph(in text: String) -> String {
        let pieces = text.components(separatedBy: "\n\n")
        return pieces.last ?? text
    }

    private func currentSentence(in text: String) -> String {
        let separators = CharacterSet(charactersIn: ".!?\n")
        let pieces = text.components(separatedBy: separators)
        return pieces.last ?? text
    }
}
