import AutocompleteLabCore
import Foundation

/// Serves completions to the InlineGhostIME input method over a local unix socket.
///
/// The IME stays a thin, crash-proof pipe; this host answers its requests from the
/// app's already-warm MLX engine. Wire protocol: one newline-delimited JSON request
/// {"v":1,"context":"...","app":?,"field":?} → a STREAM of newline-delimited JSON
/// responses: zero or more {"suggestion":"...","partial":true} as the model
/// generates, then a final {"suggestion":"..."} and close. Partials put the first
/// words on screen near time-to-first-token instead of time-to-last-token.
///
/// Privacy: requests carry raw typed context. It is used only in-memory to build a
/// `CompletionRequest` and is never logged or persisted. The socket lives in the
/// user's own Application Support with owner-only permissions.
final class GhostBrainServerHost: @unchecked Sendable {

    static let socketPath = NSString(
        string: "~/Library/Application Support/SteadyType/ghost.sock"
    ).expandingTildeInPath

    private let engineProvider: @MainActor () -> any CompletionEngine
    private let screenContextResolver: @Sendable (_ app: String?, _ field: String?, _ textBeforeCursor: String) -> VisiblePageContext?
    private let queue = DispatchQueue(label: "bar.r3d.steadytype.ghost-brain-server")
    private var listenerFD: Int32 = -1
    private var acceptSource: DispatchSourceRead?
    /// Identity (inode) of the socket file THIS process bound. Teardown may only
    /// unlink the file while it still has this identity — a transient second
    /// instance must never remove the primary's live socket.
    private var boundFileID: UInt64?
    private var socketWatchSource: DispatchSourceFileSystemObject?

    init(
        engineProvider: @escaping @MainActor () -> any CompletionEngine,
        screenContextResolver: @escaping @Sendable (_ app: String?, _ field: String?, _ textBeforeCursor: String) -> VisiblePageContext? = { _, _, _ in nil }
    ) {
        self.engineProvider = engineProvider
        self.screenContextResolver = screenContextResolver
    }

    func start() {
        queue.async { [weak self] in self?.bindAndListen() }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            self.tearDownListener()
            if GhostSocketLifecyclePolicy.shouldUnlinkOnStop(
                didBindSocket: self.boundFileID != nil,
                boundFileID: self.boundFileID,
                currentFileID: Self.fileID(atPath: Self.socketPath)
            ) {
                unlink(Self.socketPath)
            }
            self.boundFileID = nil
        }
    }

    /// For the status menu: this process is listening and the socket file the
    /// keyboard connects to is present.
    var isServingKeyboard: Bool {
        queue.sync {
            listenerFD >= 0 && FileManager.default.fileExists(atPath: Self.socketPath)
        }
    }

    // MARK: - Listener

    private func bindAndListen() {
        let directory = (Self.socketPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(
            atPath: directory, withIntermediateDirectories: true
        )
        if FileManager.default.fileExists(atPath: Self.socketPath) {
            let action = GhostSocketLifecyclePolicy.bindAction(
                liveServerAnswersProbe: Self.probeConnect(Self.socketPath)
            )
            guard action == .replaceStaleSocket else {
                // A live server (an older primary instance) already answers on
                // this path — we are the duplicate; never steal its socket.
                DiagnosticsLog.shared.record("ghost-socket-already-served", metadata: [:])
                return
            }
            unlink(Self.socketPath)
        }

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
        boundFileID = Self.fileID(atPath: Self.socketPath)

        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in self?.acceptOne() }
        source.resume()
        acceptSource = source
        watchSocketFile()
    }

    private func tearDownListener() {
        socketWatchSource?.cancel()
        socketWatchSource = nil
        acceptSource?.cancel()
        acceptSource = nil
        if listenerFD >= 0 {
            close(listenerFD)
            listenerFD = -1
        }
    }

    /// Self-heal: if anything removes the socket file out from under us (the
    /// historical offender was a transient second instance's teardown), new
    /// keyboard connections silently fail even though this process is fine.
    /// A socket file cannot be open(2)ed for a vnode watch, so watch the parent
    /// directory and re-bind the moment our file's identity is gone.
    private func watchSocketFile() {
        let directory = (Self.socketPath as NSString).deletingLastPathComponent
        let fd = open(directory, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd, eventMask: .write, queue: queue
        )
        source.setEventHandler { [weak self] in self?.socketDirectoryChanged() }
        source.setCancelHandler { close(fd) }
        source.resume()
        socketWatchSource = source
    }

    private func socketDirectoryChanged() {
        guard let bound = boundFileID,
              Self.fileID(atPath: Self.socketPath) != bound else { return }
        DiagnosticsLog.shared.record("ghost-socket-vanished-rebinding", metadata: [:])
        tearDownListener()
        boundFileID = nil
        bindAndListen()
    }

    /// A file at the path only blocks binding if a server still answers on it;
    /// a leftover from a dead process refuses the connection immediately.
    private static func probeConnect(_ path: String) -> Bool {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        var tv = timeval(tv_sec: 0, tv_usec: 250_000)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathOK = path.withCString { cPath -> Bool in
            withUnsafeMutableBytes(of: &addr.sun_path) { raw in
                guard strlen(cPath) < raw.count else { return false }
                raw.baseAddress!.assumingMemoryBound(to: CChar.self)
                    .update(from: cPath, count: strlen(cPath) + 1)
                return true
            }
        }
        guard pathOK else { return false }
        let size = socklen_t(MemoryLayout<sockaddr_un>.size)
        return withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, size) == 0 }
        }
    }

    private static func fileID(atPath path: String) -> UInt64? {
        var status = stat()
        guard stat(path, &status) == 0 else { return nil }
        return UInt64(status.st_ino)
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
            guard let self, let payload = Self.readPayload(connection) else { return }
            let engine = await self.engineProvider()
            // Mid-word contexts want the engine's word-completion mode; word
            // boundaries want phrase continuation. App + field identity let the
            // prompt KV cache recognize consecutive keystrokes in the same field.
            let midWord = payload.context.unicodeScalars.last.map(CharacterSet.alphanumerics.contains) ?? false
            let pageContext = self.screenContextResolver(payload.app, payload.field, payload.context)
            let request = CompletionRequest(
                textBeforeCursor: payload.context,
                appBundleIdentifier: payload.app,
                fieldIdentityDescription: payload.field,
                visiblePageContext: pageContext,
                mode: midWord ? .wordCompletion : .phraseContinuation
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
                let text = partial.visibleText
                guard !text.isEmpty else { return }
                send(["suggestion": text, "partial": true])
            }
            // "page" reports whether screen context was attached — observability
            // for the capture pipeline (content itself never leaves the process).
            send(["suggestion": final?.visibleText ?? "", "page": pageContext != nil])
        }
    }

    // MARK: - Wire format

    private struct RequestPayload {
        let context: String
        let app: String?
        let field: String?
    }

    private static func readPayload(_ fd: Int32) -> RequestPayload? {
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
        return RequestPayload(
            context: context,
            app: object["app"] as? String,
            field: object["field"] as? String
        )
    }

    private static func write(_ object: [String: Any], to fd: Int32) {
        guard var payload = try? JSONSerialization.data(withJSONObject: object) else { return }
        payload.append(0x0A)
        _ = payload.withUnsafeBytes { raw in
            Darwin.write(fd, raw.baseAddress, raw.count)
        }
    }
}
