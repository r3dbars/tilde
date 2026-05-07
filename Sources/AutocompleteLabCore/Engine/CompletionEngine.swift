import Foundation

public enum CompletionRequestMode: String, Equatable, Sendable {
    case phraseContinuation
    case sentenceContinuation
    case wordCompletion

    public var isContinuation: Bool {
        switch self {
        case .phraseContinuation, .sentenceContinuation:
            true
        case .wordCompletion:
            false
        }
    }
}

public struct CompletionRequest: Equatable, Sendable {
    public let textBeforeCursor: String
    public let textAfterCursor: String
    public let appBundleIdentifier: String?
    public let fieldKind: AXFieldKind
    public let behaviorProfileID: AutocompleteBehaviorProfileID?
    public let acceptedTextStyleSketch: AcceptedTextStyleSketch?
    public let maxVisibleWords: Int
    public let mode: CompletionRequestMode
    public let suggestionID: String

    public init(
        textBeforeCursor: String,
        textAfterCursor: String = "",
        appBundleIdentifier: String? = nil,
        fieldKind: AXFieldKind = .unknown,
        behaviorProfileID: AutocompleteBehaviorProfileID? = nil,
        acceptedTextStyleSketch: AcceptedTextStyleSketch? = nil,
        maxVisibleWords: Int = CompletionModelPolicy.mvp.maxVisibleWords,
        mode: CompletionRequestMode = .phraseContinuation,
        suggestionID: String = ""
    ) {
        self.textBeforeCursor = textBeforeCursor
        self.textAfterCursor = textAfterCursor
        self.appBundleIdentifier = appBundleIdentifier
        self.fieldKind = fieldKind
        self.behaviorProfileID = behaviorProfileID
        self.acceptedTextStyleSketch = acceptedTextStyleSketch
        self.maxVisibleWords = CompletionModelPolicy.clampedVisibleWords(maxVisibleWords)
        self.mode = mode
        self.suggestionID = suggestionID
    }

    public var behaviorProfile: AutocompleteBehaviorProfile {
        AutocompleteBehaviorProfileResolver().profile(for: AutocompleteBehaviorProfileInput(
            requestedProfileID: behaviorProfileID,
            appBundleIdentifier: appBundleIdentifier,
            fieldKind: fieldKind
        ))
    }

    public var behaviorProfileTraceMetadata: [String: String] {
        var metadata = behaviorProfile.traceMetadata
        metadata["requestFieldKind"] = fieldKind.rawValue
        if let acceptedTextStyleSketch {
            metadata.merge(acceptedTextStyleSketch.traceMetadata) { current, _ in current }
        }
        return metadata
    }
}

public protocol CompletionEngine: Sendable {
    func suggestion(for request: CompletionRequest) async throws -> CompletionSuggestion?
    func suggestion(
        for request: CompletionRequest,
        onPartialSuggestion: @escaping @Sendable (CompletionSuggestion) -> Void
    ) async throws -> CompletionSuggestion?
}

public extension CompletionEngine {
    func suggestion(
        for request: CompletionRequest,
        onPartialSuggestion: @escaping @Sendable (CompletionSuggestion) -> Void
    ) async throws -> CompletionSuggestion? {
        try await suggestion(for: request)
    }
}
