import Foundation
import os.log

/// Thin blocking client for the SteadyType "ghost brain" — the menu-bar app hosts
/// the MLX engine and serves completions over a local unix socket. One connection
/// per request (connect cost is microseconds locally; keeps the IME crash-proof
/// and stateless). Newline-delimited JSON: {"v":1,"context":...} → {"suggestion":...}.
///
/// Returns nil when the app isn't running / doesn't answer in time — callers fall
/// back to the on-device Apple model, then the tiny predictor. Suggestions never
/// just vanish because the brain is away.
enum GhostBrainClient {

    static let socketPath = NSString(
        string: "~/Library/Application Support/SteadyType/ghost.sock"
    ).expandingTildeInPath

    /// Total time we are willing to wait for the brain, per request.
    private static let timeout = timeval(tv_sec: 0, tv_usec: 700_000)

    // MARK: - Reachability observability (redacted: event names only, never text)

    /// Why the last attempt got no answer. The demotion to the Apple fallback
    /// used to be completely silent — the only symptom was chatbot-style
    /// suggestions. Now every reachability TRANSITION logs one redacted line
    /// (visible in Console.app under subsystem bar.r3d.steadytype.ime) and the
    /// input menu shows the current state.
    enum UnreachableReason: String {
        case socketMissing = "socket-missing"
        case connectFailed = "connect-failed"
        case requestFailed = "request-failed"
        case noResponse = "no-response"
    }

    private static let log = Logger(subsystem: "bar.r3d.steadytype.ime", category: "brain")
    private static let stateLock = NSLock()
    private static var lastReason: UnreachableReason?
    private static var everReached = false

    /// One line for the input menu: is the personal model answering, or has the
    /// keyboard demoted to the Apple fallback?
    static func menuStatusLine() -> String {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard let reason = lastReason else {
            return everReached ? "Brain: connected" : "Brain: not contacted yet"
        }
        return "Brain: unreachable (\(reason.rawValue)) — Apple fallback"
    }

    private static func noteReachable() {
        stateLock.lock()
        let wasDown = lastReason != nil
        lastReason = nil
        everReached = true
        stateLock.unlock()
        if wasDown { log.info("brain reachable again — personal model resumed") }
    }

    private static func noteUnreachable(_ reason: UnreachableReason) -> String? {
        stateLock.lock()
        let changed = lastReason != reason
        lastReason = reason
        stateLock.unlock()
        if changed {
            log.error("brain unreachable (\(reason.rawValue, privacy: .public)) — demoting to Apple fallback")
        }
        return nil
    }

    /// Streams a completion: `onPartial` fires for each partial suggestion as the
    /// model generates (first words near time-to-first-token); the return value is
    /// the final suggestion (or the last partial if the stream times out).
    static func complete(
        context: String,
        app: String?,
        field: String?,
        onPartial: ((String) -> Void)? = nil
    ) -> String? {
        var object: [String: Any] = ["v": 1, "context": context]
        // App + field identity let the brain's prompt KV cache recognize
        // consecutive keystrokes in the same field (the big latency win).
        if let app { object["app"] = app }
        if let field { object["field"] = field }
        guard let request = try? JSONSerialization.data(withJSONObject: object) else {
            return nil
        }

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return noteUnreachable(.connectFailed) }
        defer { close(fd) }

        var tv = timeout
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let ok = socketPath.withCString { path -> Bool in
            withUnsafeMutableBytes(of: &addr.sun_path) { raw in
                let capacity = raw.count
                guard strlen(path) < capacity else { return false }
                raw.baseAddress!.assumingMemoryBound(to: CChar.self).update(from: path, count: strlen(path) + 1)
                return true
            }
        }
        guard ok else { return nil }

        let size = socklen_t(MemoryLayout<sockaddr_un>.size)
        let connected = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, size) }
        }
        guard connected == 0 else {
            // The socket file vanishing is THE signature of the historical bug
            // (a second app instance tearing down the shared path) — name it.
            let fileExists = FileManager.default.fileExists(atPath: socketPath)
            return noteUnreachable(fileExists ? .connectFailed : .socketMissing)
        }

        var payload = request
        payload.append(0x0A) // newline delimiter
        let sent = payload.withUnsafeBytes { write(fd, $0.baseAddress, $0.count) }
        guard sent == payload.count else { return noteUnreachable(.requestFailed) }

        // Read newline-delimited JSON lines: partials as they generate, then the
        // final (no "partial" flag). On timeout/EOF, the last partial stands.
        var pending = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        var lastPartial: String?
        while pending.count < 262_144 {
            let n = read(fd, &buffer, buffer.count)
            guard n > 0 else { break }
            pending.append(contentsOf: buffer[0..<n])
            while let newline = pending.firstIndex(of: 0x0A) {
                let line = pending.prefix(upTo: newline)
                pending = Data(pending.suffix(from: pending.index(after: newline)))
                guard
                    let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                    let suggestion = object["suggestion"] as? String
                else { continue }
                if (object["partial"] as? Bool) == true {
                    if !suggestion.isEmpty {
                        lastPartial = suggestion
                        onPartial?(suggestion)
                    }
                } else {
                    // The brain ANSWERED — empty means it chose silence. Return ""
                    // (not nil) so callers respect the silence instead of treating
                    // it as "brain unreachable" and falling back to another model.
                    noteReachable()
                    return suggestion.isEmpty ? (lastPartial ?? "") : suggestion
                }
            }
        }
        if lastPartial == nil {
            return noteUnreachable(.noResponse)
        }
        noteReachable()
        return lastPartial
    }
}
