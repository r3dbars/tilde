import Foundation
import Testing
import AutocompleteLabCore
@testable import AutocompleteLabApp

@Suite("Trace logger privacy routing")
struct TraceLoggerTests {
    /// Every field that can carry raw typed text, prompts, model output, or a
    /// screenshot path. The redacted default log must never contain any of these.
    private static let rawSecrets: [String] = [
        "the user is typing a private sentence",
        "text that comes after the caret",
        "you are a helpful system prompt",
        "draft email body the user is writing",
        "raw model output token stream",
        "cleaned visible suggestion text",
        "displayed ghost text",
        "accepted private completion",
        "remaining visible private text",
        "/Users/someone/Library/Logs/SteadyType/screenshots/secret.png"
    ]

    private func secretBearingEvent() -> AutocompleteTraceEvent {
        AutocompleteTraceEvent(
            timestamp: "2026-06-13T20:00:00Z",
            sessionID: "session-1",
            suggestionID: "suggestion-1",
            type: .suggestionAccepted,
            appBundleIdentifier: "com.apple.TextEdit",
            fieldIdentity: "field-1",
            requestMode: "wordCompletion",
            triggerReason: "typing",
            textBeforeCursor: Self.rawSecrets[0],
            textAfterCursor: Self.rawSecrets[1],
            systemPrompt: Self.rawSecrets[2],
            userPrompt: Self.rawSecrets[3],
            rawOutput: Self.rawSecrets[4],
            cleanedVisibleText: Self.rawSecrets[5],
            displayedText: Self.rawSecrets[6],
            acceptedText: Self.rawSecrets[7],
            remainingVisibleText: Self.rawSecrets[8],
            screenshotPath: Self.rawSecrets[9]
        )
    }

    private func makeLogger(in folder: URL) -> (logger: TraceLogger, redacted: URL, raw: URL) {
        let redacted = folder.appendingPathComponent("traces.jsonl")
        let raw = folder.appendingPathComponent("raw-traces.jsonl")
        let logger = TraceLogger(
            logURL: redacted,
            rawLogURL: raw,
            screenshotsURL: folder.appendingPathComponent("screenshots"),
            redactionLayer: RedactionLayer()
        )
        return (logger, redacted, raw)
    }

    private func decodeEvents(at url: URL) throws -> [AutocompleteTraceEvent] {
        let contents = try String(contentsOf: url, encoding: .utf8)
        let decoder = JSONDecoder()
        return contents
            .split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap { try? decoder.decode(AutocompleteTraceEvent.self, from: Data($0.utf8)) }
    }

    @Test("Default trace persists no raw typed text, prompts, output, or screenshot path")
    func defaultTraceDropsRawContent() async throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("TraceLoggerTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }

        let (logger, redacted, raw) = makeLogger(in: folder)

        await logger.record(secretBearingEvent(), writesRawDebugTrace: false)

        // The redacted log must exist and the raw log must never be created.
        let onDisk = try String(contentsOf: redacted, encoding: .utf8)
        #expect(!FileManager.default.fileExists(atPath: raw.path))

        // No raw secret may appear anywhere in the redacted file bytes.
        for secret in Self.rawSecrets {
            #expect(!onDisk.contains(secret), "redacted trace leaked raw content: \(secret)")
        }

        // The decoded event keeps only shape data, never the raw strings.
        let event = try #require(try decodeEvents(at: redacted).first)
        #expect(event.textBeforeCursor.isEmpty)
        #expect(event.textAfterCursor.isEmpty)
        #expect(event.systemPrompt.isEmpty)
        #expect(event.userPrompt.isEmpty)
        #expect(event.rawOutput.isEmpty)
        #expect(event.cleanedVisibleText.isEmpty)
        #expect(event.displayedText.isEmpty)
        #expect(event.acceptedText.isEmpty)
        #expect(event.remainingVisibleText.isEmpty)
        #expect(event.screenshotPath.isEmpty)

        // Shape and routing metadata survive so diagnostics stay useful.
        #expect(event.metadata["textBeforeCursorChars"] == String(Self.rawSecrets[0].count))
        #expect(event.metadata["screenshotCaptured"] == "true")
        #expect(event.metadata["privacyLane"] == TracePrivacyLane.redactedBetaTelemetry.rawValue)
        #expect(event.metadata["rawDogfoodDiagnostics"] == "false")
    }

    @Test("Raw debug trace keeps content in the raw log only, never the default log")
    func rawDebugTraceStaysOutOfDefaultLog() async throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("TraceLoggerTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }

        let (logger, redacted, raw) = makeLogger(in: folder)

        await logger.record(secretBearingEvent(), writesRawDebugTrace: true)

        // The redacted default log still leaks nothing, even when raw capture is on.
        let redactedOnDisk = try String(contentsOf: redacted, encoding: .utf8)
        for secret in Self.rawSecrets {
            #expect(!redactedOnDisk.contains(secret), "redacted trace leaked raw content: \(secret)")
        }

        // The raw dogfood log retains the content and is tagged as the raw lane.
        let rawEvent = try #require(try decodeEvents(at: raw).first)
        #expect(rawEvent.textBeforeCursor == Self.rawSecrets[0])
        #expect(rawEvent.acceptedText == Self.rawSecrets[7])
        #expect(rawEvent.metadata["privacyLane"] == TracePrivacyLane.rawDogfoodDiagnostics.rawValue)
        #expect(rawEvent.metadata["rawDogfoodDiagnostics"] == "true")
    }
}
