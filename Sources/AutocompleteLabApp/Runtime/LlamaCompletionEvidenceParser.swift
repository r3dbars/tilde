import AutocompleteLabCore
import Foundation

/// Decodes only the tiny response surface Tilde owns. Unknown llama-server
/// fields are ignored. Missing probability data is valid and returns an empty
/// trace so uncertainty support can fail open without breaking autocomplete.
enum LlamaCompletionEvidenceParser {
    struct Payload: Decodable {
        let content: String
        let probs: [TokenProbability]?
    }

    struct TokenProbability: Decodable {
        let token: String
        let prob: Double?
        let topProbs: [TopProbability]?

        enum CodingKeys: String, CodingKey {
            case token, prob
            case topProbs = "top_probs"
        }
    }

    struct TopProbability: Decodable {
        let token: String
        let prob: Double
    }

    static func decode(_ data: Data) throws -> (content: String, tokens: [CompletionTokenEvidence]) {
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        let tokens = payload.probs?.compactMap { item -> CompletionTokenEvidence? in
            guard let probability = item.prob else { return nil }
            let alternatives = (item.topProbs ?? []).map {
                CompletionTokenEvidence.Alternative(text: $0.token, probability: $0.prob)
            }
            return CompletionTokenEvidence(
                text: item.token,
                probability: probability,
                alternatives: alternatives
            )
        } ?? []
        return (payload.content, tokens)
    }
}
