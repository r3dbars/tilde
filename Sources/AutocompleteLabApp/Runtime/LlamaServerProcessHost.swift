import Foundation

/// Owns the app's one llama-server child, health state, and restart policy.
final class LlamaServerProcessHost: @unchecked Sendable {
    static let port = 17872
    static let modelMinimumBytes: Int64 = 1_500_000_000

    var baseURL: URL { URL(string: "http://127.0.0.1:\(Self.port)")! }
    var isHealthy: Bool { synchronized { healthy } }

    private struct Assets: Sendable {
        let binary: String
        let model: String
    }

    private let lock = NSLock()
    private var process: Process?
    private var healthTask: Task<Void, Never>?
    private var healthy = false
    private var stopped = false
    private var launchedAt = Date.distantPast
    private var restartPolicy = LlamaRestartPolicy()

    func start() {
        guard let assets = Self.resolveAssets() else {
            DiagnosticsLog.shared.record("llama-server-unavailable", metadata: ["reason": "assets-missing"])
            return
        }
        launch(assets)
    }

    func stop() {
        lock.lock()
        stopped = true
        healthy = false
        let child = process
        process = nil
        let health = healthTask
        healthTask = nil
        lock.unlock()
        health?.cancel()
        child?.terminate()
    }

    /// A transport/protocol failure means the owned helper is not serving a
    /// usable model. Restart that exact child once; concurrent failures see the
    /// cleared health bit and do nothing.
    func reportCompletionFailure() {
        let child: Process? = synchronized {
            guard healthy, let process else { return nil }
            healthy = false
            return process
        }
        child?.terminate()
    }

    /// A packaged app always uses its exact embedded pair. Only a build without
    /// embedded assets may use the two explicit development overrides.
    private static func resolveAssets() -> Assets? {
        let binary = Bundle.main.bundlePath + "/Contents/Helpers/llama-server"
        let model = Bundle.main.bundlePath + "/Contents/Resources/bundled-model.gguf"
        let hasPackagedAsset = FileManager.default.fileExists(atPath: binary)
            || FileManager.default.fileExists(atPath: model)
        if hasPackagedAsset {
            guard FileManager.default.isExecutableFile(atPath: binary), usableModel(model) else { return nil }
            return Assets(binary: binary, model: model)
        }
        let environment = ProcessInfo.processInfo.environment
        guard let devBinary = environment["TILDE_DEV_LLAMA_SERVER"],
              let devModel = environment["TILDE_DEV_MODEL_PATH"],
              FileManager.default.isExecutableFile(atPath: devBinary),
              usableModel(devModel) else { return nil }
        return Assets(binary: devBinary, model: devModel)
    }

    private static func usableModel(_ path: String) -> Bool {
        guard let size = try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int64 else {
            return false
        }
        return size >= modelMinimumBytes
    }

    private func launch(_ assets: Assets) {
        lock.lock()
        guard !stopped, process == nil else {
            lock.unlock()
            return
        }
        lock.unlock()
        guard Self.preparePort(for: assets.binary) else {
            DiagnosticsLog.shared.record("llama-server-unavailable", metadata: ["reason": "port-in-use"])
            scheduleRestart(assets, wasHealthy: false, uptime: 0)
            return
        }

        let child = Process()
        child.executableURL = URL(fileURLWithPath: assets.binary)
        child.arguments = [
            "-m", assets.model,
            "--host", "127.0.0.1",
            "--port", String(Self.port),
            "-c", "4096",
            "--swa-full",
            "--cache-reuse", "256",
        ]
        child.standardOutput = FileHandle.nullDevice
        child.standardError = FileHandle.nullDevice
        child.terminationHandler = { [weak self, weak child] _ in
            guard let child else { return }
            self?.handleExit(child, assets: assets)
        }
        lock.lock()
        process = child
        healthy = false
        launchedAt = Date()
        lock.unlock()
        do {
            try child.run()
        } catch {
            lock.lock()
            if process === child { process = nil }
            lock.unlock()
            DiagnosticsLog.shared.record("llama-server-unavailable", metadata: ["reason": "launch-failed"])
            scheduleRestart(assets, wasHealthy: false, uptime: 0)
            return
        }

        lock.lock()
        guard !stopped else {
            lock.unlock()
            child.terminate()
            return
        }
        lock.unlock()
        DiagnosticsLog.shared.record("llama-server-start", metadata: [:])
        pollHealth(of: child)
    }

