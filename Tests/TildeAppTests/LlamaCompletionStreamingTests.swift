import TildeCore
import Foundation
import Testing
@testable import TildeApp

@Suite("Llama completion streaming")
struct LlamaCompletionStreamingTests {
    @Test("Cancelling an in-flight stream cancels its transport")
    func cancellationReachesTransport() async {
        let probe = StreamingTransportProbe()
        let engine = LlamaCompletionEngine(
            baseURL: URL(string: "http://127.0.0.1:17872")!,
            diagnostics: .disabled,
            transport: ProbeTransport(probe: probe)
        )

        let task = Task {
            try await engine.suggestion(
                textBeforeCursor: "hello ",
                appBundleIdentifier: "com.apple.TextEdit",
                scene: nil
            )
        }
        await probe.waitUntilOpened()
        task.cancel()
        _ = try? await task.value
        #expect(probe.wasCancelled)
    }

    @Test("Cancelling the real URLSession transport cancels its data task")
    func cancellationReachesURLSessionTask() async {
        StreamingURLProtocol.probe.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StreamingURLProtocol.self]
        let engine = LlamaCompletionEngine(
            baseURL: URL(string: "http://127.0.0.1:17872")!,
            diagnostics: .disabled,
            transport: URLSessionLlamaCompletionTransport(configuration: configuration)
        )

        let task = Task {
            try await engine.suggestion(
                textBeforeCursor: "hello ",
                appBundleIdentifier: "com.apple.TextEdit",
                scene: nil
            )
        }
        await StreamingURLProtocol.probe.waitUntilStarted()
        task.cancel()
        _ = try? await task.value
        await StreamingURLProtocol.probe.waitUntilStopped()
        #expect(StreamingURLProtocol.probe.wasStopped)
    }

    @Test("Packaged llama delta frames preserve repeated tokens")
    func repeatedDeltaTokensAreAppended() async throws {
        let transport = FixedFrameTransport(lines: [
            #"data: {"content":" very"}"#,
            #"data: {"content":" very"}"#,
            #"data: {"content":" good "}"#,
            #"data: {"stop":true,"tokens_predicted":3,"stopped_word":true}"#,
        ])
        let engine = LlamaCompletionEngine(
            baseURL: URL(string: "http://127.0.0.1:17872")!,
            diagnostics: .disabled,
            transport: transport
        )

        let suggestion = try await engine.suggestion(
            textBeforeCursor: "That was ",
            appBundleIdentifier: "com.apple.TextEdit",
            scene: nil
        )
        #expect(suggestion?.visibleText.contains("very very good") == true)
    }

    @Test("Partials stop at whitespace and never repeat")
    func partialsAreWordBounded() async throws {
        let transport = FixedFrameTransport(lines: [
            #"data: {"content":" at"}"#,
            #"data: {"content":" 10"}"#,
            #"data: {"content":":"}"#,
            #"data: {"content":"30"}"#,
            #"data: {"content":" tomorrow"}"#,
            #"data: {"content":" morning"}"#,
            #"data: {"stop":true,"tokens_predicted":6,"stopped_limit":true}"#,
        ])
        let engine = LlamaCompletionEngine(
            baseURL: URL(string: "http://127.0.0.1:17872")!,
            diagnostics: .disabled,
            transport: transport
        )
        let partials = PartialCollector()
        let final = try await engine.suggestion(
            textBeforeCursor: "Let's meet ",
            appBundleIdentifier: "com.apple.TextEdit",
            scene: nil,
            onPartialSuggestion: { partials.append($0.visibleText) }
        )
        #expect(partials.values == ["at", "at 10:30", "at 10:30 tomorrow"])
        #expect(final?.visibleText == "at 10:30 tomorrow morning")
    }

    @Test("9B preview uses its promoted three-word visible cap")
    func preview9BVisibleCap() async throws {
        let transport = FixedFrameTransport(lines: [
            #"data: {"content":" sounds really good today "}"#,
            #"data: {"stop":true,"tokens_predicted":5,"stopped_limit":true}"#,
        ])
        let engine = LlamaCompletionEngine(
            baseURL: URL(string: "http://127.0.0.1:17875")!,
            diagnostics: .disabled,
            transport: transport,
            productProfile: .preview9B
        )

        let suggestion = try await engine.suggestion(
            textBeforeCursor: "That ",
            appBundleIdentifier: "com.apple.TextEdit",
            scene: nil
        )
        #expect(suggestion?.visibleText == "sounds really good")
    }

    @Test("Malformed or non-SSE success responses fail closed")
    func malformedStreamsFailClosed() async {
        for lines in [
            ["data: {not-json}"],
            [#"{"content":"legacy aggregate"}"#],
            [#"data: {"unexpected":1}"#],
        ] {
            let engine = LlamaCompletionEngine(
                baseURL: URL(string: "http://127.0.0.1:17872")!,
                diagnostics: .disabled,
                transport: FixedFrameTransport(lines: lines)
            )
            do {
                _ = try await engine.suggestion(
                    textBeforeCursor: "hello ",
                    appBundleIdentifier: "com.apple.TextEdit",
                    scene: nil
                )
                Issue.record("expected malformed helper response to fail")
            } catch {
                // Expected: protocol incompatibility is not successful silence.
            }
        }
    }
}

private final class PartialCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [String] = []
    var values: [String] { lock.withLock { stored } }
    func append(_ value: String) { lock.withLock { stored.append(value) } }
}

