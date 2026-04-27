import Testing
@testable import AutocompleteLabCore

@Suite("Insertion verification")
struct InsertionVerificationTests {
    @Test("Verifies accepted text landed exactly after the previous cursor text")
    func verifiesExactAcceptedText() {
        let verifier = InsertionVerification()

        #expect(verifier.verify(
            previousTextBeforeCursor: "Can we",
            acceptedText: " make",
            currentTextBeforeCursor: "Can we make"
        ) == .verified)
    }

    @Test("Detects unchanged and partially inserted text")
    func detectsUnchangedAndPartialInsertion() {
        let verifier = InsertionVerification()

        #expect(verifier.verify(
            previousTextBeforeCursor: "Can we",
            acceptedText: " make",
            currentTextBeforeCursor: "Can we"
        ) == .unchanged)

        #expect(verifier.verify(
            previousTextBeforeCursor: "Can we",
            acceptedText: " make",
            currentTextBeforeCursor: "Can we ma"
        ) == .partial)
    }

    @Test("Detects unexpected editor mutations")
    func detectsUnexpectedEditorMutations() {
        let verifier = InsertionVerification()

        #expect(verifier.verify(
            previousTextBeforeCursor: "Can we",
            acceptedText: " make",
            currentTextBeforeCursor: "Something else"
        ) == .changedUnexpectedly)
    }
}
