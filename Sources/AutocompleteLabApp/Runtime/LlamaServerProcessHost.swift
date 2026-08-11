import Foundation
import Security

/// Owns the app's one llama-server child, health state, and restart policy.
final class LlamaServerProcessHost: @unchecked Sendable {
    static let port = 17872
    static let modelMinimumBytes: Int64 = 1_500_000_000

    var baseURL: URL { URL(string: "http://127.0.0.1:\(Self.port)")! }
    var isHealthy: Bool { lifecycle.sync { healthy } }

    private struct Assets: Sendable {
        let binary: String
        let model: String
    }

    private let lifecycle = DispatchQueue(label: "bar.r3d.tilde.llama-lifecycle")
    private let preparation = DispatchQueue(label: "bar.r3d.tilde.llama-preparation", qos: .utility)
    private var process: Process?
    private var healthTask: Task<Void, Never>?
    private var healthy = false
    private var stopped = false
    private var preparing = false
    private var launchedAt = Date.distantPast
    private var restartPolicy = LlamaRestartPolicy()

    func start() {
        preparation.async { [weak self] in
            guard let self else { return }
            guard let assets = Self.resolveAssets() else {
                DiagnosticsLog.shared.record("llama-server-unavailable", metadata: ["reason": "assets-missing"])
                return
            }
            lifecycle.async { self.prepareLaunch(assets) }
        }
    }

    func stop() {
        let child: Process? = lifecycle.sync {
            stopped = true
            preparing = false
            healthy = false
            healthTask?.cancel()
            healthTask = nil
            defer { process = nil }
            return process
        }
        Self.shutDown(child)
    }

    /// A transport/protocol failure means the owned helper is not serving a
    /// usable model. Concurrent failures see the cleared health bit and stop.
    func reportCompletionFailure() {
        lifecycle.async { [weak self] in
            guard let self, healthy, let process else { return }
            healthy = false
            Self.shutDown(process)
        }
    }

    /// Recheck ownership immediately before a completion request. Cached
    /// health alone cannot prove the current listener is still our child.
    func isReadyForCompletion() async -> Bool {
        guard let child = lifecycle.sync(execute: { healthy ? process : nil }) else { return false }
        let ownsListener = await Task.detached(priority: .userInitiated) {
            Self.listenerBelongs(to: child, port: Self.port)
        }.value
        return ownsListener && lifecycle.sync { healthy && process === child && !stopped }
    }

    /// A packaged app always uses its exact embedded pair and must pass its
    /// resource-seal check first. Development overrides are only considered
    /// when neither embedded asset exists.
    private static func resolveAssets() -> Assets? {
        let binary = Bundle.main.bundlePath + "/Contents/Helpers/llama-server"
        let model = Bundle.main.bundlePath + "/Contents/Resources/bundled-model.gguf"
        let hasPackagedAsset = FileManager.default.fileExists(atPath: binary)
            || FileManager.default.fileExists(atPath: model)
        if hasPackagedAsset {
            guard validCurrentBundleSeal(),
                  FileManager.default.isExecutableFile(atPath: binary),
                  usableModel(model) else { return nil }
            return Assets(binary: binary, model: model)
        }
        let environment = ProcessInfo.processInfo.environment
        guard let devBinary = environment["TILDE_DEV_LLAMA_SERVER"],
              let devModel = environment["TILDE_DEV_MODEL_PATH"],
              FileManager.default.isExecutableFile(atPath: devBinary),
              usableModel(devModel) else { return nil }
        return Assets(binary: devBinary, model: devModel)
    }

    private static func validCurrentBundleSeal() -> Bool {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(Bundle.main.bundleURL as CFURL, [], &code) == errSecSuccess,
              let code else { return false }
        let flags = SecCSFlags(
            rawValue: kSecCSCheckAllArchitectures | kSecCSCheckNestedCode | kSecCSStrictValidate
        )
        return SecStaticCodeCheckValidity(code, flags, nil) == errSecSuccess
    }

    private static func usableModel(_ path: String) -> Bool {
        guard let size = try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int64 else {
            return false
        }
        return size >= modelMinimumBytes
    }

    private func prepareLaunch(_ assets: Assets) {
        guard !stopped, process == nil, !preparing else { return }
        preparing = true
        preparation.async { [weak self] in
            guard let self else { return }
            let ready = Self.preparePort(for: assets.binary)
            self.lifecycle.async { [weak self] in
                self?.finishPreparation(assets, ready: ready)
            }
        }
    }

    private func finishPreparation(_ assets: Assets, ready: Bool) {
        preparing = false
        guard !stopped, process == nil else { return }
        guard ready else {
            DiagnosticsLog.shared.record("llama-server-unavailable", metadata: ["reason": "port-in-use"])
            scheduleRestart(assets, wasHealthy: false, uptime: 0)
            return
        }
        launchPrepared(assets)
    }

