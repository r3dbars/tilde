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

    @Test("Silence and failure are distinct from a suggestion")
    func outcomesAreDistinct() throws {
        let outcomes: [GhostBrainResponse] = [
            .suggestion("next words"), .silence, .unavailable, .error, .timeout, .invalidRequest,
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
    }
}
