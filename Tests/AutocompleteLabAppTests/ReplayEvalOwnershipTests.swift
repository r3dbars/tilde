import Foundation
import Testing
@testable import AutocompleteLabApp

@Suite("Replay-eval server ownership")
struct ReplayEvalOwnershipTests {
    private let appPath = "/Applications/Tilde.app/Contents/MacOS/Tilde"
    private let serverPath = "/Applications/Tilde.app/Contents/Helpers/llama-server"
    private let port = 17_872

    @Test("A single owned, loopback-only child is accepted")
    func acceptsOwnedServer() {
        let inspector = FakeInspector(
            rows: [
                .init(pid: 1, ppid: 0, executablePath: appPath, arguments: []),
                .init(
                    pid: 2, ppid: 1, executablePath: serverPath,
                    arguments: ["--port", "17872", "--host", "127.0.0.1"]
                ),
            ],
            loopbackOwners: [2]
        )

        let result = verify(inspector)

        #expect(result.isSuccess)
    }

    @Test("No running app fails closed")
    func noRunningAppFails() {
        let result = verify(FakeInspector(rows: [], loopbackOwners: []))
        #expect(result == .failure(.noRunningApp))
    }

    @Test("More than one matching app fails closed")
    func ambiguousAppFails() {
        let inspector = FakeInspector(
            rows: [
                .init(pid: 1, ppid: 0, executablePath: appPath, arguments: []),
                .init(pid: 2, ppid: 0, executablePath: appPath, arguments: []),
            ],
            loopbackOwners: []
        )
        #expect(verify(inspector) == .failure(.ambiguousApp))
    }

    @Test("An app process with extra arguments is not the production instance")
    func nonProductionAppIsNotMatched() {
        let inspector = FakeInspector(
            rows: [.init(pid: 1, ppid: 0, executablePath: appPath, arguments: ["--release-proof"])],
            loopbackOwners: []
        )
        #expect(verify(inspector) == .failure(.noRunningApp))
    }

    @Test("No llama-server child fails closed")
    func noServerChildFails() {
        let inspector = FakeInspector(
            rows: [.init(pid: 1, ppid: 0, executablePath: appPath, arguments: [])],
            loopbackOwners: []
        )
        #expect(verify(inspector) == .failure(.noServerChild))
    }

    @Test("A server that is not a direct child is not found")
    func nonChildServerIsNotFound() {
        let inspector = FakeInspector(
            rows: [
                .init(pid: 1, ppid: 0, executablePath: appPath, arguments: []),
                .init(
                    pid: 3, ppid: 99, executablePath: serverPath,
                    arguments: ["--port", "17872", "--host", "127.0.0.1"]
                ),
            ],
            loopbackOwners: [3]
        )
        #expect(verify(inspector) == .failure(.noServerChild))
    }

    @Test("A server binary that is not the packaged helper is rejected")
    func wrongServerBinaryIsRejected() {
        let inspector = FakeInspector(
            rows: [
                .init(pid: 1, ppid: 0, executablePath: appPath, arguments: []),
                .init(
                    pid: 2, ppid: 1, executablePath: "/tmp/evil/llama-server",
                    arguments: ["--port", "17872", "--host", "127.0.0.1"]
                ),
            ],
            loopbackOwners: [2]
        )
        #expect(verify(inspector) == .failure(.wrongServerBinary))
    }

    @Test("A server on the wrong port is rejected")
    func wrongPortIsRejected() {
        let inspector = FakeInspector(
            rows: [
                .init(pid: 1, ppid: 0, executablePath: appPath, arguments: []),
                .init(
                    pid: 2, ppid: 1, executablePath: serverPath,
                    arguments: ["--port", "17873", "--host", "127.0.0.1"]
                ),
            ],
            loopbackOwners: [2]
        )
        #expect(verify(inspector) == .failure(.wrongPort))
    }

    @Test("A non-loopback host is rejected")
    func nonLoopbackHostIsRejected() {
        let inspector = FakeInspector(
            rows: [
                .init(pid: 1, ppid: 0, executablePath: appPath, arguments: []),
                .init(
                    pid: 2, ppid: 1, executablePath: serverPath,
                    arguments: ["--port", "17872", "--host", "0.0.0.0"]
                ),
            ],
            loopbackOwners: [2]
        )
        #expect(verify(inspector) == .failure(.notLoopbackOnly))
    }

    @Test("A server whose listener does not observably match is rejected")
    func unobservedListenerIsRejected() {
        let inspector = FakeInspector(
            rows: [
                .init(pid: 1, ppid: 0, executablePath: appPath, arguments: []),
                .init(
                    pid: 2, ppid: 1, executablePath: serverPath,
                    arguments: ["--port", "17872", "--host", "127.0.0.1"]
                ),
            ],
            loopbackOwners: []
        )
        #expect(verify(inspector) == .failure(.listenerNotOwned))
    }

    @Test("An unreadable process table fails closed")
    func unreadableProcessTableFails() {
        #expect(verify(FakeInspector(rows: nil, loopbackOwners: [])) == .failure(.processTableUnavailable))
    }

    private func verify(
        _ inspector: FakeInspector
    ) -> Result<ReplayEvalOwnedServer, ReplayEvalOwnershipFailure> {
        ReplayEvalServerOwnership.verifyOwnedServer(
            inspector: inspector,
            appExecutablePath: appPath,
            serverExecutablePath: serverPath,
            port: port
        )
    }

    private struct FakeInspector: ReplayEvalProcessInspecting {
        let rows: [ReplayEvalProcessRow]?
        let loopbackOwners: Set<Int32>

        func processTable() -> [ReplayEvalProcessRow]? { rows }
        func ownsExactLoopbackListener(pid: Int32, port: Int) -> Bool {
            loopbackOwners.contains(pid)
        }
    }
}

extension Result {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}
