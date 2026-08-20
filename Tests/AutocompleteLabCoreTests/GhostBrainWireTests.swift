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
