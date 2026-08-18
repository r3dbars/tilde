import AutocompleteLabCore
import Foundation

/// Decodes only the tiny response surface Tilde owns. Unknown llama-server
/// fields are ignored. Missing probability data is valid and returns an empty
/// trace so uncertainty support can fail open without breaking autocomplete.
enum LlamaCompletionEvidenceParser {
    struct Payload: Decodable {
        let content: String
        let completionProbabilities: [TokenProbability]?
        let probs: [TokenProbability]?

        enum CodingKeys: String, CodingKey {
            case content
            case completionProbabilities = "completion_probabilities"
            case probs
        }
    }

    struct TokenProbability: Decodable {
        let token: String
        let logprob: Double?
        let topLogprobs: [TopProbability]?

        enum CodingKeys: String, CodingKey {
            case token, logprob
            case topLogprobs = "top_logprobs"
        }
    }

    struct TopProbability: Decodable {
        let token: String
        let logprob: Double
    }

    static func decode(_ data: Data) throws -> (content: String, tokens: [CompletionTokenEvidence]) {
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        let rawTokens = payload.completionProbabilities ?? payload.probs
        let tokens = rawTokens?.compactMap { item -> CompletionTokenEvidence? in
            guard let logprob = item.logprob else { return nil }
            let alternatives = (item.topLogprobs ?? []).map {
                CompletionTokenEvidence.Alternative(text: $0.token, probability: exp($0.logprob))
            }
            return CompletionTokenEvidence(
                text: item.token,
                probability: exp(logprob),
                alternatives: alternatives
            )
        } ?? []
        return (payload.content, tokens)
    }
}
