import Foundation
import Testing
@testable import AutocompleteLabApp

@Suite("Personal memory snapshot host")
struct PersonalMemorySnapshotHostTests {
    @Test("Usage outcomes build qualified words and phrase examples")
    func buildsMemoryFromUsageLogs() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("tilde-personal-memory-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let log = root.appendingPathComponent("ghost_events_test.jsonl")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let events: [[String: Any]] = [
            ["event": "typed_instead", "context": "Transcripted says we should", "typed": "ship it today"],
            ["event": "accept_all", "context": "Transcripted agrees we should", "accepted": "ship and learn"],
            ["event": "typed_instead", "context": "With Transcripted we should", "typed": "ship this now"],
        ]
        let data = try events
            .map { try JSONSerialization.data(withJSONObject: $0) + Data([0x0A]) }
            .reduce(into: Data()) { $0.append($1) }
        try data.write(to: log)

        let memory = PersonalMemorySnapshotHost.liveMemory(from: [log])
        #expect(memory.wordCompletion(for: "Tra") == "Transcripted")
        #expect(memory.examples(after: "Given the evidence, we should").count == 2)
    }
}
