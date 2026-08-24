import AutocompleteLabCore
import Foundation

/// The release gate's packaged capture/redaction stimulus (AGENTS.md).
///
/// The runtime egress lane observes the release-proof app's sockets, but
/// until this existed nothing in that window ever executed Screen Memory's
/// code paths — the gate could not tell whether scene classification,
/// scene-bearing prompting, or redaction opened a socket, and it never
/// demonstrated that redaction fails closed. This stimulus runs INSIDE the
/// observed release-proof process, on compiled-in synthetic text (no
/// Screen Recording permission, no user data):
///
///  1. classifies a synthetic chat window's blocks into a scene,
///  2. builds the production scene-bearing prompt and completes it against
///     the packaged helper over loopback,
///  3. passes synthetic text through the shipped RedactionService — in a
///     release bundle the span model is absent, so the expected outcome is
///     the fail-closed drop,
///
/// and writes a count-only JSON report for the egress script to assert.
/// No raw text leaves this type: the report carries outcomes and counts.
enum ScreenMemoryProofStimulus {
    static let environmentKey = "TILDE_RELEASE_PROOF_STIMULUS_OUT"

    /// A fixed synthetic conversation shaped like a real chat window.
    static func syntheticBlocks() -> [ScreenScene.OCRBlock] {
        let frame = ScreenScene.NormalizedRect(x: 0.3, y: 0.1, width: 0.4, height: 0.8)
        func block(_ text: String, _ x: Double, _ y: Double) -> ScreenScene.OCRBlock {
            ScreenScene.OCRBlock(
                text: text,
                boundingBox: ScreenScene.NormalizedRect(x: x, y: y, width: 0.2, height: 0.03),
                windowOwnerBundleID: "proof.synthetic.chat",
                windowTitle: nil,
                windowFrame: frame
            )
        }
        return [
            block("are we still on for the synthetic meeting later", 0.32, 0.30),
            block("yes, just confirming the room now", 0.48, 0.42),
            block("great, can you send the summary before it starts?", 0.32, 0.55),
        ]
    }

    static func classifiedScene() -> ScreenScene.Scene {
        ScreenScene.classify(
            blocks: syntheticBlocks(),
            frontmostBundleID: "proof.synthetic.chat",
            fieldText: ""
        )
    }

    struct Report: Codable {
        let schema: String
        let sceneMode: String
        let classifiedTurns: Int
        let promptContainsConversation: Bool
        let completionRan: Bool
        let completionCharacters: Int
        let redactionOutcome: String
        let rawTextPersisted: Bool
    }

    /// Runs the full stimulus against the helper at `port` and writes the
    /// report to `outputPath`. Any thrown error is reported as a failed
    /// stimulus by the egress script (missing/invalid report file).
    static func run(port: Int, outputPath: String) async {
        let scene = classifiedScene()
        let typed = "Sure, I can send "
        let prompt = RawContinuationPrompt(
            textBeforeCursor: typed,
            register: ContinuationRegister.following(scene: scene, hostBundleIdentifier: nil),
            scene: scene
        )

        var completionCharacters = 0
        var completionRan = false
        if await waitForHelperHealth(port: port) {
            let engine = LlamaCompletionEngine(baseURL: URL(string: "http://127.0.0.1:\(port)")!)
            do {
                // A nil suggestion is a legitimate outcome (the cleaner
                // chose silence); what the gate needs is that the
                // scene-bearing request round-tripped the packaged helper.
                let suggestion = try await engine.suggestion(
                    textBeforeCursor: typed,
                    appBundleIdentifier: "proof.synthetic.chat",
                    scene: scene
                )
                completionRan = true
                completionCharacters = suggestion?.visibleText.count ?? 0
            } catch {
                completionRan = false
            }
        }

        let redaction = await RedactionService(spanDetector: GLiNERRedactionHelperHost())
            .redact("synthetic text with a fake code 4921-1188-2266-3344 inside")
        let redactionOutcome: String
        switch redaction {
        case .redacted: redactionOutcome = "redacted"
        case let .dropped(reason): redactionOutcome = "dropped-\(reason)"
        }

        let report = Report(
            schema: "tilde.release-proof-screen-memory-stimulus.v1",
            sceneMode: scene.mode.rawValue,
            classifiedTurns: scene.conversationTurns.count,
            promptContainsConversation: prompt.prompt.contains("Conversation:"),
            completionRan: completionRan,
            completionCharacters: completionCharacters,
            redactionOutcome: redactionOutcome,
            rawTextPersisted: false
        )
        if let data = try? JSONEncoder().encode(report) {
            try? data.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
        }
    }

    private static func waitForHelperHealth(port: Int, timeoutSeconds: Int = 90) async -> Bool {
        let url = URL(string: "http://127.0.0.1:\(port)/health")!
        for _ in 0..<(timeoutSeconds * 2) {
            if let (_, response) = try? await LocalhostURLSession.shared.data(for: URLRequest(url: url)),
               (response as? HTTPURLResponse)?.statusCode == 200 {
                return true
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        return false
    }
}
