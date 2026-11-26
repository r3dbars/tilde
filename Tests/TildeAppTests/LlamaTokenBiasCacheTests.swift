import TildeCore
import Foundation
import Testing
@testable import TildeApp

@Suite("Llama token bias cache & completion integration")
struct LlamaTokenBiasCacheTests {
    @Test("LlamaTokenBiasCache caches resolved tokens and clears on reset")
    func cachesAndClears() async {
        let counter = TokenizeCounter()
        let cache = LlamaTokenBiasCache(
            baseURL: URL(string: "http://127.0.0.1:17872")!,
            apiKey: "test-key",
            perform: { request in
                #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-key")
                await counter.increment()
                return [4242]
            }
        )
        let terms = [WeightedBiasTerm(term: "Kubernetes", weight: 1.35)]
        let first = await cache.logitBiasEntries(for: terms)
        let second = await cache.logitBiasEntries(for: terms)
        #expect(first.count == 1)
        #expect(second.count == 1)
        #expect(await counter.value == 1)

        await cache.clear()
        _ = await cache.logitBiasEntries(for: terms)
        #expect(await counter.value == 2)
    }

    @Test("LlamaCompletionEngine sends logit_bias and trims low-confidence tail words from streamed probabilities")
    func engineSendsBiasAndTrimsShakyTail() async throws {
        let capture = BodyCaptureTransport(lines: [
            #"data: {"content":" Thursday","completion_probabilities":[{"prob":0.85}]}"#,
            #"data: {"content":" afternoon","completion_probabilities":[{"prob":0.78}]}"#,
            #"data: {"content":" banana","completion_probabilities":[{"prob":0.005}]}"#,
            #"data: {"stop":true,"tokens_predicted":3,"stopped_eos":true}"#,
        ])
        let cache = LlamaTokenBiasCache(
            baseURL: URL(string: "http://127.0.0.1:17872")!,
            perform: { _ in [777] }
        )
        let engine = LlamaCompletionEngine(
            baseURL: URL(string: "http://127.0.0.1:17872")!,
            diagnostics: .disabled,
            transport: capture,
            tokenBiasCache: cache
        )
        let scene = ScreenScene.Scene(
            mode: .replying,
            conversationTurns: [.init(speaker: .other, text: "Does Thursday work for the demo?")],
            referenceSnippets: []
        )
        let decision = try await engine.decide(
            textBeforeCursor: "Yes let's do ",
            appBundleIdentifier: "com.tinyspeck.slackmacgap",
            scene: scene,
            onPartialSuggestion: { _, _ in }
        )
        let sentBody = try #require(capture.lastBodyJSON)
        let bias = sentBody["logit_bias"] as? [[Any]]
        #expect(bias?.isEmpty == false)
        #expect((sentBody["n_probs"] as? Int) == 1)
        // Low-confidence 3rd word "banana" is trimmed before returning.
        #expect(decision.suggestion?.visibleText.contains("Thursday") == true)
        #expect(decision.suggestion?.visibleText.contains("banana") == false)
    }
}

private actor TokenizeCounter {
    var value = 0
    func increment() { value += 1 }
}

private final class BodyCaptureTransport: LlamaCompletionStreamingTransport, @unchecked Sendable {
    private let lines: [String]
    private let lock = NSLock()
    private var capturedBody: [String: Any]?

    init(lines: [String]) { self.lines = lines }

    var lastBodyJSON: [String: Any]? { lock.withLock { capturedBody } }

    func open(request: URLRequest) async throws -> LlamaCompletionHTTPStream {
        if let data = request.httpBody,
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            lock.withLock { capturedBody = obj }
        }
        let captured = lines
        return LlamaCompletionHTTPStream(
            statusCode: 200,
            lines: AsyncThrowingStream { continuation in
                for line in captured { continuation.yield(line) }
                continuation.finish()
            },
            cancel: {}
        )
    }
}
