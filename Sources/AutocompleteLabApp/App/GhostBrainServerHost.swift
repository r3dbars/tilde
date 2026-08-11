import AutocompleteLabCore
import Foundation

/// Serves completions to the InlineGhostIME input method over a local unix socket.
///
/// The IME stays a thin, crash-proof pipe; this host answers its requests from the
/// app's already-warm llama/Gemma engine. Wire protocol: one newline-delimited JSON request
/// {"v":1,"context":"...","app":?} → a STREAM of newline-delimited JSON
/// responses: zero or more {"suggestion":"...","partial":true} as the model
/// generates, then a final {"suggestion":"..."} and close. Partials put the first
/// words on screen near time-to-first-token instead of time-to-last-token.
///
/// Privacy: requests carry raw typed context. It is used only in-memory to build a
/// `CompletionRequest` and is never logged or persisted. The socket lives in the
/// user's own Application Support with owner-only permissions.
final class GhostBrainServerHost: @unchecked Sendable {

    static let socketPath = NSString(
        string: "~/Library/Application Support/Tilde/ghost.sock"
    ).expandingTildeInPath

    private let engineProvider: @MainActor () -> any CompletionEngine
    private let queue = DispatchQueue(label: "bar.r3d.tilde.ghost-brain-server")
    private var listenerFD: Int32 = -1
    private var acceptSource: DispatchSourceRead?
    // Only the instance that actually bound the socket may unlink it. A
    // duplicate instance bowing out runs the same stop() on its way to
    // terminate — without this flag it unlinked the LIVE socket of the
    // healthy first instance, silently cutting the keyboard off from the brain.
    private var ownsSocketFile = false

    init(engineProvider: @escaping @MainActor () -> any CompletionEngine) {
        self.engineProvider = engineProvider
    }

