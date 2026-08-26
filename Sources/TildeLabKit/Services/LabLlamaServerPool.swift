import Darwin
import Foundation

public enum LabServerPoolError: Error, LocalizedError, Sendable {
    case noFreePort
    case launchFailed(Int)
    case exitedBeforeHealthy(Int)
    case healthTimeout(Int)

    public var errorDescription: String? {
        switch self {
        case .noFreePort:
            "Tilde Lab could not reserve enough loopback ports."
        case let .launchFailed(index):
            "Model worker \(index + 1) could not launch."
        case let .exitedBeforeHealthy(index):
            "Model worker \(index + 1) exited before becoming healthy."
        case let .healthTimeout(index):
            "Model worker \(index + 1) did not become healthy before the startup deadline."
        }
    }
}

/// Emergency ownership registry so quitting Tilde Lab never leaves model
/// workers re-parented in the background. Only processes launched by the lab
/// are registered here; the running production Tilde helper is never touched.
public final class LabChildProcessRegistry: @unchecked Sendable {
    public static let shared = LabChildProcessRegistry()

    private let lock = NSLock()
    private var processes: [ObjectIdentifier: Process] = [:]

    private init() {}

    func register(_ process: Process) {
        lock.withLock { processes[ObjectIdentifier(process)] = process }
    }

    func unregister(_ process: Process) {
        _ = lock.withLock { processes.removeValue(forKey: ObjectIdentifier(process)) }
    }

    public func terminateAll() {
        let snapshot = lock.withLock { Array(processes.values) }
        for process in snapshot where process.isRunning { process.terminate() }
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline, snapshot.contains(where: \.isRunning) {
            usleep(50_000)
        }
        for process in snapshot where process.isRunning {
            kill(process.processIdentifier, SIGKILL)
        }
        lock.withLock { processes.removeAll() }
    }
}

public actor LabLlamaServerPool {
    private var workers: [LabLlamaServerWorker] = []
    private var activeConfiguration: LabExecutionConfiguration?
    private var activeClients: [any LabCompletionClient] = []

    public init() {}

    public func start(
        configuration: LabExecutionConfiguration,
        restart: Bool = true
    ) async throws -> [any LabCompletionClient] {
        if !restart,
           activeConfiguration == configuration,
           !workers.isEmpty,
           workers.allSatisfy(\.isRunning) {
            return activeClients
        }
        stop()
        let ports = try LabPortAllocator.allocate(configuration.workerCount)

        do {
            let started = try await withThrowingTaskGroup(of: LabLlamaServerWorker.self) { group in
                for (index, port) in ports.enumerated() {
                    group.addTask {
                        try await LabLlamaServerWorker.start(
                            index: index,
                            port: port,
                            configuration: configuration
                        )
                    }
                }
                var result: [LabLlamaServerWorker] = []
                for try await worker in group { result.append(worker) }
                return result.sorted { $0.index < $1.index }
            }
            workers = started
        } catch {
            LabChildProcessRegistry.shared.terminateAll()
            workers = []
            throw error
        }

        var clients: [any LabCompletionClient] = []
        for worker in workers {
            for _ in 0..<configuration.slotsPerWorker {
                clients.append(try LabHTTPCompletionClient(
                    baseURL: worker.baseURL,
                    workerIndex: worker.index
                ))
            }
        }
        activeConfiguration = configuration
        activeClients = clients
        return clients
    }

    public func stop() {
        let active = workers
        workers = []
        activeConfiguration = nil
        activeClients = []
        for worker in active { worker.stop() }
    }
}

private final class LabLlamaServerWorker: @unchecked Sendable {
    let index: Int
    let port: Int
    let process: Process
    let baseURL: URL
    var isRunning: Bool { process.isRunning }

    private let stopLock = NSLock()
    private var stopped = false

    private init(index: Int, port: Int, process: Process) {
        self.index = index
        self.port = port
        self.process = process
        baseURL = URL(string: "http://127.0.0.1:\(port)")!
    }

