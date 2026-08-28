import Foundation
import Testing
@testable import TildeLabKit

@Suite("Tilde Lab helper probability schema")
struct LabTokenProbabilityTests {
    private func client() throws -> LabHTTPCompletionClient {
        try LabHTTPCompletionClient(baseURL: URL(string: "http://127.0.0.1:1")!, workerIndex: 0)
    }

    @Test("Modern logprob rows retain selected-token evidence and alternatives")
    func modernLogProbability() throws {
        let client = try client()
        let rows: [[String: Any]] = [[
            "id": 42, "logprob": log(0.25),
            "top_logprobs": [["id": 9, "logprob": log(0.6)], ["id": 42, "logprob": log(0.25)]]
        ]]
        #expect(abs(try #require(client.probabilityValues(rows).first) - 0.25) < 1e-12)
        #expect(client.tokenLogProbabilities(rows) == [log(0.25)])
        #expect(abs(try #require(client.tokenProbabilityMargins(rows).first) - 0.35) < 1e-12)
        #expect(try #require(client.tokenEntropies(rows).first) > 0)
    }

    @Test("Post-sampling probability rows and legacy selected tokens remain readable")
    func compatibleSchemas() throws {
        let client = try client()
        let modern: [[String: Any]] = [["prob": 0.4, "top_probs": [["prob": 0.6], ["prob": 0.4]]]]
        #expect(client.probabilityValues(modern) == [0.4])
        #expect(abs(try #require(client.tokenProbabilityMargins(modern).first) - 0.2) < 1e-12)
        let legacy: [[String: Any]] = [["content": "chosen", "probs": [
            ["tok_str": "other", "prob": 0.8], ["tok_str": "chosen", "prob": 0.2]
        ]]]
        #expect(client.probabilityValues(legacy) == [0.2])
        #expect(client.probabilityValues([["probs": [["prob": 0.9]]]]).isEmpty)
    }

    @Test("Missing, malformed, and partial evidence is not a confidence score")
    func invalidEvidence() throws {
        let client = try client()
        for invalid: [String: Any] in [[:], ["prob": -0.1], ["prob": 1.1],
                                      ["logprob": 1.0], ["logprob": Double.nan],
                                      ["prob": Double.infinity], ["logprob": "-0.5"]] {
            #expect(client.probabilityValues([invalid]).isEmpty)
            #expect(client.probabilityValues([["prob": 0.8], invalid]).isEmpty)
            #expect(client.tokenLogProbabilities([invalid]).isEmpty)
        }
        #expect(client.probabilityValues(nil).isEmpty)
        #expect(client.tokenLogProbabilities([["logprob": -1000.0]]) == [-1000])
    }

    @Test("Parsed helper evidence survives the synthetic cache round-trip")
    func cacheRoundTrip() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let client = try client()
        let rows: [[String: Any]] = [["id": 42, "logprob": log(0.25)]]
        let response = LabModelResponse(content: "synthetic", latencyMilliseconds: 1,
            meanTokenProbability: client.probabilityValues(rows).first,
            tokenIDs: [42], tokenLogProbabilities: client.tokenLogProbabilities(rows))
        let scenario = LabScenario(id: "synthetic.probability", category: "test",
            typedContext: "Synthetic", expectation: .init(shouldSuggest: true, goldenContinuation: "example"),
            evaluation: .init(source: .synthetic))
        let assets = LabAssetSnapshot(modelIdentifier: "synthetic", modelRevision: "test",
            modelSHA256: String(repeating: "a", count: 64), helperSHA256: String(repeating: "b", count: 64))
        let key = try LabCandidateCacheKey(modelSHA256: assets.modelSHA256, helperSHA256: assets.helperSHA256,
            prompt: "synthetic", generation: .init(probabilityCount: 5), scenario: scenario)
        let cache = try LabSyntheticCandidateCache(fileURL: root.appendingPathComponent("cache.sqlite3"))
        try await cache.store(LabCachedCandidate(response: response, assets: assets), for: key)
        #expect(try await cache.value(for: key)?.modelResponse == response)
    }
}
