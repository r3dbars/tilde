import Foundation
import Testing
@testable import TildeApp

private final class CallCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    func increment() { lock.lock(); count += 1; lock.unlock() }
    var value: Int { lock.lock(); defer { lock.unlock() }; return count }
}

@Suite("GLiNER redaction helper host")
struct GLiNERRedactionHelperHostTests {
    @Test("Missing assets fail closed: detectSpans returns nil, never an empty-but-successful result")
    func missingAssetsFailClosed() async {
        let host = GLiNERRedactionHelperHost(assetResolver: { nil })
        let result = await host.detectSpans(in: "some text")
        #expect(result == nil)
    }

    @Test("A resolver that keeps returning assets for a binary that fails to launch still fails closed")
    func launchFailureFailsClosed() async {
        let assets = GLiNERRedactionHelperHost.Assets(
            interpreter: "/nonexistent/interpreter",
            script: "/nonexistent/script.py",
            model: "/nonexistent/model.onnx",
            tokenizerDir: "/nonexistent/tokenizer-dir"
        )
        let host = GLiNERRedactionHelperHost(assetResolver: { assets })
        let result = await host.detectSpans(in: "some text")
        #expect(result == nil)
    }

    @Test("Repeated calls after a failure stay closed rather than retrying forever")
    func staysClosedAfterFailure() async {
        let callCount = CallCounter()
        let host = GLiNERRedactionHelperHost(assetResolver: {
            callCount.increment()
            return nil
        })
        _ = await host.detectSpans(in: "first")
        _ = await host.detectSpans(in: "second")
        // The resolver is consulted once on the first attempt; a broken
        // host does not re-resolve assets (and so does not re-attempt a
        // launch) on every subsequent call.
        #expect(callCount.value == 1)
    }

    /// Exercises the REAL child-process protocol end to end using a tiny
    /// fixture interpreter script (no Python/gliner/onnxruntime required —
    /// those are exactly the dependencies this repo does not install for
    /// `swift test`). This proves the line-delimited JSON wiring itself
    /// (ready handshake, request/response, process spawn/pipe plumbing) is
    /// correct; `script/redaction_eval.py` is what proves the real model
    /// integration end to end using this exact host.
    @Test("Real subprocess round-trip: ready handshake, then a request/response pair")
    func realSubprocessRoundTrip() async throws {
        let fixture = try Self.writeFixtureInterpreter()
        defer { try? FileManager.default.removeItem(at: fixture) }

        // The real `launch()` always invokes `interpreter script --model ... --tokenizer-dir ...`.
        // To run our shell fixture directly (no python3/gliner dependency)
        // we point `interpreter` at the fixture itself; it ignores every
        // argument it's given and just speaks the stdin/stdout protocol.
        let directAssets = GLiNERRedactionHelperHost.Assets(
            interpreter: fixture.path,
            script: "--ignored",
            model: "--ignored",
            tokenizerDir: fixture.deletingLastPathComponent().path
        )
        let host = GLiNERRedactionHelperHost(assetResolver: { directAssets })
        let result = await host.detectSpans(in: "hello world")
        #expect(result != nil)
        #expect(result?.first?.label == "fixture_label")
        host.stop()
    }

    /// A minimal shell "interpreter" that speaks exactly the protocol
    /// `redaction_helper.py` speaks: one `{"ready": true}` line, then one
    /// JSON reply per input line. Avoids any Python dependency in the
    /// hermetic test suite while still proving the real pipe/process code
    /// path (not a fake).
    private static func writeFixtureInterpreter() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let script = dir.appendingPathComponent("fixture_helper.sh")
        let contents = """
        #!/bin/sh
        echo '{"ready": true}'
        while IFS= read -r line; do
          echo '{"ok": true, "spans": [{"start": 0, "end": 5, "label": "fixture_label", "score": 0.9}]}'
        done
        """
        try contents.write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        return script
    }

    @Test("A well-formed ok:false reason:missing-text reply is NOT fatal — it does not mark the host broken")
    func missingTextReplyDoesNotMarkBroken() async throws {
        // Mirrors `redaction_helper.py`'s real behavior for an empty
        // `text` field: `{"ok": false, "reason": "missing-text"}`. Every
        // OTHER call still gets the normal successful reply, so this
        // fixture proves one benign missing-text reply cannot poison
        // later calls the way any other `ok:false` reason (or a
        // transport failure) intentionally does.
        let fixture = try Self.writeAlwaysMissingTextThenSuccessInterpreter()
        defer { try? FileManager.default.removeItem(at: fixture) }

        let directAssets = GLiNERRedactionHelperHost.Assets(
            interpreter: fixture.path,
            script: "--ignored",
            model: "--ignored",
            tokenizerDir: fixture.deletingLastPathComponent().path
        )
        let host = GLiNERRedactionHelperHost(assetResolver: { directAssets })
        defer { host.stop() }

        // First call: the fixture replies missing-text. Must come back as
        // an explicit "found nothing" — NOT nil/unavailable.
        let firstResult = await host.detectSpans(in: "some text the fixture will call missing-text")
        #expect(firstResult == [])

        // Second call on the SAME host: proves the first reply did not
        // call `markBroken()` — a broken host always returns nil.
        let secondResult = await host.detectSpans(in: "some other text")
        #expect(secondResult != nil)
        #expect(secondResult?.first?.label == "fixture_label")
    }

    /// A fixture interpreter that answers the FIRST request with a
    /// well-formed `{"ok": false, "reason": "missing-text"}` (exactly what
    /// `redaction_helper.py` sends for empty input) and every later
    /// request with a normal successful reply — regardless of what text
    /// it was actually sent, so the test can drive the missing-text branch
    /// on demand without depending on this host's own empty-text handling.
    private static func writeAlwaysMissingTextThenSuccessInterpreter() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let script = dir.appendingPathComponent("fixture_missing_text_helper.sh")
        let contents = """
        #!/bin/sh
        echo '{"ready": true}'
        first=1
        while IFS= read -r line; do
          if [ "$first" = "1" ]; then
            echo '{"ok": false, "reason": "missing-text"}'
            first=0
          else
            echo '{"ok": true, "spans": [{"start": 0, "end": 5, "label": "fixture_label", "score": 0.9}]}'
          fi
        done
        """
        try contents.write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        return script
    }
}
