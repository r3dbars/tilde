import Foundation

/// One row of `ps -axo pid=,ppid=,args=`, split the same way
/// `script/check_runtime_network_egress.py`'s `ProcessRow` does: macOS `ps`
/// does not quote paths, so the executable is recovered by locating a known
/// binary-name marker rather than by naive whitespace splitting.
struct ReplayEvalProcessRow: Equatable, Sendable {
    let pid: Int32
    let ppid: Int32
    let executablePath: String
    let arguments: [String]
}

protocol ReplayEvalProcessInspecting: Sendable {
    func processTable() -> [ReplayEvalProcessRow]?
    /// True when `pid` owns exactly one open listener and it is the IPv4
    /// loopback address on `port` — no other sockets, no wildcard bind.
    func ownsExactLoopbackListener(pid: Int32, port: Int) -> Bool
}

enum ReplayEvalOwnershipFailure: String, Error, Equatable, Sendable {
    case processTableUnavailable = "process-table-unavailable"
    case noRunningApp = "no-running-app"
    case ambiguousApp = "ambiguous-app"
    case noServerChild = "no-server-child"
    case ambiguousServerChild = "ambiguous-server-child"
    case wrongServerBinary = "wrong-server-binary"
    case wrongPort = "wrong-port"
    case notLoopbackOnly = "not-loopback-only"
    case listenerNotOwned = "listener-not-owned"
}

struct ReplayEvalOwnedServer: Equatable, Sendable {
    let baseURL: URL
}

/// Verifies, without starting anything, that the exact packaged llama-server
/// helper is a direct child of the one running production Tilde and owns the
/// exact loopback listener on `port` — mirroring
/// `check_runtime_network_egress.py:require_owned_model`. Never launches or
/// mutates anything; a failed verification is reported, not repaired.
enum ReplayEvalServerOwnership {
    static func verifyOwnedServer(
        inspector: any ReplayEvalProcessInspecting,
        appExecutablePath: String,
        serverExecutablePath: String,
        port: Int
    ) -> Result<ReplayEvalOwnedServer, ReplayEvalOwnershipFailure> {
        guard let rows = inspector.processTable() else {
            return .failure(.processTableUnavailable)
        }
        let appMatches = rows.filter {
            $0.arguments.isEmpty && sameFile($0.executablePath, appExecutablePath)
        }
        guard appMatches.count <= 1 else { return .failure(.ambiguousApp) }
        guard let app = appMatches.first else { return .failure(.noRunningApp) }

        let servers = rows.filter {
            $0.ppid == app.pid && ($0.executablePath as NSString).lastPathComponent == "llama-server"
        }
        guard servers.count <= 1 else { return .failure(.ambiguousServerChild) }
        guard let server = servers.first else { return .failure(.noServerChild) }
        guard sameFile(server.executablePath, serverExecutablePath) else {
            return .failure(.wrongServerBinary)
        }
        guard optionValues(server.arguments, "--port") == [String(port)] else {
            return .failure(.wrongPort)
        }
        guard optionValues(server.arguments, "--host") == ["127.0.0.1"] else {
            return .failure(.notLoopbackOnly)
        }
        guard inspector.ownsExactLoopbackListener(pid: server.pid, port: port) else {
            return .failure(.listenerNotOwned)
        }
        return .success(ReplayEvalOwnedServer(baseURL: URL(string: "http://127.0.0.1:\(port)")!))
    }

    private static func sameFile(_ left: String, _ right: String) -> Bool {
        !left.isEmpty
            && URL(fileURLWithPath: left).resolvingSymlinksInPath().path
            == URL(fileURLWithPath: right).resolvingSymlinksInPath().path
    }

    private static func optionValues(_ arguments: [String], _ option: String) -> [String] {
        var values: [String] = []
        for (index, token) in arguments.enumerated() {
            if token == option {
                values.append(index + 1 < arguments.count ? arguments[index + 1] : "")
            } else if token.hasPrefix(option + "=") {
                values.append(String(token.dropFirst(option.count + 1)))
            }
        }
        return values
    }
}

/// Real process-table inspector: shells out to the same read-only,
/// side-effect-free tools (`ps`, `lsof`) the release-proof scripts use.
struct SystemReplayEvalProcessInspector: ReplayEvalProcessInspecting {
    func processTable() -> [ReplayEvalProcessRow]? {
        guard let output = Self.run("/bin/ps", ["-axo", "pid=,ppid=,args="]) else { return nil }
        var rows: [ReplayEvalProcessRow] = []
        for line in output.split(separator: "\n", omittingEmptySubsequences: true) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let fields = trimmed.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            guard fields.count == 3, let pid = Int32(fields[0]), let ppid = Int32(fields[1]) else {
                continue
            }
            let (executable, arguments) = Self.splitExecutable(String(fields[2]))
            rows.append(ReplayEvalProcessRow(
                pid: pid, ppid: ppid, executablePath: executable, arguments: arguments
            ))
        }
        return rows
    }

    func ownsExactLoopbackListener(pid: Int32, port: Int) -> Bool {
        guard let output = Self.run(
            "/usr/sbin/lsof",
            ["-nP", "-a", "-p", String(pid), "-iTCP:\(port)", "-sTCP:LISTEN", "-Fpn"]
        ) else { return false }
        var currentPID: Int32?
        var endpoints: [Int32: Set<String>] = [:]
        for field in output.split(separator: "\n", omittingEmptySubsequences: true) {
            if field.hasPrefix("p"), let value = Int32(field.dropFirst()) {
                currentPID = value
                endpoints[value, default: []] = []
            } else if field.hasPrefix("n"), let currentPID {
                endpoints[currentPID, default: []].insert(String(field.dropFirst()))
            }
        }
        return endpoints == [pid: ["127.0.0.1:\(port)"]]
    }

    /// `ps args` output is already flattened and unquoted; recover the
    /// executable by locating a known binary-name marker rather than naive
    /// whitespace splitting, exactly as the Python release-proof tooling does.
    private static func splitExecutable(_ args: String) -> (String, [String]) {
        for name in ["InlineGhostIME", "llama-server", "Tilde"] {
            let marker = "/" + name
            guard let range = args.range(of: marker, options: .backwards) else { continue }
            let end = range.upperBound
            guard end == args.endIndex || args[end].isWhitespace else { continue }
            let executable = String(args[..<end])
            let rest = args[end...].trimmingCharacters(in: .whitespaces)
            let arguments = rest.isEmpty
                ? [] : rest.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            return (executable, arguments)
        }
        let parts = args.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        return (parts.first.map(String.init) ?? args, [])
    }

    private static func run(_ path: String, _ arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return nil
        }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        // lsof exits non-zero when it finds no matching listener, which is a
        // legitimate "not listening" answer, not a launch failure — only a
        // failure to launch the tool at all (caught above) is unavailable.
        return String(data: data, encoding: .utf8)
    }
}
