import TildeCore
import Foundation

/// Keeps the current register's scaffold — and, when Screen Memory has
/// classified a live scene, the exact `scaffold + scene` prompt prefix — warm
/// in the helper's prompt cache.
///
/// Every prompt opens with a fixed scaffold (70–180 tokens) followed by an
/// optional Conversation/Reference scene block (up to ~750 tokens). Warming
/// that exact prefix ahead of time, while the writer is reading or switching
/// threads, turns a cold conversation switch into a warm KV cache hit
/// (cutting Qwen 3.5 9B first-keystroke TTFT from ~188 ms to ~45 ms on M5 Max).
///
/// Safety and slot discipline:
/// - verifies live helper ownership (`verifyHelperReady`) before sending;
/// - skips sensitive and prompt-injection scenes, re-checks `scenePrewarmGate`
///   right before sending, and drops held scene targets on `clearScene()`;
/// - reserves the single warm-up slot synchronously before spawning a `Task`,
///   cancels immediately on live completion activity, and re-checks if a newer
///   target arrived while busy.
final class ScaffoldPrewarmer: @unchecked Sendable {
    typealias Perform = @Sendable (URLRequest) async -> Bool

    private struct TargetPrefix: Equatable {
        let fingerprint: UInt64
        let prompt: String
        let kind: String
    }

    private let baseURL: URL
    private let apiKey: String?
    private let quietPeriod: TimeInterval
    private let now: @Sendable () -> TimeInterval
    private let verifyHelperReady: @Sendable () async -> Bool
    private let scenePrewarmGate: @Sendable () -> Bool
    private let customScaffoldProvider: (@Sendable (ContinuationRegister, String?) -> String?)?
    private let perform: Perform
    private let lock = NSLock()
    private var helperReady = false
    private var currentTarget: TargetPrefix?
    private var warmedFingerprint: UInt64?
    private var lastCompletionAt: TimeInterval = -.greatestFiniteMagnitude
    private var inflight: Task<Void, Never>?
    private var inflightToken: UUID?

    init(
        baseURL: URL,
        apiKey: String? = nil,
        quietPeriod: TimeInterval = 2.0,
        now: @escaping @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
        verifyHelperReady: (@Sendable () async -> Bool)? = nil,
        scenePrewarmGate: (@Sendable () -> Bool)? = nil,
        customScaffoldProvider: (@Sendable (ContinuationRegister, String?) -> String?)? = nil,
        perform: Perform? = nil
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.quietPeriod = quietPeriod
        self.now = now
        self.verifyHelperReady = verifyHelperReady ?? { true }
        self.scenePrewarmGate = scenePrewarmGate ?? { true }
        self.customScaffoldProvider = customScaffoldProvider
        self.perform = perform ?? Self.performOverLoopback
    }

    /// A helper just became ready. Its cache is empty whatever was warmed
    /// before, so the current target prefix is warmed again.
    func noteHelperReady() {
        lock.withLock {
            helperReady = true
            warmedFingerprint = nil
        }
        warmIfNeeded()
    }

    func noteHelperUnavailable() {
        let task: Task<Void, Never>? = lock.withLock {
            helperReady = false
            warmedFingerprint = nil
            inflightToken = nil
            defer { inflight = nil }
            return inflight
        }
        task?.cancel()
    }

    /// Drops any retained scene target and cancels an in-flight scene warm-up.
    /// Must be called whenever Screen Memory is toggled off or wiped so a
    /// helper restart cannot replay stale screen text.
    func clearScene() {
        let task: Task<Void, Never>? = lock.withLock {
            if currentTarget?.kind == "scene" {
                currentTarget = nil
                warmedFingerprint = nil
            }
            inflightToken = nil
            defer { inflight = nil }
            return inflight
        }
        task?.cancel()
    }

    /// Drops ALL retained targets (both personal-voice scaffolds and scenes)
    /// and cancels any in-flight warm-up. Called when Personal History is
    /// disabled, wiped, or an app is added to the exclusion list so personal
    /// sentences can never be replayed on helper restart.
    func clearAllTargets() {
        let task: Task<Void, Never>? = lock.withLock {
            currentTarget = nil
            warmedFingerprint = nil
            inflightToken = nil
            defer { inflight = nil }
            return inflight
        }
        task?.cancel()
    }

    /// The frontmost app changed. Its register decides which bare scaffold
    /// the next real request will need if no scene is captured yet.
    func noteFrontmostApp(bundleIdentifier: String?) {
        let register = ContinuationRegister.from(bundleIdentifier: bundleIdentifier)
        let customScaffold = customScaffoldProvider?(register, bundleIdentifier)
        let prompt = customScaffold ?? RawContinuationPrompt.scaffold(for: register)
        let target = TargetPrefix(
            fingerprint: InlineSuggestionTicket.fingerprint(prompt),
            prompt: prompt,
            kind: "scaffold"
        )
        lock.withLock {
            currentTarget = target
        }
        warmIfNeeded()
    }