    static func start(
        index: Int,
        port: Int,
        configuration: LabExecutionConfiguration
    ) async throws -> LabLlamaServerWorker {
        let process = Process()
        process.executableURL = configuration.serverExecutable
        var arguments = [
            "-m", configuration.modelFile.path,
            "--host", "127.0.0.1",
            "--port", String(port),
            "-c", String(configuration.contextSizePerSlot * configuration.slotsPerWorker),
            "--parallel", String(configuration.slotsPerWorker),
            "--threads", String(configuration.generationThreads),
            "--threads-batch", String(configuration.batchThreads),
            "--threads-http", String(configuration.HTTPThreads),
            "--batch-size", String(configuration.batchSize),
            "--ubatch-size", String(configuration.microBatchSize),
            "--flash-attn", configuration.flashAttention.rawValue,
            "--cache-type-k", configuration.keyCacheType.rawValue,
            "--cache-type-v", configuration.valueCacheType.rawValue,
            "--gpu-layers", configuration.GPUlayers,
            "--load-mode", configuration.loadMode.rawValue,
            "--slot-prompt-similarity", String(configuration.slotPromptSimilarity),
            configuration.continuousBatching ? "--cont-batching" : "--no-cont-batching",
            configuration.warmup ? "--warmup" : "--no-warmup",
            configuration.promptCaching ? "--cache-prompt" : "--no-cache-prompt",
            "--offline",
            "--no-ui",
            "--reasoning", "off",
            "--metrics",
        ]
        if configuration.fullSWA { arguments.append("--swa-full") }
        if !configuration.KVOffload { arguments.append("--no-kv-offload") }
        if configuration.promptCaching {
            arguments.append(contentsOf: ["--cache-reuse", String(configuration.cacheReuseTokens)])
        }
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { child in
            LabChildProcessRegistry.shared.unregister(child)
        }
        LabChildProcessRegistry.shared.register(process)
        do {
            try process.run()
        } catch {
            LabChildProcessRegistry.shared.unregister(process)
            throw LabServerPoolError.launchFailed(index)
        }
        let worker = LabLlamaServerWorker(index: index, port: port, process: process)
        do {
            try await worker.waitUntilHealthy(timeout: .seconds(180))
            return worker
        } catch {
            worker.stop()
            throw error
        }
    }

    func stop() {
        let shouldStop = stopLock.withLock { () -> Bool in
            guard !stopped else { return false }
            stopped = true
            return true
        }
        guard shouldStop else { return }
        if process.isRunning { process.terminate() }
    }

    private func waitUntilHealthy(timeout: Duration) async throws {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.connectionProxyDictionary = [:]
        configuration.urlCache = nil
        let session = URLSession(configuration: configuration)
        var request = URLRequest(url: baseURL.appendingPathComponent("health"))
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 2
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")

        while ContinuousClock.now < deadline {
            try Task.checkCancellation()
            guard process.isRunning else {
                throw LabServerPoolError.exitedBeforeHealthy(index)
            }
            if let (data, response) = try? await session.data(for: request),
               let http = response as? HTTPURLResponse,
               http.statusCode == 200,
               String(data: data, encoding: .utf8)?.contains("ok") == true {
                return
            }
            try await Task.sleep(for: .milliseconds(250))
        }
        throw LabServerPoolError.healthTimeout(index)
    }
}

private enum LabPortAllocator {
    static func allocate(_ count: Int) throws -> [Int] {
        var result: [Int] = []
        var seen = Set<Int>()
        for _ in 0..<max(0, count) {
            var selected: Int?
            for _ in 0..<32 {
                guard let candidate = freePort() else { continue }
                if seen.insert(candidate).inserted {
                    selected = candidate
                    break
                }
            }
            guard let selected else { throw LabServerPoolError.noFreePort }
            result.append(selected)
        }
        return result
    }

    private static func freePort() -> Int? {
        let descriptor = socket(AF_INET, SOCK_STREAM, 0)
        guard descriptor >= 0 else { return nil }
        defer { close(descriptor) }

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = 0
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
        let bound = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bound == 0 else { return nil }

        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let resolved = withUnsafeMutablePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(descriptor, $0, &length)
            }
        }
        guard resolved == 0 else { return nil }
        return Int(UInt16(bigEndian: address.sin_port))
    }
}
