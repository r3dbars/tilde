import Foundation

/// What kind of continuation a request wants; each mode carries a generation
/// budget ceiling.
public enum CompletionRequestMode: String, Equatable, Sendable {
    case phraseContinuation
    case sentenceContinuation
    case wordCompletion

    public var generatedTokenCeiling: Int {
        switch self {
        case .phraseContinuation:
            return 20
        case .sentenceContinuation:
            return 32
        case .wordCompletion:
            return 8
        }
    }

    public var isContinuation: Bool {
        self != .wordCompletion
    }
}

/// A single completion request from the input method: the text being written,
/// where it's being written, and the optional screen context.
public struct CompletionRequest: Equatable, Sendable {
    public let textBeforeCursor: String
    public let textAfterCursor: String
    public let appBundleIdentifier: String?
    public let fieldIdentityDescription: String?
    public let visiblePageContext: VisiblePageContext?
    public let maxVisibleWords: Int
    public let mode: CompletionRequestMode

    public init(
        textBeforeCursor: String,
        textAfterCursor: String = "",
        appBundleIdentifier: String? = nil,
        fieldIdentityDescription: String? = nil,
        visiblePageContext: VisiblePageContext? = nil,
        maxVisibleWords: Int = CompletionModelPolicy.mvp.maxVisibleWords,
        mode: CompletionRequestMode = .phraseContinuation
    ) {
        self.textBeforeCursor = textBeforeCursor
        self.textAfterCursor = textAfterCursor
        self.appBundleIdentifier = appBundleIdentifier
        self.fieldIdentityDescription = fieldIdentityDescription
        self.visiblePageContext = visiblePageContext
        self.maxVisibleWords = CompletionModelPolicy.clampedVisibleWords(maxVisibleWords)
        self.mode = mode
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