private struct FixedFrameTransport: LlamaCompletionStreamingTransport {
    let lines: [String]

    func open(request: URLRequest) async throws -> LlamaCompletionHTTPStream {
        LlamaCompletionHTTPStream(
            statusCode: 200,
            lines: AsyncThrowingStream { continuation in
                for line in lines { continuation.yield(line) }
                continuation.finish()
            },
            cancel: {}
        )
    }
}

private final class StreamingURLProtocol: URLProtocol, @unchecked Sendable {
    static let probe = URLProtocolCancellationProbe()

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.probe.markStarted()
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "text/event-stream"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    }

    override func stopLoading() {
        Self.probe.markStopped()
    }
}

private final class URLProtocolCancellationProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var started = false
    private var stopped = false

    var wasStopped: Bool {
        lock.withLock { stopped }
    }

    func reset() {
        lock.withLock {
            started = false
            stopped = false
        }
    }

    func markStarted() { lock.withLock { started = true } }
    func markStopped() { lock.withLock { stopped = true } }

    func waitUntilStarted() async {
        await wait { self.lock.withLock { self.started } }
    }

    func waitUntilStopped() async {
        await wait { self.lock.withLock { self.stopped } }
    }

    private func wait(_ predicate: @escaping @Sendable () -> Bool) async {
        for _ in 0..<1_000 {
            if predicate() { return }
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
    }
}

private final class StreamingTransportProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var opened = false
    private var cancelled = false
    private var continuation: AsyncThrowingStream<String, Error>.Continuation?

    var wasCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    func markOpened(_ continuation: AsyncThrowingStream<String, Error>.Continuation) {
        lock.lock()
        opened = true
        self.continuation = continuation
        lock.unlock()
    }

    func waitUntilOpened() async {
        for _ in 0..<100 {
            if isOpened { return }
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
    }

    private var isOpened: Bool {
        lock.lock()
        defer { lock.unlock() }
        return opened
    }

    func cancel() {
        lock.lock()
        cancelled = true
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()
        continuation?.finish(throwing: CancellationError())
    }
}

private struct ProbeTransport: LlamaCompletionStreamingTransport {
    let probe: StreamingTransportProbe

    func open(request: URLRequest) async throws -> LlamaCompletionHTTPStream {
        let lines = AsyncThrowingStream<String, Error> { continuation in
            probe.markOpened(continuation)
        }
        return LlamaCompletionHTTPStream(
            statusCode: 200,
            lines: lines,
            cancel: { probe.cancel() }
        )
    }
}
