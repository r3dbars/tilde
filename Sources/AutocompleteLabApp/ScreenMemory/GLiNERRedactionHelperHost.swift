import Foundation

/// One freeform-PII span the model layer found, in the SAME coordinate
/// space `RedactionService` already redacted structured secrets in (i.e.
/// offsets are into the rules-cleaned text, not the original capture).
/// Offsets are Unicode-scalar counts — Python's own string indexing unit,
/// which is what the helper process's `start`/`end` fields report — so
/// `RedactionService` converts them via `String.UnicodeScalarView`, never
/// UTF-8 byte or UTF-16 offsets.
struct GLiNERSpan: Sendable, Equatable {
    let unicodeScalarStart: Int
    let unicodeScalarEnd: Int
    let label: String
    let score: Double
}

/// The model layer's boundary as `RedactionService` sees it. `nil` means
/// "unavailable" — no model loaded, a crashed helper, a malformed reply, a
/// timeout — and every one of those MUST be treated identically by the
/// caller: fail-closed, not "no PII found". Only an explicit, successfully
/// decoded (possibly empty) span array counts as "the model looked and
/// found nothing".
protocol GLiNERSpanDetecting: Sendable {
    func detectSpans(in text: String) async -> [GLiNERSpan]?
}

/// Owns the app's one GLiNER redaction helper child process — the model
/// layer's ONLY way to see screen text, over stdin/stdout pipes with no
/// listening socket at all (narrower than `LlamaServerProcessHost`'s
/// HTTP+TCP: this helper doesn't even bind a port). See
/// `script/redaction_helper.py` for the protocol this speaks and the full
/// in-process-vs-helper-process rationale.
///
/// Lifecycle is deliberately simpler than `LlamaServerProcessHost`: no
/// health polling loop, no restart-with-backoff policy. This helper is
/// idle almost all the time (redaction runs once per screen capture, not
/// per keystroke) — if it is missing, fails to launch, or ever errors on a
/// request, `detectSpans` reports unavailable for that call AND every
/// later call in this launch (the process is torn down, not retried);
/// `RedactionService` in turn drops the capture. A future launch of the
/// app gets a fresh attempt. This matches the covenant's fail-closed
/// requirement more directly than a restart-and-hope loop would: a
/// redaction feature that keeps quietly retrying a broken model process
/// is a worse failure mode than one that simply stops capturing until
/// restarted.
final class GLiNERRedactionHelperHost: GLiNERSpanDetecting, @unchecked Sendable {
    struct Assets: Sendable, Equatable {
        let interpreter: String
        let script: String
        let model: String
        let tokenizerDir: String
    }

    /// Bounded wait for a reply to one request. Redaction happens on the
    /// same cadence as screen capture (seconds, not keystrokes) so a few
    /// seconds of budget here is cheap; it exists only to guarantee a
    /// hung/wedged helper cannot hang a capture forever.
    static let requestTimeout: TimeInterval = 5.0
    static let readyTimeout: TimeInterval = 15.0

    private let lifecycle = DispatchQueue(label: "bar.r3d.tilde.redaction-helper-lifecycle")
    private let assetResolver: @Sendable () -> Assets?
    private let now: @Sendable () -> Date

    private var process: Process?
    private var channel: LinePipeChannel?
    private var broken = false
    private var launchAttempted = false

    init(
        assetResolver: @escaping @Sendable () -> Assets? = GLiNERRedactionHelperHost.resolveAssets,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.assetResolver = assetResolver
        self.now = now
    }

    func detectSpans(in text: String) async -> [GLiNERSpan]? {
        guard let channel = await ensureLaunched() else { return nil }
        let request = RedactionHelperRequest(text: text, labels: nil, threshold: nil)
        guard let requestLine = try? JSONEncoder().encode(request) else {
            markBroken()
            return nil
        }
        guard await channel.writeLine(requestLine) else {
            markBroken()
            DiagnosticsLog.shared.record("redaction-helper-unavailable", metadata: ["reason": "write-failed"])
            return nil
        }
        guard let replyLine = await channel.readLine(deadline: now().addingTimeInterval(Self.requestTimeout)) else {
            markBroken()
            DiagnosticsLog.shared.record("redaction-helper-unavailable", metadata: ["reason": "timeout"])
            return nil
        }
        guard let reply = try? JSONDecoder().decode(RedactionHelperResponse.self, from: replyLine),
              reply.ok == true, let spans = reply.spans else {
            markBroken()
            DiagnosticsLog.shared.record("redaction-helper-unavailable", metadata: ["reason": "inference-error"])
            return nil
        }
        return spans.map {
            GLiNERSpan(unicodeScalarStart: $0.start, unicodeScalarEnd: $0.end, label: $0.label, score: $0.score)
        }
    }

