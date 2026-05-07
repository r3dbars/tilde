import Foundation
import Testing
@testable import AutocompleteLabCore

@Suite("Autocomplete trace event schema")
struct AutocompleteTraceEventTests {
    @Test("Encodes current schema and privacy versions")
    func encodesCurrentVersions() throws {
        let event = AutocompleteTraceEvent(
            timestamp: "2026-05-07T00:00:00Z",
            sessionID: "session",
            suggestionID: "suggestion",
            type: .suggestionPresented
        )

        let data = try JSONEncoder().encode(event)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["schemaVersion"] as? Int == AutocompleteTraceEvent.currentSchemaVersion)
        #expect(object["privacyVersion"] as? Int == AutocompleteTraceEvent.currentPrivacyVersion)
        #expect(object["experimentArm"] as? String == "length_3_word")
    }

    @Test("Decodes old trace events without schema fields")
    func decodesOldTraceEventsWithoutSchemaFields() throws {
        let json = """
        {
          "timestamp": "2026-04-01T00:00:00Z",
          "sessionID": "session",
          "suggestionID": "suggestion",
          "type": "suggestionPresented",
          "metadata": {"fieldKind": "multilineCompose"}
        }
        """

        let event = try JSONDecoder().decode(AutocompleteTraceEvent.self, from: Data(json.utf8))

        #expect(event.schemaVersion == 1)
        #expect(event.privacyVersion == 0)
        #expect(event.experimentArm == "length_3_word")
        #expect(event.type == .suggestionPresented)
        #expect(event.metadata["fieldKind"] == "multilineCompose")
    }
}
