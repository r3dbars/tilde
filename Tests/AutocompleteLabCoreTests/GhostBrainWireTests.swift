import Foundation
import Testing
@testable import AutocompleteLabCore

@Suite("Ghost brain wire")
struct GhostBrainWireTests {
    @Test("Request carries an explicit version")
    func requestVersion() throws {
        let request = GhostBrainRequest(context: "hello ", app: "com.apple.TextEdit")
        let decoded = try JSONDecoder().decode(
            GhostBrainRequest.self,
            from: JSONEncoder().encode(request)
        )
        #expect(decoded == request)
        #expect(decoded.v == 1)
        #expect(decoded.supportsStreamingResponses)
    }

    @Test("Requests without the stream flag remain final-only")
    func legacyRequestIsFinalOnly() throws {
        let current = GhostBrainRequest(context: "hello ", app: "com.apple.TextEdit")
        var object = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(current)) as? [String: Any]
        )
        object.removeValue(forKey: "streamResponses")
        let legacy = try JSONDecoder().decode(
            GhostBrainRequest.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        #expect(legacy.v == GhostBrainRequest.version)
        #expect(!legacy.supportsStreamingResponses)
    }

    @Test("Streamed response lines carry a terminal marker")
    func streamedResponseMarker() throws {
        let partial = GhostBrainResponse.partial(" world")
        let decodedPartial = try JSONDecoder().decode(
            GhostBrainResponse.self,
            from: JSONEncoder().encode(partial)
        )
        #expect(decodedPartial.final == false)
        #expect(decodedPartial.suggestion == " world")

        let final = GhostBrainResponse.suggestion(" world again")
        let decodedFinal = try JSONDecoder().decode(
            GhostBrainResponse.self,
            from: JSONEncoder().encode(final)
        )
        #expect(decodedFinal.final)
        // Lines from a pre-stream app have no marker and are terminal.
        #expect(GhostBrainResponse.decode(Data(#"{"outcome":"silence"}"#.utf8)).final)
    }

    @Test("Screen Memory field events carry lifecycle only, never text")
    func screenMemoryLifecycleRequest() throws {
        let event = ScreenMemoryInputEvent(
            kind: .typingPaused,
            sessionIdentifier: UUID().uuidString
        )
        let request = GhostBrainRequest(screenMemoryEvent: event)
        let decoded = try JSONDecoder().decode(
            GhostBrainRequest.self,
            from: JSONEncoder().encode(request)
        )
        #expect(decoded == request)
        #expect(decoded.context.isEmpty)
        #expect(decoded.app == nil)
        #expect(decoded.personalHistoryEvents == nil)
        #expect(decoded.screenMemoryEvent == event)
    }

    @Test("Silence and failure are distinct from a suggestion")
    func outcomesAreDistinct() throws {
        let outcomes: [GhostBrainResponse] = [
            .suggestion("next words"), .silence, .unavailable, .error, .timeout, .invalidRequest,
            .recorded,
        ]
        for outcome in outcomes {
            let decoded = try JSONDecoder().decode(
                GhostBrainResponse.self,
                from: JSONEncoder().encode(outcome)
            )
            #expect(decoded == outcome)
        }
        #expect(GhostBrainResponse.suggestion("") == .silence)
        #expect(GhostBrainResponse.silence != .unavailable)
        #expect(GhostBrainResponse.decode(Data("not-json".utf8)) == .error)
    }
}