    /// Lazily launches the child on first use and reuses it afterward.
    /// Returns nil (never launches, or already broken) whenever the
    /// caller must treat the model layer as unavailable.
    private func ensureLaunched() async -> LinePipeChannel? {
        await withCheckedContinuation { continuation in
            lifecycle.async { [self] in
                if broken { continuation.resume(returning: nil); return }
                if let channel { continuation.resume(returning: channel); return }
                guard !launchAttempted else { continuation.resume(returning: nil); return }
                launchAttempted = true
                guard let assets = assetResolver() else {
                    broken = true
                    DiagnosticsLog.shared.record("redaction-helper-unavailable", metadata: ["reason": "assets-missing"])
                    continuation.resume(returning: nil)
                    return
                }
                guard let launched = Self.launch(assets) else {
                    broken = true
                    DiagnosticsLog.shared.record("redaction-helper-unavailable", metadata: ["reason": "launch-failed"])
                    continuation.resume(returning: nil)
                    return
                }
                self.process = launched.process
                self.channel = launched.channel
                DiagnosticsLog.shared.record("redaction-helper-start", metadata: [:])
                Task {
                    let ok = await launched.channel.awaitReady(deadline: self.now().addingTimeInterval(Self.readyTimeout))
                    if !ok {
                        self.markBroken()
                        DiagnosticsLog.shared.record("redaction-helper-unavailable", metadata: ["reason": "ready-timeout"])
                        continuation.resume(returning: nil)
                    } else {
                        continuation.resume(returning: launched.channel)
                    }
                }
            }
        }
    }

    private func markBroken() {
        lifecycle.async { [self] in
            guard !broken else { return }
            broken = true
            let child = process
            process = nil
            channel = nil
            DiagnosticsLog.shared.record("redaction-helper-exit", metadata: [:])
            LlamaServerProcessHost.shutDownNow(child)
        }
    }

    func stop() {
        lifecycle.sync { [self] in
            let child = process
            process = nil
            channel = nil
            broken = true
            LlamaServerProcessHost.shutDownNow(child)
        }
    }

    private static func launch(_ assets: Assets) -> (process: Process, channel: LinePipeChannel)? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: assets.interpreter)
        process.arguments = [
            assets.script,
            "--model", assets.model,
            "--tokenizer-dir", assets.tokenizerDir,
        ]
        let stdin = Pipe()
        let stdout = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return nil
        }
        let channel = LinePipeChannel(input: stdin.fileHandleForWriting, output: stdout.fileHandleForReading)
        return (process, channel)
    }

    /// Production asset resolution. Screen Memory redaction is not yet a
    /// bundled/pinned input to `package_app.sh` (tracked follow-up — see PR
    /// 3b body); until that lands there is no sealed production path, only
    /// the DEBUG-only dev override below, mirroring
    /// `LlamaServerProcessHost.resolveAssets`'s own `TILDE_DEV_*` pattern
    /// before its model/helper were sealed into a release bundle.
    static func resolveAssets() -> Assets? {
#if DEBUG
        let environment = ProcessInfo.processInfo.environment
        guard let interpreter = environment["TILDE_DEV_REDACTION_HELPER_PYTHON"],
              let script = environment["TILDE_DEV_REDACTION_HELPER_SCRIPT"],
              let model = environment["TILDE_DEV_REDACTION_MODEL"],
              let tokenizerDir = environment["TILDE_DEV_REDACTION_TOKENIZER_DIR"],
              FileManager.default.isExecutableFile(atPath: interpreter),
              FileManager.default.fileExists(atPath: script),
              FileManager.default.fileExists(atPath: model),
              FileManager.default.fileExists(atPath: tokenizerDir) else { return nil }
        return Assets(interpreter: interpreter, script: script, model: model, tokenizerDir: tokenizerDir)
#else
        return nil
#endif
    }
}

private struct RedactionHelperRequest: Encodable {
    let text: String
    let labels: [String]?
    let threshold: Double?
}

private struct RedactionHelperResponse: Decodable {
    struct Span: Decodable {
        let start: Int
        let end: Int
        let label: String
        let score: Double
    }

    // Both fields are optional because this one type decodes TWO distinct
    // line shapes: the one-time startup handshake (`{"ready": true}` or
    // `{"ready": false, "reason": "..."}`, no `ok` key at all) and every
    // subsequent per-request reply (`{"ok": true, "spans": [...]}` or
    // `{"ok": false, "reason": "..."}`, no `ready` key at all). Requiring
    // `ok` unconditionally would fail to decode the handshake line and
    // silently fail the whole launch closed before a single request ever
    // went out.
    let ok: Bool?
    let spans: [Span]?
    let ready: Bool?
}

