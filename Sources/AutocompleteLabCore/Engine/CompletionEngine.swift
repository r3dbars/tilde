import Foundation

public enum CompletionRequestMode: String, Equatable, Sendable {
    case phraseContinuation
    case wordCompletion
}

public struct CompletionRequest: Equatable, Sendable {
    public let textBeforeCursor: String
    public let textAfterCursor: String
    public let appBundleIdentifier: String?
    public let maxVisibleWords: Int
    public let mode: CompletionRequestMode
    public let suggestionID: String

    public init(
        textBeforeCursor: String,
        textAfterCursor: String = "",
        appBundleIdentifier: String? = nil,
        maxVisibleWords: Int = CompletionModelPolicy.mvp.maxVisibleWords,
        mode: CompletionRequestMode = .phraseContinuation,
        suggestionID: String = ""
    ) {
        self.textBeforeCursor = textBeforeCursor
        self.textAfterCursor = textAfterCursor
        self.appBundleIdentifier = appBundleIdentifier
        self.maxVisibleWords = maxVisibleWords
        self.mode = mode
        self.suggestionID = suggestionID
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
