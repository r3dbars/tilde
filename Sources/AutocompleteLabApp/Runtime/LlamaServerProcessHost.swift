import AutocompleteLabCore
import Foundation

/// Manages a local llama.cpp server as the app's child process — the app's
/// only model engine (llama-only, owner decision 2026-07-22).
///
/// Lifecycle: start() launches llama-server bound to localhost, polls /health
/// until ready, relaunches on unexpected exit (bounded by LlamaRestartBudget),
/// and terminates the child with the app. When the binary or model is missing
/// the host simply stays unhealthy; mid-word dictionary suffixes still work,
/// while phrase suggestions stay silent until the app-owned model recovers.
final class LlamaServerProcessHost: @unchecked Sendable {

    static let port = 17872

    /// THE model: Gemma 2 2B base, Q4_K_M (~1.6GB) — settled after the
    /// 14-model bakeoff (docs/quiz-lessons.md; base beats instruct for the raw
    /// recipe, fits any Apple Silicon Mac). One model, no hardware tiers, no
    /// runtime download: the GGUF ships inside the app.
    static let modelFileName = "gemma-2-2b.Q4_K_M.gguf"
    static let modelMinimumBytes: Int64 = 1_500_000_000

    /// Bundled binary first (self-contained installs), brew fallbacks for dev.
    static var binaryCandidates: [String] {
        var paths: [String] = []
        if let helpers = Bundle.main.url(forResource: nil, withExtension: nil, subdirectory: "Helpers")?.path {
            paths.append(helpers + "/llama-server")
        }
        paths.append(Bundle.main.bundlePath + "/Contents/Helpers/llama-server")
        paths.append("/opt/homebrew/bin/llama-server")
        paths.append("/usr/local/bin/llama-server")
        return paths
    }

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
    private var launchedAt: Date?
    private var restartBudget = LlamaRestartBudget()

    func start() {
        guard let binary = Self.binaryCandidates.first(where: {
            FileManager.default.isExecutableFile(atPath: $0)
        }) else {
            DiagnosticsLog.shared.record("llama-server-unavailable", metadata: ["reason": "binary-missing"])
            return
        }
        guard let model = Self.resolveModelPath() else {
            // Fail loudly and stay unhealthy — nothing downloads at runtime.
            DiagnosticsLog.shared.record("llama-server-unavailable", metadata: ["reason": "model-missing"])
            return
        }
        launch(binary: binary, modelPath: model)
    }

    /// The model is part of the app. Resolution order:
    ///   1. MODEL_PATH override — research: point at any local GGUF
    ///   2. the GGUF bundled inside the app — every distributed build
    ///   3. the dev copy in Application Support/Tilde/Models/GGUF
    /// Deleting the tier table, first-run download, and HF-cache adoption
    /// (2026-08-04) also removed the app's only network egress.
    static func resolveModelPath() -> String? {
        if let explicit = RuntimeSetting.string("MODEL_PATH"),
           FileManager.default.isReadableFile(atPath: explicit) {
            return explicit
        }
        let bundled = Bundle.main.bundlePath + "/Contents/Resources/bundled-model.gguf"
        if isUsableModelFile(at: URL(fileURLWithPath: bundled), minimumBytes: modelMinimumBytes) {
            return bundled
        }
        let dev = modelsDirectory.appendingPathComponent(modelFileName)
        if isUsableModelFile(at: dev, minimumBytes: modelMinimumBytes) {
            return dev.path
        }
        return nil
    }

    static var modelsDirectory: URL {
        (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory()))
            .appendingPathComponent("Tilde/Models/GGUF", isDirectory: true)
    }

    private static func isUsableModelFile(at url: URL, minimumBytes: Int64) -> Bool {
        guard let size = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 else {
            return false
        }
        return size >= minimumBytes
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

    /// A previous app instance's llama child can outlive it (kill -9, hard
    /// crash) and keep our port — the new child then fails to bind in a loop
    /// while the ORPHAN answers /health, which reads as "healthy then exit"
    /// and exhausts the restart budget (2026-08-04: root cause of the
    /// overnight engine death, reproduced live twice). Reap any llama-server
    /// listening on our port before launching ours. Anything else on the port
    /// is a loud unavailability, never a kill target.
    /// Returns true when the port is ours to bind.
    private static func reapOrphanServer() -> Bool {
        let listeners = shell("/usr/sbin/lsof", ["-ti", "tcp:\(port)", "-sTCP:LISTEN"])
            .split(separator: "\n")
            .compactMap { Int32($0.trimmingCharacters(in: .whitespaces)) }
        guard !listeners.isEmpty else { return true }
        var portIsOurs = true
        for pid in listeners {
            let command = shell("/bin/ps", ["-o", "comm=", "-p", String(pid)])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if command.hasSuffix("llama-server") {
                kill(pid, SIGTERM)
                DiagnosticsLog.shared.record("llama-orphan-reaped", metadata: ["pid": String(pid)])
            } else {
                portIsOurs = false
                DiagnosticsLog.shared.record(
                    "llama-server-unavailable",
                    metadata: ["reason": "port-held-by-foreign-process"]
                )
            }
        }
        // Give the kernel a beat to release the socket; if the orphan lingers,
        // the bind fails and the restart budget retries in 3s anyway.
        if portIsOurs { usleep(300_000) }
        return portIsOurs
    }

    private static func shell(_ path: String, _ arguments: [String]) -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = arguments
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do { try task.run() } catch { return "" }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func launch(binary: String, modelPath: String) {
        guard Self.reapOrphanServer() else { return }
        let child = Process()
        child.executableURL = URL(fileURLWithPath: binary)
        child.arguments = [
            "-m", modelPath,
            "--host", "127.0.0.1",
            "--port", String(Self.port),
            "-c", "4096",
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
            self?.handleExit(binary: binary, modelPath: modelPath)
        }
        do {
            try child.run()
        } catch {
            DiagnosticsLog.shared.record("llama-server-unavailable", metadata: ["reason": "launch-failed"])
            return
        }
        lock.lock()
        process = child
        launchedAt = Date()
        let restarts = restartBudget.consecutiveFailures
        lock.unlock()
        DiagnosticsLog.shared.record("llama-server-start", metadata: ["restart": String(restarts)])
        pollHealth()
    }

    private func handleExit(binary: String, modelPath: String) {
        lock.lock()
        let wasHealthy = healthy
        let uptime = launchedAt.map { Date().timeIntervalSince($0) } ?? 0
        healthy = false
        process = nil
        launchedAt = nil
        let shouldRestart = !stopped && restartBudget.shouldRestart(wasHealthy: wasHealthy, uptime: uptime)
        lock.unlock()
        DiagnosticsLog.shared.record("llama-server-exit", metadata: ["willRestart": String(shouldRestart)])
        guard shouldRestart else { return }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self, !self.isStopped else { return }
            self.launch(binary: binary, modelPath: modelPath)
        }
    }

    private var isStopped: Bool {
        lock.lock()
        defer { lock.unlock() }
        return stopped
    }

    /// Polls /health until the server reports ready (loading the 1.6GB model
    /// takes seconds; five minutes covers a cold, busy disk), then flips
    /// `healthy`.
    private func pollHealth() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            for _ in 0..<150 {
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
