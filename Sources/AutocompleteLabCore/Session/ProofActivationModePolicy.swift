import Foundation

public struct ProofActivationModePolicy: Equatable, Sendable {
    public init() {}

    public func adjustedDecision(
        original: CompletionActivationDecision,
        wordFallback: CompletionActivationDecision,
        disablesPhraseContinuation: Bool,
        disablesWordCompletion: Bool
    ) -> CompletionActivationDecision {
        guard disablesPhraseContinuation,
              !disablesWordCompletion,
              original.requestMode == .phraseContinuation,
              wordFallback.requestMode == .wordCompletion else {
            return original
        }

        return wordFallback
    }
}
