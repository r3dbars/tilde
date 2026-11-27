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
                return [.init(id: 4242, piece: " Kubernetes")]
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

    @Test("LlamaTokenBiasCache rejects bare whitespace and single-letter BPE pieces")
    func rejectsBareSpaceAndSingleLetterPieces() async {
        let cache = LlamaTokenBiasCache(
            baseURL: URL(string: "http://127.0.0.1:17872")!,
            perform: { request in
                let body = request.httpBody.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
                let content = body?["content"] as? String ?? ""
                if content == " 10am" {
                    return [.init(id: 220, piece: " "), .init(id: 16, piece: "1")]
                }
                if content == " gRPC" {
                    return [.init(id: 338, piece: " g"), .init(id: 28565, piece: "RPC")]
                }
                return [.init(id: 7548, piece: " Thursday")]
            }
        )
        let entries = await cache.logitBiasEntries(for: [
            WeightedBiasTerm(term: "10am", weight: 1.35),
            WeightedBiasTerm(term: "gRPC", weight: 1.35),
            WeightedBiasTerm(term: "Thursday", weight: 1.35),
        ])
        #expect(entries == [.init(tokenID: 7548, weight: 1.35)])
    }

    @Test("LlamaCompletionEngine sends logit_bias and trims low-confidence tail words from streamed probabilities")
    func engineSendsBiasAndTrimsShakyTail() async throws {
        let capture = BodyCaptureTransport(lines: [
            #"data: {"content":" Thursday","completion_probabilities":[{"prob":0.85}]}"#,
            #"data: {"content":" afternoon","completion_probabilities":[{"prob":0.78}]}"#,
            #"data: {"content":" banana","completion_probabilities":[{"prob":0.005}]}"#,
            #"data: {"content":" xylophone","completion_probabilities":[{"prob":0.002}]}"#,
            #"data: {"stop":true,"tokens_predicted":4,"stopped_eos":true}"#,
        ])
        let cache = LlamaTokenBiasCache(
            baseURL: URL(string: "http://127.0.0.1:17872")!,
            performTokenIDs: { _ in [777] }
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
        let partials = PartialRecorder()
        let decision = try await engine.decide(
            textBeforeCursor: "Yes let's do ",
            appBundleIdentifier: "com.tinyspeck.slackmacgap",
            scene: scene,
            onPartialSuggestion: { suggestion, _ in partials.record(suggestion.visibleText) }
        )
        let sentBody = try #require(capture.lastBodyJSON)
        let bias = sentBody["logit_bias"] as? [[Any]]
        #expect(bias?.isEmpty == false)
        #expect((sentBody["n_probs"] as? Int) == 3)
        // Collapsing tail word "banana" is neither flashed as a partial nor kept in the final suggestion.
        #expect(partials.all.allSatisfy { !$0.contains("banana") && !$0.contains("xylophone") })
        #expect(decision.suggestion?.visibleText.contains("Thursday") == true)
        #expect(decision.suggestion?.visibleText.contains("banana") == false)
    }

    @Test("LlamaCompletionEngine suppresses weak first-word guesses before flashing any partial")
    func engineSuppressesLowConfidenceFirstWord() async throws {
        let capture = BodyCaptureTransport(lines: [
            #"data: {"content":" probably","completion_probabilities":[{"prob":0.09}]}"#,
            #"data: {"content":" tomorrow","completion_probabilities":[{"prob":0.85}]}"#,
            #"data: {"content":" morning","completion_probabilities":[{"prob":0.90}]}"#,
            #"data: {"stop":true,"tokens_predicted":3,"stopped_eos":true}"#,
        ])
        let engine = LlamaCompletionEngine(
            baseURL: URL(string: "http://127.0.0.1:17872")!,
            diagnostics: .disabled,
            transport: capture
        )
        let partials = PartialRecorder()
        let decision = try await engine.decide(
            textBeforeCursor: "I think we should ",
            appBundleIdentifier: "com.tinyspeck.slackmacgap",
            scene: nil,
            onPartialSuggestion: { suggestion, _ in partials.record(suggestion.visibleText) }
        )
        #expect(partials.all.isEmpty)
        #expect(decision.suggestion == nil)
        #expect(decision.reason == .lowConfidence)
    }

    @Test("LlamaServerProcessHost appends --lora only when provided and ModelManager validates 0600 GGUF")
    func loraValidationAndArguments() throws {
        let baseArgs = LlamaServerProcessHost.helperArguments(model: "/dev/fd/0", port: 17_872)
        #expect(!baseArgs.contains("--lora"))
        let loraArgs = LlamaServerProcessHost.helperArguments(
            model: "/dev/fd/0",
            port: 17_872,
            lora: "/tmp/personal.lora.gguf"
        )
        #expect(loraArgs.suffix(2) == ["--lora-scaled", "/tmp/personal.lora.gguf:0.60"])
        let fullScaleArgs = LlamaServerProcessHost.helperArguments(
            model: "/dev/fd/0",
            port: 17_872,
            lora: "/tmp/personal.lora.gguf",
            loraScale: 1.0
        )
        #expect(fullScaleArgs.suffix(2) == ["--lora", "/tmp/personal.lora.gguf"])

        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("tilde-lora-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        let canonicalRoot = tempRoot.resolvingSymlinksInPath()
        defer { try? FileManager.default.removeItem(at: canonicalRoot) }

        let manager = ModelManager(descriptor: .qwen35B4BQ4KM, rootDirectory: canonicalRoot)
        try FileManager.default.createDirectory(
            at: manager.modelDirectory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        #expect(manager.verifiedLocalLoRAPath() == nil)

        // Valid GGUF v3 header + >=64 bytes + 0600 -> accepted.
        var validGGUF = Data([0x47, 0x47, 0x55, 0x46, 0x03, 0x00, 0x00, 0x00])
        validGGUF.append(Data(repeating: 0, count: 64))
        try validGGUF.write(to: manager.loraURL)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: manager.loraURL.path)
        #expect(manager.verifiedLocalLoRAPath() != nil)
        #expect(URL(fileURLWithPath: try #require(manager.verifiedLocalLoRAPath())).resolvingSymlinksInPath().standardizedFileURL.path
            == manager.loraURL.resolvingSymlinksInPath().standardizedFileURL.path)

        // Loose permissions (0644) -> fail closed.
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: manager.loraURL.path)
        #expect(manager.verifiedLocalLoRAPath() == nil)

        // Bad magic with 0600 -> fail closed.
        try Data(repeating: 0x41, count: 72).write(to: manager.loraURL)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: manager.loraURL.path)
        #expect(manager.verifiedLocalLoRAPath() == nil)
    }
}

private final class PartialRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String] = []
    func record(_ text: String) { lock.withLock { values.append(text) } }
    var all: [String] { lock.withLock { values } }
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