    private func handleExit(_ child: Process, assets: Assets) {
        lock.lock()
        guard process === child else {
            lock.unlock()
            return
        }
        let wasHealthy = healthy
        let uptime = Date().timeIntervalSince(launchedAt)
        process = nil
        healthy = false
        healthTask?.cancel()
        healthTask = nil
        let shouldRestart = !stopped
        lock.unlock()
        DiagnosticsLog.shared.record("llama-server-exit", metadata: ["willRestart": String(shouldRestart)])
        if shouldRestart { scheduleRestart(assets, wasHealthy: wasHealthy, uptime: uptime) }
    }

    private func scheduleRestart(_ assets: Assets, wasHealthy: Bool, uptime: TimeInterval) {
        lock.lock()
        guard !stopped else {
            lock.unlock()
            return
        }
        let delay = restartPolicy.delay(wasHealthy: wasHealthy, uptime: uptime)
        lock.unlock()
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.launch(assets)
        }
    }

    private func pollHealth(of child: Process) {
        let task = Task { [weak self, weak child] in
            guard let self, let child else { return }
            for _ in 0..<45 {
                guard !Task.isCancelled, self.isCurrent(child) else { return }
                if await self.probeHealth(of: child) {
                    self.synchronized {
                        if self.process === child { self.healthy = true }
                    }
                    DiagnosticsLog.shared.record("llama-server-healthy", metadata: [:])
                    return
                }
                try? await Task.sleep(for: .seconds(2))
            }
            guard self.isCurrent(child) else { return }
            DiagnosticsLog.shared.record("llama-server-unavailable", metadata: ["reason": "health-timeout"])
            child.terminate()
        }
        lock.lock()
        healthTask?.cancel()
        healthTask = task
        lock.unlock()
    }

    private func isCurrent(_ child: Process) -> Bool {
        synchronized { !stopped && process === child }
    }

    private func probeHealth(of child: Process) async -> Bool {
        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(Self.port)/health")!)
        request.timeoutInterval = 2
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200,
              String(data: data, encoding: .utf8)?.contains("ok") == true else { return false }
        return Self.listenerBelongs(to: child, port: Self.port)
    }

    private static func listenerBelongs(to child: Process, port: Int) -> Bool {
        guard child.isRunning else { return false }
        return command(
            "/usr/sbin/lsof",
            [
                "-nP", "-a", "-p", String(child.processIdentifier),
                "-iTCP:\(port)", "-sTCP:LISTEN", "-t",
            ]
        ).trimmingCharacters(in: .whitespacesAndNewlines) == String(child.processIdentifier)
    }

    /// Reap only a re-parented helper from this exact app asset. Any other
    /// listener is left untouched and keeps this runtime unavailable.
    private static func preparePort(for binary: String) -> Bool {
        let listeners = command(
            "/usr/sbin/lsof",
            ["-nP", "-iTCP:\(port)", "-sTCP:LISTEN", "-t"]
        ).split(whereSeparator: \Character.isNewline).compactMap { Int32($0) }
        guard !listeners.isEmpty else { return true }
        guard listeners.count == 1,
              let pid = listeners.first,
              processPath(pid: pid) == URL(fileURLWithPath: binary).standardizedFileURL.path,
              command("/bin/ps", ["-o", "ppid=", "-p", String(pid)])
                .trimmingCharacters(in: .whitespacesAndNewlines) == "1" else { return false }
        kill(pid, SIGTERM)
        usleep(200_000)
        return command(
            "/usr/sbin/lsof",
            ["-nP", "-iTCP:\(port)", "-sTCP:LISTEN", "-t"]
        ).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func processPath(pid: Int32) -> String? {
        var buffer = [CChar](repeating: 0, count: 4_096)
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        let bytes = buffer.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) }
        return URL(fileURLWithPath: String(decoding: bytes, as: UTF8.self)).standardizedFileURL.path
    }

    private static func command(_ executable: String, _ arguments: [String]) -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = arguments
        let output = Pipe()
        task.standardOutput = output
        task.standardError = FileHandle.nullDevice
        do { try task.run() } catch { return "" }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func synchronized<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}