    func start() {
        queue.async { [weak self] in self?.bindAndListen() }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            self.acceptSource?.cancel()
            self.acceptSource = nil
            if self.listenerFD >= 0 {
                close(self.listenerFD)
                self.listenerFD = -1
            }
            if self.ownsSocketFile {
                unlink(Self.socketPath)
                self.ownsSocketFile = false
            }
        }
    }

    /// True when a process is actively accepting on the socket path. A stale
    /// file from a crashed instance refuses the connection; a live server
    /// accepts it (we close immediately — no request is sent).
    private static func socketIsAlive() -> Bool {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathOK = socketPath.withCString { path -> Bool in
            withUnsafeMutableBytes(of: &addr.sun_path) { raw in
                guard strlen(path) < raw.count else { return false }
                raw.baseAddress!.assumingMemoryBound(to: CChar.self)
                    .update(from: path, count: strlen(path) + 1)
                return true
            }
        }
        guard pathOK else { return false }
        let size = socklen_t(MemoryLayout<sockaddr_un>.size)
        return withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, size) == 0 }
        }
    }

    // MARK: - Listener

    private func bindAndListen() {
        let directory = (Self.socketPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(
            atPath: directory, withIntermediateDirectories: true
        )
        // Never steal a live socket: if something is answering on the path,
        // another brain instance is serving the keyboard — leave it alone.
        // Only a stale file (crash leftover; connect refused) gets replaced.
        if Self.socketIsAlive() {
            DiagnosticsLog.shared.record("ghost-socket-live-abort", metadata: [:])
            return
        }
        unlink(Self.socketPath)

        // A peer can vanish between accept and write (the IME drops connections
        // mid-stream whenever typing resumes). Without this, writing to the dead
        // socket raises SIGPIPE and silently kills the whole app — no crash
        // report. Ignore it process-wide; such writes then fail with EPIPE.
        signal(SIGPIPE, SIG_IGN)

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathOK = Self.socketPath.withCString { path -> Bool in
            withUnsafeMutableBytes(of: &addr.sun_path) { raw in
                guard strlen(path) < raw.count else { return false }
                raw.baseAddress!.assumingMemoryBound(to: CChar.self)
                    .update(from: path, count: strlen(path) + 1)
                return true
            }
        }
        let size = socklen_t(MemoryLayout<sockaddr_un>.size)
        let bound = pathOK && withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, size) == 0 }
        }
        guard bound, listen(fd, 8) == 0 else {
            close(fd)
            return
        }
        chmod(Self.socketPath, 0o600)
        listenerFD = fd
        ownsSocketFile = true

        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in self?.acceptOne() }
        source.resume()
        acceptSource = source
    }

    private func acceptOne() {
        guard listenerFD >= 0 else { return }
        let connection = accept(listenerFD, nil, nil)
        guard connection >= 0 else { return }

        var tv = timeval(tv_sec: 2, tv_usec: 0)
        setsockopt(connection, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(connection, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        var noSigpipe: Int32 = 1
        setsockopt(connection, SOL_SOCKET, SO_NOSIGPIPE, &noSigpipe, socklen_t(MemoryLayout<Int32>.size))

        Task.detached(priority: .userInitiated) { [weak self] in
            defer { close(connection) }
            guard let self, let payload = Self.readPayload(connection) else { return }
            // Config probe: the tuning-sweep driver asks "what are you running?"
            // and verifies the expected override is live before quizzing. Echoes
            // launch-time knobs only — never any typed content.
            if payload.configProbe {
                let env = ProcessInfo.processInfo.environment
                Self.write([
                    "scaffold_chat": env["TILDE_SCAFFOLD_CHAT_FILE"] ?? "builtin",
                    "token_budget": env["TILDE_TOKEN_BUDGET"] ?? "default",
                    "temperature": env["TILDE_TEMPERATURE"] ?? "0",
                    "model_path": env["TILDE_MODEL_PATH"] ?? "default",
                    "confidence": env["TILDE_CONFIDENCE"] ?? "0",
                    "max_context_chars": env["TILDE_MAX_CONTEXT_CHARS"] ?? "3000",
                    "top_p": env["TILDE_TOP_P"] ?? "default",
                    "top_k": env["TILDE_TOP_K"] ?? "default",
                    "min_p": env["TILDE_MIN_P"] ?? "default",
                    "repeat_penalty": env["TILDE_REPEAT_PENALTY"] ?? "default",
                ], to: connection)
                return
            }
            let engine = await self.engineProvider()
            // The keyboard owns mid-word completion. Reject malformed or stale
            // socket requests instead of creating a hidden second model path.
            guard payload.context.last?.isWhitespace == true else {
                Self.write(["suggestion": ""], to: connection)
                return
            }
            let request = CompletionRequest(
                textBeforeCursor: payload.context,
                appBundleIdentifier: payload.app,
                mode: .phraseContinuation
            )
            // Partial callbacks can fire from generation threads; serialize socket
            // writes so JSON lines never interleave mid-message.
            let writeLock = NSLock()
            let send: @Sendable ([String: Any]) -> Void = { object in
                writeLock.lock()
                defer { writeLock.unlock() }
                Self.write(object, to: connection)
            }
            let final = try? await engine.suggestion(for: request) { partial in
                let text = Self.keyboardText(partial)
                guard !text.isEmpty else { return }
                send(["suggestion": text, "partial": true])
            }
            send(["suggestion": final.map(Self.keyboardText) ?? ""])
            // The end-to-end proof lane (script/real_app_smoke.sh) waits for
            // this event: a real keystroke travelled keyboard → socket →
            // engine → back. "Served", deliberately not "presented" — the IME
            // may still drop a stale answer, and display isn't observable from
            // this process. Bundle id and shape only — never content.
            if let final, !Self.keyboardText(final).isEmpty {
                DiagnosticsLog.shared.record("suggestion-served", metadata: [
                    "app": payload.app ?? "unknown",
                    "chars": String(Self.keyboardText(final).count)
                ])
            }
        }
    }

    // MARK: - Wire format

    private struct RequestPayload {
        let context: String
        let app: String?
        let configProbe: Bool
    }

    private static func readPayload(_ fd: Int32) -> RequestPayload? {
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while data.count < 65536 {
            let n = read(fd, &buffer, buffer.count)
            guard n > 0 else { break }
            data.append(contentsOf: buffer[0..<n])
            if buffer[0..<n].contains(0x0A) { break }
            // Defensive framing: the protocol is newline-terminated JSON, but a
            // client that forgets the terminator (several eval harnesses did)
            // otherwise stalls here until the socket timeout — measured as a
            // phantom 2s "latency" that sent us bug-hunting. Serve as soon as
            // the payload parses complete.
            if (try? JSONSerialization.jsonObject(with: data)) != nil { break }
        }
        if let newline = data.firstIndex(of: 0x0A) {
            data = data.prefix(upTo: newline)
        }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        if (object["config"] as? Bool) == true {
            return RequestPayload(context: "", app: nil, configProbe: true)
        }
        guard let context = object["context"] as? String
        else { return nil }
        return RequestPayload(
            context: context,
            app: object["app"] as? String,
            configProbe: false
        )
    }

    private static func write(_ object: [String: Any], to fd: Int32) {
        guard var payload = try? JSONSerialization.data(withJSONObject: object) else { return }
        payload.append(0x0A)
        _ = payload.withUnsafeBytes { raw in
            Darwin.write(fd, raw.baseAddress, raw.count)
        }
    }

    /// Completion suggestions include the separator needed by overlay insertion.
    /// IMKit marked text is already placed after the typed boundary.
    private static func keyboardText(_ suggestion: CompletionSuggestion) -> String {
        String(suggestion.visibleText.drop(while: \Character.isWhitespace))
    }
}