    /// Screen Memory classified a fresh scene on window or field focus.
    /// Prewarms the exact byte-identical `scaffold + scene` prefix that the
    /// next real completion will open with. Sensitive and prompt-injection
    /// scenes are never prewarmed.
    func noteScene(
        _ scene: ScreenScene.Scene?,
        bundleIdentifier: String?,
        includesWindowTitle: Bool = false
    ) {
        guard let scene,
              scenePrewarmGate(),
              !SensitiveScenePolicy.isSensitive(scene: scene),
              SceneSuggestionPolicy.suppressionReason(scene: scene) != .promptInjection
        else { return }
        let register = ContinuationRegister.following(
            scene: scene,
            hostBundleIdentifier: bundleIdentifier
        )
        let customScaffold = customScaffoldProvider?(register, bundleIdentifier)
        let prefix = RawContinuationPrompt.prewarmPrefix(
            register: register,
            scene: scene,
            includesWindowTitle: includesWindowTitle,
            customScaffold: customScaffold
        )
        let scaffoldOnly = customScaffold ?? RawContinuationPrompt.scaffold(for: register)
        let kind = prefix == scaffoldOnly ? "scaffold" : "scene"
        let target = TargetPrefix(
            fingerprint: InlineSuggestionTicket.fingerprint(prefix),
            prompt: prefix,
            kind: kind
        )
        lock.withLock {
            currentTarget = target
        }
        warmIfNeeded()
    }

    /// A real completion is running. It owns the slot now. Cancel any in-flight
    /// warm-up immediately so the slot is free for the writer, while keeping
    /// the last warmed fingerprint as a fair guess so switching within the
    /// same register does not churn warm-ups.
    func noteCompletionActivity() {
        let task: Task<Void, Never>? = lock.withLock {
            lastCompletionAt = now()
            inflightToken = nil
            defer { inflight = nil }
            return inflight
        }
        task?.cancel()
    }

    /// Awaits any in-flight warm-up; tests only.
    func settle() async {
        while let task = lock.withLock({ inflight }) {
            await task.value
        }
    }

    private func warmIfNeeded() {
        let planned: (token: UUID, target: TargetPrefix, request: URLRequest)? = lock.withLock {
            guard helperReady,
                  inflightToken == nil,
                  let target = currentTarget,
                  target.fingerprint != warmedFingerprint,
                  now() - lastCompletionAt >= quietPeriod
            else { return nil }
            if target.kind == "scene", !scenePrewarmGate() {
                currentTarget = nil
                return nil
            }
            guard let request = try? warmRequest(for: target.prompt) else { return nil }
            let token = UUID()
            inflightToken = token
            return (token, target, request)
        }
        guard let planned else { return }
        let task = Task { [weak self] in
            guard let self else { return }
            guard await self.verifyHelperReady(), !Task.isCancelled else {
                self.lock.withLock {
                    if self.inflightToken == planned.token {
                        self.inflightToken = nil
                        self.inflight = nil
                    }
                }
                return
            }
            // Re-check both the live scene gate and our slot reservation AFTER
            // the async helper ownership check so a toggle-off or `clearScene()`
            // during verification fails closed before anything leaves loopback.
            let readyToSend: Bool = {
                guard !Task.isCancelled else { return false }
                if planned.target.kind == "scene", !self.scenePrewarmGate() { return false }
                return self.lock.withLock {
                    self.inflightToken == planned.token
                        && self.helperReady
                        && self.currentTarget?.fingerprint == planned.target.fingerprint
                }
            }()
            guard readyToSend else {
                let retryNewer: Bool = self.lock.withLock {
                    guard self.inflightToken == planned.token else { return false }
                    self.inflightToken = nil
                    self.inflight = nil
                    return self.helperReady
                        && self.currentTarget != nil
                        && self.currentTarget?.fingerprint != self.warmedFingerprint
                        && self.currentTarget?.fingerprint != planned.target.fingerprint
                }
                if retryNewer { self.warmIfNeeded() }
                return
            }
            let succeeded = await self.perform(planned.request)
            guard !Task.isCancelled else {
                self.lock.withLock {
                    if self.inflightToken == planned.token {
                        self.inflightToken = nil
                        self.inflight = nil
                    }
                }
                return
            }
            let shouldFollowUp: Bool = self.lock.withLock {
                guard self.inflightToken == planned.token else { return false }
                if succeeded, self.helperReady {
                    self.warmedFingerprint = planned.target.fingerprint
                }
                self.inflightToken = nil
                self.inflight = nil
                guard self.helperReady, let latest = self.currentTarget else { return false }
                // If a different replacement target arrived while we were busy,
                // follow up even if the superseded warm-up failed; never loop
                // tightly on the same failing target.
                return latest.fingerprint != self.warmedFingerprint
                    && latest.fingerprint != planned.target.fingerprint
            }
            DiagnosticsLog.shared.record(
                "scaffold-prewarm",
                metadata: [
                    "kind": planned.target.kind,
                    "outcome": succeeded ? "warmed" : "failed",
                ]
            )
            if shouldFollowUp {
                self.warmIfNeeded()
            }
        }
        let cancelledDuringPublish: Bool = lock.withLock {
            guard inflightToken == planned.token else { return true }
            inflight = task
            return false
        }
        if cancelledDuringPublish {
            task.cancel()
        }
    }

    private func warmRequest(for prompt: String) throws -> URLRequest {
        let body: [String: Any] = [
            "prompt": prompt,
            "n_predict": 1,
            "temperature": 0,
            "cache_prompt": true,
            "stream": false,
        ]
        var request = URLRequest(url: baseURL.appendingPathComponent("completion"))
        request.httpMethod = "POST"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        if let apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 5
        return request
    }

    private static func performOverLoopback(_ request: URLRequest) async -> Bool {
        guard let (_, response) = try? await LocalhostURLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse else { return false }
        return http.statusCode == 200
    }
}
