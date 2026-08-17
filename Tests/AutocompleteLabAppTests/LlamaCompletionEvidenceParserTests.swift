import Foundation
import Testing
@testable import AutocompleteLabApp

@Suite("Llama completion uncertainty parser")
struct LlamaCompletionEvidenceParserTests {
    @Test("Decodes greedy token log probabilities and alternatives")
    func decodesProbabilities() throws {
        let json = """
        {"content":" hello there","probs":[{"token":" hello","logprob":-0.2231435513,"top_logprobs":[{"token":" hello","logprob":-0.2231435513},{"token":" hey","logprob":-1.6094379124}]},{"token":" there","logprob":-0.5108256238,"top_logprobs":[]}]}
        """
        let decoded = try LlamaCompletionEvidenceParser.decode(Data(json.utf8))
        #expect(decoded.content == " hello there")
        #expect(decoded.tokens.count == 2)
        #expect(abs(decoded.tokens[0].probability - 0.8) < 0.0001)
        #expect(decoded.tokens[0].alternatives.count == 2)
        #expect(abs(decoded.tokens[0].alternatives[1].probability - 0.2) < 0.0001)
        #expect(abs(decoded.tokens[1].probability - 0.6) < 0.0001)
    }

    @Test("Missing probability trace fails open")
    func missingProbabilities() throws {
        let json = """{"content":"hello"}"""
        let decoded = try LlamaCompletionEvidenceParser.decode(Data(json.utf8))
        #expect(decoded.content == "hello")
        #expect(decoded.tokens.isEmpty)
    }
}
