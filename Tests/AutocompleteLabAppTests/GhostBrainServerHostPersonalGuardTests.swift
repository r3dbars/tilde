import Foundation
import Testing
@testable import AutocompleteLabApp

@Suite("Personal serving mid-word guard")
struct GhostBrainServerHostPersonalGuardTests {
    @Test("Word-boundary context yields tail words")
    func wordBoundaryYieldsTailWords() {
        let tailWords = GhostBrainServerHost.personalTailWords(fromContext: "see you tomorrow ")
        #expect(tailWords == ["you", "tomorrow"])
    }

    @Test("Mid-word context is refused, never handed to the personal model")
    func midWordContextIsRefused() {
        // Cursor sits right after "tomo" — the word isn't finished yet. If
        // this were tokenized as a tail word, a confident personal
        // prediction for "tomorrow" could be glued straight onto it
        // ("tomotomorrow").
        let tailWords = GhostBrainServerHost.personalTailWords(fromContext: "see you tomo")
        #expect(tailWords.isEmpty)
    }

    @Test("Empty context yields no tail words")
    func emptyContextYieldsNoTailWords() {
        #expect(GhostBrainServerHost.personalTailWords(fromContext: "").isEmpty)
    }
}
