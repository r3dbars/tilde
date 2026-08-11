import AutocompleteLabCore
import Foundation
import Testing
@testable import InlineGhostIME

@Suite("Ghost brain client")
struct GhostBrainClientTests {
    @Test("Authenticated malformed responses are runtime errors")
    func malformedResponseIsError() {
        #expect(GhostBrainClient.decodeResponse(Data("not-json".utf8)) == .error)
    }
}
