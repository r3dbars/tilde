import Foundation

/// Thin blocking client for the Tilde "ghost brain" — the menu-bar app hosts
/// the llama/Gemma engine and serves completions over a local unix socket. One connection
/// per request (connect cost is microseconds locally; keeps the IME crash-proof
/// and stateless). Newline-delimited JSON: {"v":1,"context":...} → {"suggestion":...}.
///
/// Returns nil when the app isn't running or does not answer in time. The IME
/// stays silent and asks macOS to relaunch Tilde; there is no second model path.
enum GhostBrainClient {

    static let socketPath = NSString(
        string: "~/Library/Application Support/Tilde/ghost.sock"
    ).expandingTildeInPath

    /// Total time we are willing to wait for the brain, per request.
    private static let timeout = timeval(tv_sec: 0, tv_usec: 700_000)

    static func complete(context: String, app: String?) -> String? {
        var object: [String: Any] = ["v": 1, "context": context]
        if let app { object["app"] = app }
        guard let request = try? JSONSerialization.data(withJSONObject: object) else {
            return nil
        }

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return nil }
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
        guard connected == 0 else { return nil }

        var payload = request
        payload.append(0x0A) // newline delimiter
        let sent = payload.withUnsafeBytes { write(fd, $0.baseAddress, $0.count) }
        guard sent == payload.count else { return nil }

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
                    }
                } else {
                    // The brain ANSWERED — empty means it chose silence. Return ""
                    // (not nil) so callers respect the silence instead of treating
                    // it as "brain unreachable" and falling back to another model.
                    return suggestion.isEmpty ? (lastPartial ?? "") : suggestion
                }
            }
        }
        return lastPartial
    }
}
