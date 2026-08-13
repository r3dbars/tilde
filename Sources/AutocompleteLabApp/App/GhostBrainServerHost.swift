import AutocompleteLabCore
import Foundation
import Security

/// Owner-only unix socket between Tilde and its input method. Completion
/// context remains memory-only; explicit Personal History batches are routed
/// to the app-owned open research store in this explicitly opted-in build.
final class GhostBrainServerHost: @unchecked Sendable {
    static let socketPath = NSString(
        string: "~/Library/Application Support/Tilde/ghost.sock"
    ).expandingTildeInPath

    private let runtime: LlamaServerProcessHost
    private let engine: LlamaCompletionEngine
    private let personalHistory: any PersonalHistoryIngesting
    private let queue = DispatchQueue(label: "bar.r3d.tilde.ghost-brain-server")
    private var listenerFD: Int32 = -1
    private var lockFD: Int32 = -1
    private var source: DispatchSourceRead?
    private var ownsSocket = false

    init(runtime: LlamaServerProcessHost, personalHistory: any PersonalHistoryIngesting) {
        self.runtime = runtime
        self.engine = LlamaCompletionEngine(baseURL: runtime.baseURL)
        self.personalHistory = personalHistory
    }

    func start() -> Bool {
        queue.sync { bindAndListen() }
    }

    func stop() {
        queue.sync {
            source?.cancel()
            source = nil
            if listenerFD >= 0 { close(listenerFD) }
            listenerFD = -1
            if ownsSocket { unlink(Self.socketPath) }
            ownsSocket = false
            if lockFD >= 0 {
                flock(lockFD, LOCK_UN)
                close(lockFD)
            }
            lockFD = -1
        }
    }

