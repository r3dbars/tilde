import Foundation
import Testing
@testable import AutocompleteLabApp

@Suite("Runtime boundaries")
struct RuntimeBoundaryTests {
    @Test("Runtime base URL uses the injected port")
    func injectedPort() {
        let runtime = LlamaServerProcessHost(port: 19_001)

        #expect(runtime.baseURL == URL(string: "http://127.0.0.1:19001"))
    }

    @Test("Localhost requests never follow redirects")
    func redirectsAreRejected() async throws {
        let local = try #require(URL(string: "http://127.0.0.1:17872/completion"))
        let remote = try #require(URL(string: "https://example.com/collect"))
        let response = try #require(HTTPURLResponse(
            url: local,
            statusCode: 307,
            httpVersion: "HTTP/1.1",
            headerFields: ["Location": remote.absoluteString]
        ))
        let session = URLSession(configuration: .ephemeral)
        let task = session.dataTask(with: local)
        defer { session.invalidateAndCancel() }

        let redirected = await withCheckedContinuation { continuation in
            LocalhostURLSessionDelegate().urlSession(
                session,
                task: task,
                willPerformHTTPRedirection: response,
                newRequest: URLRequest(url: remote)
            ) { continuation.resume(returning: $0) }
        }

        #expect(redirected == nil)
        #expect(LocalhostURLSession.shared.delegate is LocalhostURLSessionDelegate)
    }

    @Test("Exact child shutdown is bounded and synchronous")
    func childShutdownIsBounded() throws {
        let child = Process()
        child.executableURL = URL(fileURLWithPath: "/bin/sleep")
        child.arguments = ["10"]
        try child.run()

        let started = ContinuousClock.now
        LlamaServerProcessHost.shutDownNow(child)

        #expect(!child.isRunning)
        #expect(ContinuousClock.now - started < .seconds(2))
    }
}
