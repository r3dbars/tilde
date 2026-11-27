import Foundation
import Testing
import TildeCore
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

    @Test("n_probs=3 streamedTokens capture top1Margin, entropy, runnerUpRatio, and tolerate empty EOS token strings")
    func streamedTokenProbabilitiesWithTopLogprobsAndEOS() throws {
        let client = try client()
        let rows: [[String: Any]] = [
            [
                "id": 10, "token": " works", "logprob": log(0.65),
                "top_logprobs": [
                    ["id": 10, "token": " works", "logprob": log(0.65)],
                    ["id": 11, "token": " sounds", "logprob": log(0.20)],
                    ["id": 12, "token": " looks", "logprob": log(0.05)],
                ],
            ],
            [
                "id": 20, "token": " well", "logprob": log(0.80),
                "top_logprobs": [
                    ["id": 20, "token": " well", "logprob": log(0.80)],
                    ["id": 21, "token": " great", "logprob": log(0.10)],
                    ["id": 22, "token": " fine", "logprob": log(0.05)],
                ],
            ],
            // Trailing EOS token with empty rendered text must not invalidate earlier tokens.
            [
                "id": 2, "token": "", "logprob": log(0.95),
                "top_logprobs": [
                    ["id": 2, "token": "", "logprob": log(0.95)],
                    ["id": 3, "token": ".", "logprob": log(0.03)],
                ],
            ],
        ]
        let tokens = client.streamedTokenProbabilities(rows)
        #expect(tokens.count == 2)
        #expect(tokens[0].piece == " works")
        #expect(abs(tokens[0].probability - 0.65) < 1e-12)
        #expect(abs(try #require(tokens[0].top1Margin) - 0.45) < 1e-12)
        #expect(abs(try #require(tokens[0].runnerUpRatio) - (0.20 / 0.65)) < 1e-12)
        #expect(try #require(tokens[0].entropy) > 0)
        #expect(tokens[1].piece == " well")
        #expect(abs(try #require(tokens[1].top1Margin) - 0.70) < 1e-12)

        // Invalid probability anywhere fails closed cleanly.
        let corrupted: [[String: Any]] = [
            ["id": 10, "token": " works", "logprob": log(0.65)],
            ["id": 11, "token": " bad", "logprob": 1.5],
        ]
        #expect(client.streamedTokenProbabilities(corrupted).isEmpty)
    }

    @Test("TildeLabKit wires WordConfidenceTruncator, minimumFirstWordProbability, QuietGate, windowTitle, and LoRA cache isolation")
    func mindReaderLabWiring() throws {
        let scenario = LabScenario(
            id: "mindreader.wiring.1",
            category: "reply.confirm",
            typedContext: "That ",
            scene: LabScene(
                mode: .replying,
                turns: [LabSceneTurn(speaker: .other, text: "Can we meet Thursday at 3pm?")],
                windowTitle: "Slack - Design Sync"
            ),
            expectation: LabExpectation(shouldSuggest: true, goldenContinuation: "works for me."),
            evaluation: .init(source: .synthetic)
        )

        var promptConfig = LabPromptConfiguration()
        promptConfig.includesWindowTitleInScene = false
        let withoutTitle = LabPromptComposer.prepare(scenario: scenario, configuration: promptConfig)
        #expect(!withoutTitle.prompt.contains("Slack - Design Sync"))

        promptConfig.includesWindowTitleInScene = true
        let withTitle = LabPromptComposer.prepare(scenario: scenario, configuration: promptConfig)
        #expect(withTitle.prompt.contains("Slack - Design Sync"))

        let tokens = [
            StreamedTokenProbability(piece: " works", probability: 0.75, top1Margin: 0.55, entropy: 0.50, runnerUpRatio: 0.27),
            StreamedTokenProbability(piece: " great", probability: 0.72, top1Margin: 0.50, entropy: 0.55, runnerUpRatio: 0.30),
            StreamedTokenProbability(piece: " purple", probability: 0.01, top1Margin: 0.005, entropy: 2.10, runnerUpRatio: 0.90),
        ]
        var truncArm = LabArmConfiguration(id: "trunc")
        truncArm.judgment.appliesWordConfidenceTruncation = true
        let trimmedDecision = LabOutputJudge.judge(
            rawOutput: " works great purple",
            preparedPrompt: withTitle,
            scenario: scenario,
            configuration: truncArm,
            meanTokenProbability: 0.49,
            streamedTokens: tokens
        )
        #expect(trimmedDecision.reason == .shown)
        #expect(trimmedDecision.suggestion == "works great")

        // Scalar first-word gate suppresses weak word 1.
        let weakTokens = [
            StreamedTokenProbability(piece: " maybe", probability: 0.12, top1Margin: 0.02, entropy: 1.90, runnerUpRatio: 0.85),
            StreamedTokenProbability(piece: " later", probability: 0.25, top1Margin: 0.05, entropy: 1.70, runnerUpRatio: 0.80),
        ]
        var scalarArm = LabArmConfiguration(id: "scalar")
        scalarArm.judgment.minimumFirstWordProbability = 0.18
        let scalarRejected = LabOutputJudge.judge(
            rawOutput: " maybe later",
            preparedPrompt: withTitle,
            scenario: scenario,
            configuration: scalarArm,
            meanTokenProbability: 0.185,
            streamedTokens: weakTokens
        )
        #expect(scalarRejected.suggestion == nil)
        #expect(scalarRejected.reason == .lowConfidence)

        // QuietGate rejects low-margin/high-entropy candidate even when p_w1 >= 0.18.
        let ambiguousTokens = [
            StreamedTokenProbability(piece: " maybe", probability: 0.24, top1Margin: 0.02, entropy: 1.95, runnerUpRatio: 0.92),
            StreamedTokenProbability(piece: " later", probability: 0.22, top1Margin: 0.03, entropy: 1.85, runnerUpRatio: 0.86),
        ]
        var gateArm = LabArmConfiguration(id: "quiet-gate")
        gateArm.judgment.quietGate = SuggestionQuietGate.Configuration(enabled: true, threshold: 0.50)
        let gateRejected = LabOutputJudge.judge(
            rawOutput: " maybe later",
            preparedPrompt: withTitle,
            scenario: scenario,
            configuration: gateArm,
            meanTokenProbability: 0.23,
            streamedTokens: ambiguousTokens
        )
        #expect(gateRejected.suggestion == nil)
        #expect(gateRejected.reason == .lowConfidence)

        // LoRA asset snapshot changes effectiveModelDigestSHA256 so base and LoRA caches never collide.
        let baseAssets = LabAssetSnapshot(
            modelIdentifier: "qwen4b",
            modelRevision: "local",
            modelSHA256: String(repeating: "a", count: 64),
            helperSHA256: String(repeating: "b", count: 64)
        )
        let loraAssets = LabAssetSnapshot(
            modelIdentifier: "qwen4b",
            modelRevision: "local",
            modelSHA256: String(repeating: "a", count: 64),
            helperSHA256: String(repeating: "b", count: 64),
            loraSHA256: String(repeating: "c", count: 64)
        )
        #expect(baseAssets.effectiveModelDigestSHA256 == baseAssets.modelSHA256)
        #expect(loraAssets.effectiveModelDigestSHA256 != baseAssets.effectiveModelDigestSHA256)
    }
}
