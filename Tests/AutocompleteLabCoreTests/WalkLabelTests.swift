import Foundation
import Testing

/// The arithmetic behind Tab-walk labels.
///
/// Taking 4 words of an 8-word offer means the model was right through word 4
/// and wrong at word 5. That inference is the entire value of the walk
/// logging, so the counting has to be exact — an off-by-one here would
/// mislabel every training row it produces.
///
/// Mirrors the word-splitting and stop-point logic in GhostInputController's
/// walk tracking; the controller itself is an IMKInputController and cannot be
/// instantiated in a test process.
@Suite("Tab-walk labels")
struct WalkLabelTests {

    /// The controller's rule: take characters up to and including the space
    /// that ends the first word.
    private func firstChunk(of ghost: String) -> String {
        var chunk = ""
        var sawWord = false
        for character in ghost {
            if character == " " {
                chunk.append(character)
                if sawWord { break }
            } else {
                sawWord = true
                chunk.append(character)
            }
        }
        return chunk
    }

    private func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace }).count
    }

    /// Walk `presses` words off `offer`, returning what a reader would infer.
    private func walk(_ offer: String, presses: Int)
        -> (taken: Int, offered: Int, stoppedEarly: Bool, firstWrongWord: Int?) {
        var remaining = offer
        var taken = 0
        for _ in 0..<presses {
            guard !remaining.isEmpty else { break }
            let chunk = firstChunk(of: remaining)
            remaining = String(remaining.dropFirst(chunk.count))
            taken += 1
        }
        let offered = wordCount(offer)
        let stoppedEarly = taken < offered
        return (taken, offered, stoppedEarly, stoppedEarly ? taken + 1 : nil)
    }

    @Test("Stopping early names the word that was wrong")
    func stoppingEarlyLocatesTheFailure() {
        let offer = "going to be about ten minutes late today"
        let result = walk(offer, presses: 4)
        #expect(result.offered == 8)
        #expect(result.taken == 4)
        #expect(result.stoppedEarly)
        // Right through "about", wrong at "ten" — a per-word label, not a
        // verdict on the whole suggestion.
        #expect(result.firstWrongWord == 5)
    }

    @Test("Taking the whole offer is not an abandonment")
    func completedWalkHasNoFailurePoint() {
        let offer = "sounds good to me"
        let result = walk(offer, presses: 4)
        #expect(result.taken == 4)
        #expect(result.offered == 4)
        #expect(!result.stoppedEarly)
        // Nothing was left on the table, so there is no rejected word to log.
        #expect(result.firstWrongWord == nil)
    }

    @Test("The common case — one word taken, the rest abandoned")
    func singleWordWalk() {
        // 471 of 620 measured walks stop here. The label says the very next
        // word was already wrong.
        let result = walk("yeah I think we can make that work", presses: 1)
        #expect(result.taken == 1)
        #expect(result.offered == 8)
        #expect(result.firstWrongWord == 2)
    }

    @Test("Word counting survives punctuation, double spaces and trailing space")
    func wordCountingIsRobust() {
        #expect(wordCount("running late, sorry!") == 3)
        #expect(wordCount("see  you   soon") == 3)
        #expect(wordCount("on my way ") == 3)
        #expect(wordCount("") == 0)
        #expect(wordCount("   ") == 0)
    }

    @Test("A one-word offer taken whole is complete, not a stop")
    func singleWordOfferTakenWhole() {
        let result = walk("okay", presses: 1)
        #expect(result.offered == 1)
        #expect(result.taken == 1)
        #expect(!result.stoppedEarly)
    }

    @Test("Pressing past the end cannot claim more words than were offered")
    func cannotOverrunTheOffer() {
        // Guards the label against a walk counter that keeps incrementing
        // after the chain is exhausted — that would report taking 5 of 3.
        let result = walk("almost there", presses: 5)
        #expect(result.taken == 2)
        #expect(result.offered == 2)
        #expect(!result.stoppedEarly)
    }
}
