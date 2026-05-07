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

    @Test("Detects duplicated accepted text")
    func detectsDuplicatedAcceptedText() {
        let verifier = InsertionVerification()

        #expect(verifier.verify(
            previousTextBeforeCursor: "Can we",
            acceptedText: " make",
            currentTextBeforeCursor: "Can we make make"
        ) == .duplicatedAcceptedText)
    }

    @Test("Detects accepted text inserted away from the captured cursor")
    func detectsAcceptedTextAtWrongLocation() {
        let verifier = InsertionVerification()

        #expect(verifier.verify(
            previousTextBeforeCursor: "Can we",
            acceptedText: " make",
            currentTextBeforeCursor: "Can make"
        ) == .insertedAtWrongLocation)

        #expect(verifier.verify(
            previousTextBeforeCursor: "Can we",
            acceptedText: " make",
            currentTextBeforeCursor: "Can we later make"
        ) == .insertedAtWrongLocation)
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
