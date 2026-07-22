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

    /// Hardware-tiered model choice: machines under 24GB (base M1/M2 class) get
    /// the ~3GB E2B; everything else gets the E4B quality tier. Both are
    /// Google's official QAT GGUFs at pinned immutable revisions.
    struct ModelTier {
        let fileName: String
        let downloadURL: URL
        let expectedMinimumBytes: Int64

        static var current: ModelTier {
            var memsize: Int64 = 0
            var size = MemoryLayout<Int64>.size
            sysctlbyname("hw.memsize", &memsize, &size, nil, 0)
            if memsize > 0, memsize < 24 * 1024 * 1024 * 1024 {
                return ModelTier(
                    fileName: "gemma-4-E2B_q4_0-it.gguf",
                    downloadURL: URL(string: "https://huggingface.co/google/gemma-4-E2B-it-qat-q4_0-gguf/resolve/675cff42a74c774d6cb76f76d8eacb49b48c9b93/gemma-4-E2B_q4_0-it.gguf")!,
                    expectedMinimumBytes: 2_500_000_000
                )
            }
            return ModelTier(
                fileName: "gemma-4-E4B_q4_0-it.gguf",
                downloadURL: URL(string: "https://huggingface.co/google/gemma-4-E4B-it-qat-q4_0-gguf/resolve/4b4a2c1d584be7264f87aac328a1bc739ce81b6c/gemma-4-E4B_q4_0-it.gguf")!,
                expectedMinimumBytes: 4_000_000_000
            )
        }
    }

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
    private var restartCount = 0
    private let maximumRestarts = 3

    func start() {
        guard let binary = Self.binaryCandidates.first(where: {
            FileManager.default.isExecutableFile(atPath: $0)
        }) else {
            DiagnosticsLog.shared.record("llama-server-unavailable", metadata: ["reason": "binary-missing"])
            return
        }
        let tier = ModelTier.current
        let modelURL = Self.modelsDirectory.appendingPathComponent(tier.fileName)
        if !Self.isUsableModelFile(at: modelURL, minimumBytes: tier.expectedMinimumBytes) {
            Self.adoptHuggingFaceCacheIfPresent(tier: tier, destination: modelURL)
        }
        if Self.isUsableModelFile(at: modelURL, minimumBytes: tier.expectedMinimumBytes) {
            launch(binary: binary, modelPath: modelURL.path)
            return
        }
        downloadModel(tier: tier, to: modelURL) { [weak self] success in
            guard success, let self, !self.isStopped else { return }
            self.launch(binary: binary, modelPath: modelURL.path)
        }
    }

    static var modelsDirectory: URL {
        (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory()))
            .appendingPathComponent("SteadyType/Models/GGUF", isDirectory: true)
    }

    /// Dev machines that used `llama-server -hf` already hold the GGUF in the
    /// Hugging Face cache — hardlink it instead of re-downloading gigabytes.
    private static func adoptHuggingFaceCacheIfPresent(tier: ModelTier, destination: URL) {
        let repoDirectory = tier.downloadURL.pathComponents.dropFirst().prefix(2).joined(separator: "--")
        let hubDirectory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cache/huggingface/hub/models--\(repoDirectory)/snapshots", isDirectory: true)
        guard let snapshots = try? FileManager.default.contentsOfDirectory(atPath: hubDirectory.path) else { return }
        for snapshot in snapshots {
            let candidate = hubDirectory.appendingPathComponent(snapshot).appendingPathComponent(tier.fileName)
            guard isUsableModelFile(at: candidate.resolvingSymlinksInPath(), minimumBytes: tier.expectedMinimumBytes) else { continue }
            try? FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
            try? FileManager.default.linkItem(at: candidate.resolvingSymlinksInPath(), to: destination)
            if isUsableModelFile(at: destination, minimumBytes: tier.expectedMinimumBytes) {
                DiagnosticsLog.shared.record("llama-model-adopted-hf-cache", metadata: [:])
                return
            }
        }
    }

    private static func isUsableModelFile(at url: URL, minimumBytes: Int64) -> Bool {
        guard let size = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 else {
            return false
        }
        return size >= minimumBytes
    }

    /// First-run model download (2.5–4.5GB). Runs in the background; the engine
    /// simply stays unhealthy (MLX/fallbacks cover) until the file is complete.
    private func downloadModel(tier: ModelTier, to destination: URL, completion: @escaping @Sendable (Bool) -> Void) {
        DiagnosticsLog.shared.record("llama-model-download-start", metadata: ["file": tier.fileName])
        try? FileManager.default.createDirectory(at: Self.modelsDirectory, withIntermediateDirectories: true)
        let task = URLSession.shared.downloadTask(with: tier.downloadURL) { temporary, response, error in
            guard
                error == nil,
                let temporary,
                let http = response as? HTTPURLResponse, http.statusCode == 200
            else {
                DiagnosticsLog.shared.record("llama-model-download-failed", metadata: [:])
                completion(false)
                return
            }
            do {
                try? FileManager.default.removeItem(at: destination)
                try FileManager.default.moveItem(at: temporary, to: destination)
                DiagnosticsLog.shared.record("llama-model-download-complete", metadata: [:])
                completion(Self.isUsableModelFile(at: destination, minimumBytes: tier.expectedMinimumBytes))
            } catch {
                DiagnosticsLog.shared.record("llama-model-download-failed", metadata: ["reason": "move-failed"])
                completion(false)
            }
        }
        task.resume()
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

    private func launch(binary: String, modelPath: String) {
        let child = Process()
        child.executableURL = URL(fileURLWithPath: binary)
        child.arguments = [
            "-m", modelPath,
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
        lock.unlock()
        DiagnosticsLog.shared.record("llama-server-start", metadata: ["restart": String(restartCount)])
        pollHealth()
    }

    private func handleExit(binary: String, modelPath: String) {
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
            self.launch(binary: binary, modelPath: modelPath)
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
