import AutocompleteLabCore
import Foundation

/// Serves completions to the InlineGhostIME input method over a local unix socket.
///
/// The IME stays a thin, crash-proof pipe; this host answers its requests from the
/// app's already-warm MLX engine. Wire protocol is one newline-delimited JSON
/// object per connection: {"v":1,"context":"..."} → {"suggestion":"..."}.
///
/// Privacy: requests carry raw typed context. It is used only in-memory to build a
/// `CompletionRequest` and is never logged or persisted. The socket lives in the
/// user's own Application Support with owner-only permissions.
final class GhostBrainServerHost: @unchecked Sendable {

    static let socketPath = NSString(
        string: "~/Library/Application Support/SteadyType/ghost.sock"
    ).expandingTildeInPath

    private let engineProvider: @MainActor () -> any CompletionEngine
    private let queue = DispatchQueue(label: "bar.r3d.steadytype.ghost-brain-server")
    private var listenerFD: Int32 = -1
    private var acceptSource: DispatchSourceRead?

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
            unlink(Self.socketPath)
        }
    }

    // MARK: - Listener

    private func bindAndListen() {
        let directory = (Self.socketPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(
            atPath: directory, withIntermediateDirectories: true
        )
        unlink(Self.socketPath)

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

        Task.detached(priority: .userInitiated) { [weak self] in
            defer { close(connection) }
            guard let self, let context = Self.readContext(connection) else { return }
            let engine = await self.engineProvider()
            let request = CompletionRequest(textBeforeCursor: context)
            let suggestion = (try? await engine.suggestion(for: request))??.visibleText ?? ""
            Self.write(["suggestion": suggestion], to: connection)
        }
    }

    // MARK: - Wire format

    private static func readContext(_ fd: Int32) -> String? {
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while data.count < 65536 {
            let n = read(fd, &buffer, buffer.count)
            guard n > 0 else { break }
            data.append(contentsOf: buffer[0..<n])
            if buffer[0..<n].contains(0x0A) { break }
        }
        if let newline = data.firstIndex(of: 0x0A) {
            data = data.prefix(upTo: newline)
        }
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let context = object["context"] as? String,
            !context.isEmpty
        else { return nil }
        return context
    }

    private static func write(_ object: [String: String], to fd: Int32) {
        guard var payload = try? JSONSerialization.data(withJSONObject: object) else { return }
        payload.append(0x0A)
        _ = payload.withUnsafeBytes { raw in
            Darwin.write(fd, raw.baseAddress, raw.count)
        }
    }
}
