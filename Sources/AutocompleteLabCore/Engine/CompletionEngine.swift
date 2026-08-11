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

/// A single completion request from the input method: the text being written
/// and where it's being written.
public struct CompletionRequest: Equatable, Sendable {
    public let textBeforeCursor: String
    public let textAfterCursor: String
    public let appBundleIdentifier: String?
    public let maxVisibleWords: Int
    public let mode: CompletionRequestMode

    public init(
        textBeforeCursor: String,
        textAfterCursor: String = "",
        appBundleIdentifier: String? = nil,
        maxVisibleWords: Int = CompletionSuggestion.defaultMaxVisibleWords,
        mode: CompletionRequestMode = .phraseContinuation
    ) {
        self.textBeforeCursor = textBeforeCursor
        self.textAfterCursor = textAfterCursor
        self.appBundleIdentifier = appBundleIdentifier
        self.maxVisibleWords = CompletionSuggestion.clampedVisibleWords(maxVisibleWords)
        self.mode = mode
    }
}

public protocol CompletionEngine: Sendable {
    func suggestion(for request: CompletionRequest) async throws -> CompletionSuggestion?
}
