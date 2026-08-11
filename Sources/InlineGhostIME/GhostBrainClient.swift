import AutocompleteLabCore
import Foundation
import Security

/// One cancellable, final-only request to Tilde's owner-only unix socket.
enum GhostBrainClient {
    static let socketPath = NSString(
        string: "~/Library/Application Support/Tilde/ghost.sock"
    ).expandingTildeInPath

    private static let timeoutNanoseconds: UInt64 = 2_000_000_000
    private static let worker = DispatchQueue(label: "bar.r3d.tilde.ghost-client", qos: .userInitiated)

    static func complete(context: String, app: String?) async -> GhostBrainResponse {
        guard let connection = Connection(path: socketPath) else { return .unavailable }
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                worker.async {
                    continuation.resume(returning: connection.run(context: context, app: app))
                }
            }
        } onCancel: {
            connection.cancel()
        }
    }

    static func decodeResponse(_ data: Data) -> GhostBrainResponse {
        (try? JSONDecoder().decode(GhostBrainResponse.self, from: data)) ?? .error
    }

    private final class Connection: @unchecked Sendable {
        private let fd: Int32
        private let deadline: UInt64
        private let lock = NSLock()
        private var cancelled = false
        private var closed = false

        init?(path: String) {
            var info = stat()
            guard lstat(path, &info) == 0,
                  info.st_mode & S_IFMT == S_IFSOCK,
                  info.st_uid == getuid(),
                  info.st_mode & 0o077 == 0 else { return nil }
            fd = socket(AF_UNIX, SOCK_STREAM, 0)
            guard fd >= 0 else { return nil }
            var noSigpipe: Int32 = 1
            setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noSigpipe, socklen_t(MemoryLayout<Int32>.size))
            deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
        }

        func cancel() {
            lock.lock()
            cancelled = true
            if !closed { shutdown(fd, SHUT_RDWR) }
            lock.unlock()
        }

        func run(context: String, app: String?) -> GhostBrainResponse {
            defer { finish() }
            guard !isCancelled, connect(), !isCancelled, verifyPeer() else { return .unavailable }
            guard let request = try? JSONEncoder().encode(GhostBrainRequest(context: context, app: app)),
                  write(request + [0x0A]) else { return timedOut ? .timeout : .unavailable }
            guard let line = readLine(maximumBytes: 8_192) else {
                return timedOut ? .timeout : .unavailable
            }
            return GhostBrainClient.decodeResponse(line)
        }

        private func connect() -> Bool {
            _ = fcntl(fd, F_SETFL, O_NONBLOCK)
            var address = sockaddr_un()
            address.sun_family = sa_family_t(AF_UNIX)
            let pathOK = GhostBrainClient.socketPath.withCString { path in
                withUnsafeMutableBytes(of: &address.sun_path) { bytes -> Bool in
                    guard strlen(path) < bytes.count else { return false }
                    bytes.baseAddress!.assumingMemoryBound(to: CChar.self)
                        .update(from: path, count: strlen(path) + 1)
                    return true
                }
            }
            guard pathOK else { return false }
            let size = socklen_t(MemoryLayout<sockaddr_un>.size)
            let result = withUnsafePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.connect(fd, $0, size)
                }
            }
            if result == 0 { return true }
            guard errno == EINPROGRESS, wait(for: Int16(POLLOUT)) else { return false }
            var error: Int32 = 0
            var length = socklen_t(MemoryLayout<Int32>.size)
            return getsockopt(fd, SOL_SOCKET, SO_ERROR, &error, &length) == 0 && error == 0
        }

        private func verifyPeer() -> Bool {
            var uid: uid_t = 0
            var gid: gid_t = 0
            guard getpeereid(fd, &uid, &gid) == 0, uid == getuid() else { return false }
#if DEBUG
            guard Bundle.main.bundleIdentifier == "bar.r3d.inputmethod.InlineGhost" else { return true }
#else
            guard Bundle.main.bundleIdentifier == "bar.r3d.inputmethod.InlineGhost" else { return false }
#endif
            var pid: pid_t = 0
            var length = socklen_t(MemoryLayout<pid_t>.size)
            guard getsockopt(fd, SOL_LOCAL, LOCAL_PEERPID, &pid, &length) == 0 else { return false }
            guard let peer = Self.identity(pid: pid), peer.identifier == "bar.r3d.tilde",
                  let own = Self.identity(pid: getpid()) else { return false }
            return own.team.map { peer.team == $0 } ?? true
        }

        private static func identity(pid: pid_t) -> (identifier: String, team: String?)? {
            var code: SecCode?
            let attributes = [kSecGuestAttributePid: pid] as CFDictionary
            guard SecCodeCopyGuestWithAttributes(nil, attributes, [], &code) == errSecSuccess,
                  let code,
                  SecCodeCheckValidity(code, [], nil) == errSecSuccess else { return nil }
            var staticCode: SecStaticCode?
            guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess,
                  let staticCode else { return nil }
            var information: CFDictionary?
            guard SecCodeCopySigningInformation(staticCode, [], &information) == errSecSuccess,
                  let values = information as? [CFString: Any],
                  let identifier = values[kSecCodeInfoIdentifier] as? String else { return nil }
            return (identifier, values[kSecCodeInfoTeamIdentifier] as? String)
        }

        private func write(_ data: Data) -> Bool {
            var offset = 0
            return data.withUnsafeBytes { bytes in
                while offset < bytes.count {
                    guard wait(for: Int16(POLLOUT)) else { return false }
                    let count = Darwin.write(fd, bytes.baseAddress!.advanced(by: offset), bytes.count - offset)
                    guard count > 0 else {
                        if errno == EINTR || errno == EAGAIN { continue }
                        return false
                    }
                    offset += count
                }
                return true
            }
        }

        private func readLine(maximumBytes: Int) -> Data? {
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 2_048)
            while data.count < maximumBytes {
                guard wait(for: Int16(POLLIN)) else { return nil }
                let count = Darwin.read(fd, &buffer, min(buffer.count, maximumBytes - data.count))
                guard count > 0 else {
                    if count < 0, errno == EINTR || errno == EAGAIN { continue }
                    return nil
                }
                data.append(contentsOf: buffer[0..<count])
                if let newline = data.firstIndex(of: 0x0A) {
                    return data.prefix(upTo: newline)
                }
            }
            return nil
        }

        private func wait(for events: Int16) -> Bool {
            while !timedOut {
                if isCancelled { return false }
                let now = DispatchTime.now().uptimeNanoseconds
                guard now < deadline else { return false }
                let milliseconds = Int32(max(1, (deadline - now) / 1_000_000))
                var descriptor = pollfd(fd: fd, events: events, revents: 0)
                let result = poll(&descriptor, 1, milliseconds)
                if result > 0 {
                    return descriptor.revents & events != 0
                }
                if result < 0, errno == EINTR { continue }
                return false
            }
            return false
        }

        private var timedOut: Bool {
            DispatchTime.now().uptimeNanoseconds >= deadline
        }

        private var isCancelled: Bool {
            lock.lock()
            defer { lock.unlock() }
            return cancelled
        }

        private func finish() {
            lock.lock()
            if !closed {
                closed = true
                close(fd)
            }
            lock.unlock()
        }
    }
}