    private func bindAndListen() -> Bool {
        let directory = (Self.socketPath as NSString).deletingLastPathComponent
        guard Self.secureSocketDirectory(directory) else {
            DiagnosticsLog.shared.record("ghost-socket-unavailable", metadata: ["reason": "directory"])
            return false
        }
        let lockPath = directory + "/runtime.lock"
        let lockFD = open(lockPath, O_CREAT | O_RDWR | O_NOFOLLOW, S_IRUSR | S_IWUSR)
        var lockInfo = stat()
        guard lockFD >= 0,
              fcntl(lockFD, F_SETFD, FD_CLOEXEC) == 0,
              fchmod(lockFD, S_IRUSR | S_IWUSR) == 0,
              fstat(lockFD, &lockInfo) == 0,
              lockInfo.st_mode & S_IFMT == S_IFREG,
              lockInfo.st_uid == getuid(),
              lockInfo.st_mode & 0o777 == 0o600,
              flock(lockFD, LOCK_EX | LOCK_NB) == 0 else {
            if lockFD >= 0 { close(lockFD) }
            DiagnosticsLog.shared.record("ghost-socket-unavailable", metadata: ["reason": "already-running"])
            return false
        }
        self.lockFD = lockFD
        unlink(Self.socketPath)

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0, fcntl(fd, F_SETFD, FD_CLOEXEC) == 0 else {
            if fd >= 0 { close(fd) }
            releaseLock()
            return false
        }
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let pathOK = Self.socketPath.withCString { path in
            withUnsafeMutableBytes(of: &address.sun_path) { bytes -> Bool in
                guard strlen(path) < bytes.count else { return false }
                bytes.baseAddress!.assumingMemoryBound(to: CChar.self)
                    .update(from: path, count: strlen(path) + 1)
                return true
            }
        }
        let size = socklen_t(MemoryLayout<sockaddr_un>.size)
        let bound = pathOK && withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, size) == 0 }
        }
        guard bound, listen(fd, 8) == 0, chmod(Self.socketPath, 0o600) == 0,
              Self.isOwnerOnlySocket(Self.socketPath) else {
            close(fd)
            unlink(Self.socketPath)
            releaseLock()
            return false
        }
        listenerFD = fd
        ownsSocket = true
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in self?.acceptOne() }
        source.resume()
        self.source = source
        return true
    }

    private func releaseLock() {
        if lockFD >= 0 {
            flock(lockFD, LOCK_UN)
            close(lockFD)
        }
        lockFD = -1
    }

    private func acceptOne() {
        let connection = accept(listenerFD, nil, nil)
        guard connection >= 0 else { return }
        guard fcntl(connection, F_SETFD, FD_CLOEXEC) == 0 else {
            close(connection)
            return
        }
        var timeout = timeval(tv_sec: 1, tv_usec: 0)
        setsockopt(connection, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(connection, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        var noSigpipe: Int32 = 1
        setsockopt(connection, SOL_SOCKET, SO_NOSIGPIPE, &noSigpipe, socklen_t(MemoryLayout<Int32>.size))

        Task.detached(priority: .userInitiated) { [weak self] in
            defer { close(connection) }
            guard let self else { return }
            guard Self.authorizedPeer(connection) else {
                _ = Self.write(.unavailable, to: connection)
                return
            }
            guard case let .success(request) = Self.readRequest(connection) else {
                _ = Self.write(.invalidRequest, to: connection)
                return
            }
            if case let .personalHistory(events) = request {
                let accepted = await self.personalHistory.ingest(events)
                _ = Self.write(accepted ? .recorded : .error, to: connection)
                return
            }
            guard case let .completion(completionRequest) = request else { return }
            guard await self.runtime.isReadyForCompletion() else {
                _ = Self.write(.unavailable, to: connection)
                return
            }

            let completion = Task {
                try await self.engine.suggestion(
                    textBeforeCursor: completionRequest.context,
                    appBundleIdentifier: completionRequest.app
                )
            }
            let disconnect = DispatchSource.makeReadSource(
                fileDescriptor: connection,
                queue: .global(qos: .userInitiated)
            )
            disconnect.setEventHandler {
                var byte: UInt8 = 0
                let count = recv(connection, &byte, 1, MSG_PEEK | MSG_DONTWAIT)
                if count == 0 || (count < 0 && errno != EAGAIN && errno != EWOULDBLOCK && errno != EINTR) {
                    completion.cancel()
                }
            }
            disconnect.resume()
            let result = await completion.result
            await withCheckedContinuation { continuation in
                disconnect.setCancelHandler { continuation.resume() }
                disconnect.cancel()
            }
            guard !completion.isCancelled else { return }

            let response: GhostBrainResponse
            let servedMetadata: [String: String]?
            switch result {
            case let .success(suggestion):
                let text = suggestion.map {
                    String($0.visibleText.drop(while: \Character.isWhitespace))
                } ?? ""
                response = .suggestion(text)
                servedMetadata = text.isEmpty ? nil : [
                    "app": completionRequest.app ?? "unknown",
                    "chars": String(text.count),
                ]
            case let .failure(error):
                self.runtime.reportCompletionFailure()
                response = (error as? URLError)?.code == .timedOut ? .timeout : .error
                servedMetadata = nil
            }
            if Self.write(response, to: connection), let servedMetadata {
                DiagnosticsLog.shared.record("suggestion-served", metadata: servedMetadata)
            }
        }
    }

    private enum ValidatedRequest {
        case completion(GhostBrainRequest)
        case personalHistory([PersonalHistoryEvent])
    }

    private static func readRequest(_ fd: Int32) -> Result<ValidatedRequest, Error> {
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4_096)
        while data.count < GhostBrainRequest.maximumWireBytes {
            let count = Darwin.read(
                fd,
                &buffer,
                min(buffer.count, GhostBrainRequest.maximumWireBytes - data.count)
            )
            guard count > 0 else { return .failure(WireError.invalid) }
            data.append(contentsOf: buffer[0..<count])
            guard let newline = data.firstIndex(of: 0x0A) else { continue }
            data = data.prefix(upTo: newline)
            guard let request = try? JSONDecoder().decode(GhostBrainRequest.self, from: data),
                  request.v == GhostBrainRequest.version else {
                return .failure(WireError.invalid)
            }
            if let events = request.personalHistoryEvents {
                guard request.context.isEmpty, request.app == nil,
                      PersonalHistoryEvent.validBatch(events) else {
                    return .failure(WireError.invalid)
                }
                return .success(.personalHistory(events))
            }
            guard !request.context.isEmpty,
                  request.context.count <= 3_000,
                  request.context.last?.isWhitespace == true,
                  (request.app?.count ?? 0) <= 512 else {
                return .failure(WireError.invalid)
            }
            return .success(.completion(request))
        }
        return .failure(WireError.invalid)
    }

    private enum WireError: Error { case invalid }

    private static func write(_ response: GhostBrainResponse, to fd: Int32) -> Bool {
        guard var data = try? JSONEncoder().encode(response) else { return false }
        data.append(0x0A)
        var offset = 0
        return data.withUnsafeBytes { bytes in
            while offset < bytes.count {
                let count = Darwin.write(fd, bytes.baseAddress!.advanced(by: offset), bytes.count - offset)
                guard count > 0 else {
                    if errno == EINTR { continue }
                    return false
                }
                offset += count
            }
            return true
        }
    }

    private static func authorizedPeer(_ fd: Int32) -> Bool {
        var uid: uid_t = 0
        var gid: gid_t = 0
        guard getpeereid(fd, &uid, &gid) == 0, uid == getuid() else { return false }
#if DEBUG
        if Bundle.main.bundleIdentifier != "bar.r3d.tilde" {
            return ProcessInfo.processInfo.environment["TILDE_ALLOW_UNSIGNED_LOCAL_PEER"] == "1"
        }
#else
        guard Bundle.main.bundleIdentifier == "bar.r3d.tilde" else { return false }
#endif
        var pid: pid_t = 0
        var length = socklen_t(MemoryLayout<pid_t>.size)
        guard getsockopt(fd, SOL_LOCAL, LOCAL_PEERPID, &pid, &length) == 0 else { return false }
        guard let peer = identity(pid: pid), peer.identifier == "bar.r3d.inputmethod.InlineGhost",
              let own = identity(pid: getpid()) else { return false }
#if DEBUG
        if let ownTeam = own.team, let peerTeam = peer.team {
            return ownTeam == peerTeam
        }
        return own.team == nil
            && peer.team == nil
            && ProcessInfo.processInfo.environment["TILDE_ALLOW_UNSIGNED_LOCAL_PEER"] == "1"
#else
        guard let ownTeam = own.team, let peerTeam = peer.team else { return false }
        return ownTeam == peerTeam
#endif
    }

    private static func identity(pid: pid_t) -> (identifier: String, team: String?)? {
        var code: SecCode?
        guard SecCodeCopyGuestWithAttributes(
            nil,
            [kSecGuestAttributePid: pid] as CFDictionary,
            [],
            &code
        ) == errSecSuccess, let code,
              SecCodeCheckValidity(code, [], nil) == errSecSuccess else { return nil }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess,
              let staticCode else { return nil }
        var information: CFDictionary?
        guard SecCodeCopySigningInformation(
            staticCode,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &information
        ) == errSecSuccess,
              let values = information as? [CFString: Any],
              let identifier = values[kSecCodeInfoIdentifier] as? String else { return nil }
        return (identifier, values[kSecCodeInfoTeamIdentifier] as? String)
    }

    private static func secureSocketDirectory(_ path: String) -> Bool {
        do {
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        } catch {
            return false
        }
        var info = stat()
        guard lstat(path, &info) == 0,
              info.st_mode & S_IFMT == S_IFDIR,
              info.st_uid == getuid(),
              chmod(path, 0o700) == 0,
              lstat(path, &info) == 0,
              info.st_mode & S_IFMT == S_IFDIR,
              info.st_uid == getuid(),
              info.st_mode & 0o777 == 0o700 else { return false }
        return true
    }

    private static func isOwnerOnlySocket(_ path: String) -> Bool {
        var info = stat()
        return lstat(path, &info) == 0
            && info.st_mode & S_IFMT == S_IFSOCK
            && info.st_uid == getuid()
            && info.st_mode & 0o777 == 0o600
    }

}
