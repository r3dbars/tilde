import Foundation

/// The small seam between the completion engine and URLSession. Keeping an
/// explicit data task here makes cancellation observable and ensures a stale
/// suggestion stops helper inference instead of only abandoning a Swift loop.
struct LlamaCompletionHTTPStream: @unchecked Sendable {
    let statusCode: Int
    let lines: AsyncThrowingStream<String, Error>
    let cancel: @Sendable () -> Void
}

protocol LlamaCompletionStreamingTransport: Sendable {
    func open(request: URLRequest) async throws -> LlamaCompletionHTTPStream
}

/// Persistent localhost streaming transport backed by one shared `URLSession`.
///
/// Creating and invalidating a fresh `URLSession` per completion request forced
/// an `OperationQueue`, connection-pool teardown, and fresh TCP handshake on
/// every typed word. Multiplexing data tasks through one delegate keeps the
/// session and connection pool warm while preserving exact per-task
/// `URLSessionDataTask.cancel()` semantics so stale requests still abort
/// `llama-server` inference immediately.
final class URLSessionLlamaCompletionTransport: LlamaCompletionStreamingTransport, @unchecked Sendable {
    private let multiplexer: URLSessionStreamMultiplexer
    private let session: URLSession

    init(configuration: URLSessionConfiguration = .ephemeral) {
        let prepared = (configuration.copy() as? URLSessionConfiguration) ?? .ephemeral
        prepared.requestCachePolicy = .reloadIgnoringLocalCacheData
        prepared.urlCache = nil
        prepared.httpCookieStorage = nil
        prepared.httpShouldSetCookies = false
        prepared.urlCredentialStorage = nil
        prepared.connectionProxyDictionary = [:]
        prepared.httpMaximumConnectionsPerHost = 4
        let multiplexer = URLSessionStreamMultiplexer()
        self.multiplexer = multiplexer
        self.session = URLSession(configuration: prepared, delegate: multiplexer, delegateQueue: nil)
    }

    deinit {
        session.finishTasksAndInvalidate()
    }

    func open(request: URLRequest) async throws -> LlamaCompletionHTTPStream {
        let operation = URLSessionStreamOperation()
        let task = session.dataTask(with: request)
        let taskID = task.taskIdentifier
        multiplexer.register(operation, for: taskID)
        operation.attach(task: task) { [weak multiplexer] in
            multiplexer?.remove(taskIdentifier: taskID)
        }
        task.resume()
        let statusCode = try await operation.waitForResponse()
        return LlamaCompletionHTTPStream(
            statusCode: statusCode,
            lines: operation.lines,
            cancel: { operation.cancel() }
        )
    }
}

private final class URLSessionStreamMultiplexer: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var operations: [Int: URLSessionStreamOperation] = [:]

    func register(_ operation: URLSessionStreamOperation, for taskIdentifier: Int) {
        lock.withLock { operations[taskIdentifier] = operation }
    }

    func remove(taskIdentifier: Int) {
        _ = lock.withLock { operations.removeValue(forKey: taskIdentifier) }
    }

    private func operation(for task: URLSessionTask) -> URLSessionStreamOperation? {
        lock.withLock { operations[task.taskIdentifier] }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void
    ) {
        guard let operation = operation(for: dataTask) else {
            completionHandler(.cancel)
            return
        }
        operation.didReceive(response: response, completionHandler: completionHandler)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        operation(for: dataTask)?.didReceive(data: data)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        let operation = lock.withLock { operations.removeValue(forKey: task.taskIdentifier) }
        operation?.didComplete(withError: error)
    }
}

private final class URLSessionStreamOperation: @unchecked Sendable {
    let lines: AsyncThrowingStream<String, Error>

    private let lock = NSLock()
    private let lineContinuation: AsyncThrowingStream<String, Error>.Continuation
    private var responseContinuation: CheckedContinuation<Int, Error>?
    private var receivedStatusCode: Int?
    private var responseError: Error?
    private var buffer = Data()
    private var task: URLSessionDataTask?
    private var unregister: (@Sendable () -> Void)?
    private var finished = false

    init() {
        var captured: AsyncThrowingStream<String, Error>.Continuation!
        lines = AsyncThrowingStream<String, Error> { captured = $0 }
        lineContinuation = captured
        lineContinuation.onTermination = { @Sendable [weak self] termination in
            if case .cancelled = termination { self?.cancel() }
        }
    }

    func attach(task: URLSessionDataTask, unregister: @escaping @Sendable () -> Void) {
        let alreadyFinished: Bool = lock.withLock {
            if finished { return true }
            self.task = task
            self.unregister = unregister
            return false
        }
        if alreadyFinished {
            task.cancel()
            unregister()
        }
    }

    func waitForResponse() async throws -> Int {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                lock.lock()
                if let status = receivedStatusCode {
                    lock.unlock()
                    continuation.resume(returning: status)
                } else if let error = responseError {
                    lock.unlock()
                    continuation.resume(throwing: error)
                } else {
                    responseContinuation = continuation
                    lock.unlock()
                }
            }
        } onCancel: {
            cancel()
        }
    }

    func cancel() {
        finish(throwing: CancellationError(), cancelTask: true)
    }

    func didReceive(
        response: URLResponse,
        completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void
    ) {
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        lock.lock()
        guard !finished else {
            lock.unlock()
            completionHandler(.cancel)
            return
        }
        receivedStatusCode = status
        let continuation = responseContinuation
        responseContinuation = nil
        lock.unlock()
        continuation?.resume(returning: status)
        completionHandler(.allow)
    }

    func didReceive(data: Data) {
        lock.lock()
        guard !finished else {
            lock.unlock()
            return
        }
        buffer.append(data)
        var ready: [String] = []
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = buffer.prefix(upTo: newline)
            buffer.removeSubrange(...newline)
            ready.append(String(decoding: line, as: UTF8.self))
        }
        lock.unlock()
        for line in ready { lineContinuation.yield(line) }
    }

    func didComplete(withError error: Error?) {
        finish(throwing: error, cancelTask: false)
    }

    private func finish(throwing error: Error?, cancelTask: Bool) {
        lock.lock()
        guard !finished else {
            lock.unlock()
            return
        }
        finished = true
        let task = self.task
        let unregister = self.unregister
        self.task = nil
        self.unregister = nil
        let responseContinuation = self.responseContinuation
        self.responseContinuation = nil
        if receivedStatusCode == nil { responseError = error ?? URLError(.badServerResponse) }
        let tail = buffer
        buffer.removeAll(keepingCapacity: false)
        lock.unlock()

        unregister?()
        if cancelTask { task?.cancel() }
        if receivedStatusCode == nil {
            responseContinuation?.resume(throwing: error ?? URLError(.badServerResponse))
        }
        if let error {
            // A truncated frame must not mask the transport error.
            lineContinuation.finish(throwing: error)
        } else {
            if !tail.isEmpty { lineContinuation.yield(String(decoding: tail, as: UTF8.self)) }
            lineContinuation.finish()
        }
    }
}