/// Non-blocking line-delimited JSON channel over a child process's
/// stdin/stdout pipes. Reads are event-driven (`readabilityHandler`, no
/// thread ever blocks on a `read()` syscall) so a wedged helper cannot pin
/// a thread; every wait has an explicit deadline via `DispatchQueue.asyncAfter`.
final class LinePipeChannel: @unchecked Sendable {
    /// A pending `readLine`/`awaitReady` waiter. `fired` guards against the
    /// checked continuation being resumed twice — once by an arriving line
    /// and once by its own timeout racing it — which is the one invariant
    /// this whole type exists to protect, since `CheckedContinuation.resume`
    /// called twice is a crash, not a logic error.
    private final class Waiter: @unchecked Sendable {
        // Only ever read/written from `LinePipeChannel.queue` — every call
        // site into `fire`/`fired` is already inside a `queue.async` block,
        // so this class's single mutable property never needs its own lock.
        var fired = false
        let resume: @Sendable (Data?) -> Void
        init(resume: @escaping @Sendable (Data?) -> Void) { self.resume = resume }

        func fire(_ value: Data?) {
            guard !fired else { return }
            fired = true
            resume(value)
        }
    }

    private let input: FileHandle
    private let output: FileHandle
    private let queue = DispatchQueue(label: "bar.r3d.tilde.redaction-helper-io")
    private var buffer = Data()
    private var pendingLines: [Data] = []
    private var waiters: [Waiter] = []
    private var readyLine: Data?
    private var readyWaiters: [Waiter] = []
    private var closed = false

    init(input: FileHandle, output: FileHandle) {
        self.input = input
        self.output = output
        output.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            guard let self else { return }
            self.queue.async { self.handleChunk(chunk) }
        }
    }

    private func handleChunk(_ chunk: Data) {
        guard !closed else { return }
        guard !chunk.isEmpty else {
            closed = true
            failAllWaiters()
            return
        }
        buffer.append(chunk)
        while let newlineIndex = buffer.firstIndex(of: 0x0A) {
            let line = buffer[buffer.startIndex..<newlineIndex]
            buffer.removeSubrange(buffer.startIndex...newlineIndex)
            if readyLine == nil {
                readyLine = line
                let resumers = readyWaiters
                readyWaiters = []
                resumers.forEach { $0.fire(line) }
            } else {
                pendingLines.append(line)
                deliverPendingIfPossible()
            }
        }
    }

    private func deliverPendingIfPossible() {
        guard !pendingLines.isEmpty, !waiters.isEmpty else { return }
        let line = pendingLines.removeFirst()
        let waiter = waiters.removeFirst()
        waiter.fire(line)
    }

    private func failAllWaiters() {
        let allWaiters = waiters
        waiters = []
        allWaiters.forEach { $0.fire(nil) }
        let readyAll = readyWaiters
        readyWaiters = []
        readyAll.forEach { $0.fire(nil) }
    }

    func awaitReady(deadline: Date) async -> Bool {
        let line = await withCheckedContinuation { (continuation: CheckedContinuation<Data?, Never>) in
            queue.async { [self] in
                if let readyLine {
                    continuation.resume(returning: readyLine)
                    return
                }
                let waiter = Waiter { continuation.resume(returning: $0) }
                readyWaiters.append(waiter)
                scheduleTimeout(deadline: deadline) { [weak self] in
                    guard let self else { return }
                    self.queue.async {
                        self.readyWaiters.removeAll { $0 === waiter }
                        waiter.fire(nil)
                    }
                }
            }
        }
        guard let line, let decoded = try? JSONDecoder().decode(RedactionHelperResponse.self, from: line) else {
            return false
        }
        return decoded.ready == true
    }

    func writeLine(_ data: Data) async -> Bool {
        await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            queue.async { [self] in
                guard !closed else { continuation.resume(returning: false); return }
                do {
                    try input.write(contentsOf: data)
                    try input.write(contentsOf: Data([0x0A]))
                    continuation.resume(returning: true)
                } catch {
                    continuation.resume(returning: false)
                }
            }
        }
    }

    func readLine(deadline: Date) async -> Data? {
        await withCheckedContinuation { (continuation: CheckedContinuation<Data?, Never>) in
            queue.async { [self] in
                if !pendingLines.isEmpty {
                    continuation.resume(returning: pendingLines.removeFirst())
                    return
                }
                if closed {
                    continuation.resume(returning: nil)
                    return
                }
                let waiter = Waiter { continuation.resume(returning: $0) }
                waiters.append(waiter)
                scheduleTimeout(deadline: deadline) { [weak self] in
                    guard let self else { return }
                    self.queue.async {
                        self.waiters.removeAll { $0 === waiter }
                        waiter.fire(nil)
                    }
                }
            }
        }
    }

    private func scheduleTimeout(deadline: Date, _ fire: @escaping @Sendable () -> Void) {
        let delay = max(0, deadline.timeIntervalSinceNow)
        queue.asyncAfter(deadline: .now() + delay, execute: fire)
    }
}