    /// Runs only on `lifecycle`, so stop/restart cannot race child creation.
    /// The child is published only after Process.run() succeeds.
    private func launchPrepared(_ assets: Assets) {
        guard !stopped, process == nil else { return }
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
            guard let self, let child else { return }
            lifecycle.async { self.handleExit(child, assets: assets) }
        }
        do {
            try child.run()
        } catch {
            DiagnosticsLog.shared.record("llama-server-unavailable", metadata: ["reason": "launch-failed"])
            scheduleRestart(assets, wasHealthy: false, uptime: 0)
            return
        }
        process = child
        healthy = false
        launchedAt = Date()
        DiagnosticsLog.shared.record("llama-server-start", metadata: [:])
        pollHealth(of: child)
    }

    private func handleExit(_ child: Process, assets: Assets) {
        guard process === child else { return }
        let wasHealthy = healthy
        let uptime = Date().timeIntervalSince(launchedAt)
        process = nil
        healthy = false
        healthTask?.cancel()
        healthTask = nil
        let shouldRestart = !stopped
        DiagnosticsLog.shared.record("llama-server-exit", metadata: ["willRestart": String(shouldRestart)])
        if shouldRestart { scheduleRestart(assets, wasHealthy: wasHealthy, uptime: uptime) }
    }

    private func scheduleRestart(_ assets: Assets, wasHealthy: Bool, uptime: TimeInterval) {
        guard !stopped else { return }
        let delay = restartPolicy.delay(wasHealthy: wasHealthy, uptime: uptime)
        lifecycle.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.prepareLaunch(assets)
        }
    }

    private func pollHealth(of child: Process) {
        healthTask?.cancel()
        let task = Task { [weak self, weak child] in
            guard let self, let child else { return }
            for _ in 0..<45 {
                guard !Task.isCancelled, self.isCurrent(child) else { return }
                if await self.probeHealth(of: child) {
                    let transitioned = self.lifecycle.sync { () -> Bool in
                        guard !self.stopped, !self.healthy, self.process === child else { return false }
                        self.healthy = true
                        return true
                    }
                    if transitioned {
                        DiagnosticsLog.shared.record("llama-server-healthy", metadata: [:])
                    }
                    return
                }
                try? await Task.sleep(for: .seconds(2))
            }
            guard self.isCurrent(child) else { return }
            DiagnosticsLog.shared.record("llama-server-unavailable", metadata: ["reason": "health-timeout"])
            Self.shutDown(child)
        }
        healthTask = task
    }

    private func isCurrent(_ child: Process) -> Bool {
        lifecycle.sync { !stopped && process === child }
    }

    private func probeHealth(of child: Process) async -> Bool {
        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(Self.port)/health")!)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        request.timeoutInterval = 2
        guard let (data, response) = try? await LocalhostURLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200,
              String(data: data, encoding: .utf8)?.contains("ok") == true else { return false }
        return await Task.detached(priority: .utility) {
            Self.listenerBelongs(to: child, port: Self.port)
        }.value
    }

    private static func listenerBelongs(to child: Process, port: Int) -> Bool {
        guard child.isRunning,
              let output = command(
                  "/usr/sbin/lsof",
                  ["-nP", "-a", "-p", String(child.processIdentifier),
                   "-iTCP:\(port)", "-sTCP:LISTEN", "-t"]
              ) else { return false }
        return output.trimmingCharacters(in: .whitespacesAndNewlines) == String(child.processIdentifier)
    }

    /// Reap only a re-parented helper from this exact app asset. Any other
    /// listener is left untouched and keeps this runtime unavailable.
    private static func preparePort(for binary: String) -> Bool {
        guard let output = command(
            "/usr/sbin/lsof", ["-nP", "-iTCP:\(port)", "-sTCP:LISTEN", "-t"]
        ) else { return false }
        let listeners = output.split(whereSeparator: \Character.isNewline).compactMap { Int32($0) }
        guard !listeners.isEmpty else { return true }
        guard listeners.count == 1,
              let pid = listeners.first,
              processPath(pid: pid) == URL(fileURLWithPath: binary).standardizedFileURL.path,
              command("/bin/ps", ["-o", "ppid=", "-p", String(pid)])?
                .trimmingCharacters(in: .whitespacesAndNewlines) == "1" else { return false }
        kill(pid, SIGTERM)
        usleep(200_000)
        guard let remaining = command(
            "/usr/sbin/lsof", ["-nP", "-iTCP:\(port)", "-sTCP:LISTEN", "-t"]
        ) else { return false }
        return remaining.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func processPath(pid: Int32) -> String? {
        var buffer = [CChar](repeating: 0, count: 4_096)
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        let bytes = buffer.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) }
        return URL(fileURLWithPath: String(decoding: bytes, as: UTF8.self)).standardizedFileURL.path
    }

    /// Shell probes are never run on the main thread and are fail-closed on a
    /// short deadline. A stuck probe is terminated, then killed if necessary.
    private static func command(
        _ executable: String,
        _ arguments: [String],
        timeout: TimeInterval = 1
    ) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = arguments
        let output = Pipe()
        task.standardOutput = output
        task.standardError = FileHandle.nullDevice
        let exited = DispatchSemaphore(value: 0)
        task.terminationHandler = { _ in exited.signal() }
        do { try task.run() } catch { return nil }
        if exited.wait(timeout: .now() + timeout) == .timedOut {
            task.terminate()
            if exited.wait(timeout: .now() + 0.2) == .timedOut {
                kill(task.processIdentifier, SIGKILL)
                guard exited.wait(timeout: .now() + 0.2) == .success else { return nil }
            }
        }
        return String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
    }

    /// TERM first, then KILL the same launched child after a bounded grace
    /// period. The caller never waits for child shutdown.
    private static func shutDown(_ child: Process?) {
        guard let child else { return }
        DispatchQueue.global(qos: .utility).async {
            guard child.isRunning else { return }
            child.terminate()
            let deadline = Date().addingTimeInterval(1)
            while child.isRunning, Date() < deadline { usleep(20_000) }
            if child.isRunning { kill(child.processIdentifier, SIGKILL) }
        }
    }
}
