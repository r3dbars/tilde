import Foundation

/// One generated token plus the model's local probability mass at that step.
/// Token text and alternatives are private completion content: memory-only,
/// never diagnostics-safe, never persisted by this type.
public struct CompletionTokenEvidence: Equatable, Sendable {
    public struct Alternative: Equatable, Sendable {
        public let text: String
        public let probability: Double

        public init(text: String, probability: Double) {
            self.text = text
            self.probability = Self.clamped(probability)
        }

        private static func clamped(_ value: Double) -> Double {
            min(max(value, 0), 1)
        }
    }

    public let text: String
    public let probability: Double
    public let alternatives: [Alternative]

    public init(text: String, probability: Double, alternatives: [Alternative] = []) {
        self.text = text
        self.probability = min(max(probability, 0), 1)
        self.alternatives = alternatives
    }
}

/// The visible completion plus its token-level uncertainty trace. The trace is
/// optional-by-emptiness so an older/changed llama-server response can fail
/// open to today's completion behavior instead of making Tilde silent.
public struct CompletionEvidence: Equatable, Sendable {
    public let suggestion: CompletionSuggestion?
    public let tokens: [CompletionTokenEvidence]

    public init(suggestion: CompletionSuggestion?, tokens: [CompletionTokenEvidence]) {
        self.suggestion = suggestion
        self.tokens = tokens
    }

    public var hasUncertainty: Bool { !tokens.isEmpty }
}
