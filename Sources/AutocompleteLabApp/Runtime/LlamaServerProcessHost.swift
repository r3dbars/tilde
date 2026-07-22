import Foundation

/// Manages a local llama.cpp server as the app's child process — the reliable
/// engine for models MLX can't serve well (Gemma 4, per docs/ime-tuning-log.md).
///
/// Lifecycle: start() launches llama-server bound to localhost, polls /health
/// until ready, relaunches on unexpected exit (bounded), and terminates the
/// child with the app. When the binary or model is missing the host simply
/// stays unhealthy and callers fall back to the MLX engine.
final class LlamaServerProcessHost: @unchecked Sendable {

    static let port = 17872
    static let modelReference = "google/gemma-4-E4B-it-qat-q4_0-gguf"
    static let defaultBinaryPaths = [
        "/opt/homebrew/bin/llama-server",
        "/usr/local/bin/llama-server",
    ]

    var baseURL: URL { URL(string: "http://127.0.0.1:\(Self.port)")! }

    var isHealthy: Bool {
        lock.lock()
        defer { lock.unlock() }
        return healthy
    }

    private let lock = NSLock()
    private var process: Process?
    private var healthy = false
    private var stopped = false
    private var restartCount = 0
    private let maximumRestarts = 3

    func start() {
        guard let binary = Self.defaultBinaryPaths.first(where: {
            FileManager.default.isExecutableFile(atPath: $0)
        }) else {
            DiagnosticsLog.shared.record("llama-server-unavailable", metadata: ["reason": "binary-missing"])
            return
        }
        launch(binary: binary)
    }

    func stop() {
        lock.lock()
        stopped = true
        healthy = false
        let running = process
        process = nil
        lock.unlock()
        running?.terminate()
    }

    // MARK: - Internals

    private func launch(binary: String) {
        let child = Process()
        child.executableURL = URL(fileURLWithPath: binary)
        child.arguments = [
            "-hf", Self.modelReference,
            "--host", "127.0.0.1",
            "--port", String(Self.port),
            "-c", "2048",
            // Gemma uses sliding-window attention; without --swa-full the slot
            // cache can't roll back past the window and consecutive keystrokes
            // re-read the whole prompt. --cache-reuse enables chunked prefix
            // reuse so only the newly typed tokens are processed.
            "--swa-full",
            "--cache-reuse", "256",
        ]
        child.standardOutput = FileHandle.nullDevice
        child.standardError = FileHandle.nullDevice
        child.terminationHandler = { [weak self] _ in
            self?.handleExit(binary: binary)
        }
        do {
            try child.run()
        } catch {
            DiagnosticsLog.shared.record("llama-server-unavailable", metadata: ["reason": "launch-failed"])
            return
        }
        lock.lock()
        process = child
        lock.unlock()
        DiagnosticsLog.shared.record("llama-server-start", metadata: ["restart": String(restartCount)])
        pollHealth()
    }

    private func handleExit(binary: String) {
        lock.lock()
        healthy = false
        process = nil
        let shouldRestart = !stopped && restartCount < maximumRestarts
        if shouldRestart { restartCount += 1 }
        lock.unlock()
        DiagnosticsLog.shared.record("llama-server-exit", metadata: ["willRestart": String(shouldRestart)])
        guard shouldRestart else { return }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self, !self.isStopped else { return }
            self.launch(binary: binary)
        }
    }

    private var isStopped: Bool {
        lock.lock()
        defer { lock.unlock() }
        return stopped
    }

    /// Polls /health until the server reports ready (model download + load can
    /// take minutes on first run), then flips `healthy`.
    private func pollHealth() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            for _ in 0..<600 {
                guard let self, !self.isStopped else { return }
                self.lock.lock()
                let running = self.process != nil
                self.lock.unlock()
                guard running else { return }
                if Self.probeHealth(port: Self.port) {
                    self.lock.lock()
                    self.healthy = true
                    self.lock.unlock()
                    DiagnosticsLog.shared.record("llama-server-healthy", metadata: [:])
                    return
                }
                Thread.sleep(forTimeInterval: 2)
            }
        }
    }

    private static func probeHealth(port: Int) -> Bool {
        guard let url = URL(string: "http://127.0.0.1:\(port)/health") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 2
        let semaphore = DispatchSemaphore(value: 0)
        var ok = false
        URLSession.shared.dataTask(with: request) { data, response, _ in
            if let http = response as? HTTPURLResponse, http.statusCode == 200,
               let data, String(data: data, encoding: .utf8)?.contains("ok") == true {
                ok = true
            }
            semaphore.signal()
        }.resume()
        semaphore.wait()
        return ok
    }
}
