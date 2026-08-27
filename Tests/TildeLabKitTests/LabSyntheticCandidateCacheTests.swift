import Foundation
import Testing
@testable import TildeLabKit

@Suite("Tilde Lab synthetic candidate cache")
struct LabSyntheticCandidateCacheTests {
    @Test("A synthetic raw candidate round-trips and can be deleted")
    func roundTripAndDelete() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = try LabSyntheticCandidateCache(fileURL: root.appendingPathComponent("cache.sqlite3"))
        let scenario = syntheticScenario()
        let generation = LabGenerationConfiguration(probabilityCount: 5)
        let key = try LabCandidateCacheKey(
            modelSHA256: String(repeating: "a", count: 64),
            helperSHA256: String(repeating: "b", count: 64),
            prompt: "private prompt is hashed, not stored as a key",
            generation: generation,
            scenario: scenario
        )
        let expected = LabCachedCandidate(
            response: LabModelResponse(
                content: "world",
                latencyMilliseconds: 50,
                firstTokenMilliseconds: 12,
                meanTokenProbability: 0.8,
                tokenIDs: [1],
                tokenLogProbabilities: [-0.22],
                stopReason: "limit"
            ),
            assets: assets()
        )

        try await cache.store(expected, for: key)
        #expect(try await cache.value(for: key) == expected)
        #expect(try await cache.count() == 1)
        try await cache.deleteEverything()
        #expect(try await cache.count() == 0)

        let databaseBytes = try Data(contentsOf: cache.fileURL)
        #expect(!String(decoding: databaseBytes, as: UTF8.self).contains("private prompt"))
    }

    @Test("Private and curated sources fail closed before cache access")
    func rejectsNonSyntheticSources() {
        for source in [LabScenarioSource.handCurated, .publicCorpus, .historicalAccepted, .historicalTypedInstead] {
            let scenario = LabScenario(
                id: "private.\(source.rawValue.replacingOccurrences(of: "-", with: "."))",
                category: "reply.private",
                typedContext: "secret context",
                expectation: .init(shouldSuggest: true, goldenContinuation: "secret"),
                evaluation: .init(source: source)
            )
            #expect(throws: LabSyntheticCandidateCacheError.privateSourceForbidden) {
                _ = try LabCandidateCacheKey(
                    modelSHA256: String(repeating: "a", count: 64),
                    helperSHA256: String(repeating: "b", count: 64),
                    prompt: "secret prompt",
                    generation: .init(),
                    scenario: scenario
                )
            }
        }
    }

    @Test("Display-policy replay uses a cached candidate without another inference")
    func engineCacheHit() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = try LabSyntheticCandidateCache(fileURL: root.appendingPathComponent("cache.sqlite3"))
        let client = CacheCountingClient()
        let suite = LabScenarioSuite(name: "cache-engine", scenarios: [syntheticScenario()])
        let arm = LabArmConfiguration(id: "cache-arm")
        let context = LabCandidateCacheContext(cache: cache, assets: assets())

        let first = try await LabExperimentEngine.execute(
            suite: suite,
            arm: arm,
            repetitions: 1,
            timeoutSeconds: 2,
            seed: 1,
            clients: [client],
            candidateCache: context
        )
        let second = try await LabExperimentEngine.execute(
            suite: suite,
            arm: arm,
            repetitions: 1,
            timeoutSeconds: 2,
            seed: 1,
            clients: [client],
            candidateCache: context
        )

        #expect(first.results.map(\.outcome) == second.results.map(\.outcome))
        #expect(first.results.first?.candidateCacheHit == false)
        #expect(second.results.first?.candidateCacheHit == true)
        #expect(await client.requestCount == 1)
    }

    @Test("Confidence floors share one raw inference cache identity")
    func confidenceFloorIsPostGeneration() throws {
        var low = LabGenerationConfiguration(probabilityCount: 5)
        low.minimumMeanTokenProbability = 0.2
        var high = low
        high.minimumMeanTokenProbability = 0.8
        let common = (
            model: String(repeating: "a", count: 64),
            helper: String(repeating: "b", count: 64),
            prompt: "synthetic prompt",
            scenario: syntheticScenario()
        )
        let lowKey = try LabCandidateCacheKey(
            modelSHA256: common.model,
            helperSHA256: common.helper,
            prompt: common.prompt,
            generation: low,
            scenario: common.scenario
        )
        let highKey = try LabCandidateCacheKey(
            modelSHA256: common.model,
            helperSHA256: common.helper,
            prompt: common.prompt,
            generation: high,
            scenario: common.scenario
        )
        #expect(lowKey == highKey)
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("tilde-candidate-cache-\(UUID().uuidString)", isDirectory: true)
    }

    private func syntheticScenario() -> LabScenario {
        LabScenario(
            id: "synthetic.cache",
            category: "reply.synthetic",
            typedContext: "Hello ",
            expectation: .init(shouldSuggest: true, goldenContinuation: "world"),
            evaluation: .init(source: .synthetic)
        )
    }

    private func assets() -> LabAssetSnapshot {
        LabAssetSnapshot(
            modelIdentifier: "synthetic-model",
            modelRevision: "test",
            modelSHA256: String(repeating: "a", count: 64),
            helperSHA256: String(repeating: "b", count: 64)
        )
    }
}

private actor CacheCountingClient: LabCompletionClient {
    nonisolated let workerIndex = 0
    private(set) var requestCount = 0

    func complete(_ request: LabModelRequest) async throws -> LabModelResponse {
        requestCount += 1
        return LabModelResponse(
            content: "world",
            latencyMilliseconds: 10,
            meanTokenProbability: 0.9,
            tokenIDs: [42],
            tokenLogProbabilities: [-0.1],
            stopReason: "limit"
        )
    }
}
