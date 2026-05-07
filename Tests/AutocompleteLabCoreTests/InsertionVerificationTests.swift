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

    @Test("Verifies rich editor whitespace equivalents")
    func verifiesRichEditorWhitespaceEquivalents() {
        let verifier = InsertionVerification()

        #expect(verifier.verify(
            previousTextBeforeCursor: "Can we",
            acceptedText: " make",
            currentTextBeforeCursor: "Can we\u{00A0}make"
        ) == .verified)

        #expect(verifier.verify(
            previousTextBeforeCursor: "Can we",
            acceptedText: " make",
            currentTextBeforeCursor: "Can we\u{202F}make"
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

    @Test("Detects duplicate accepted text")
    func detectsDuplicateAcceptedText() {
        let verifier = InsertionVerification()

        #expect(verifier.verify(
            previousTextBeforeCursor: "Can we",
            acceptedText: " make",
            currentTextBeforeCursor: "Can we make make"
        ) == .duplicateText)

        #expect(verifier.verify(
            previousTextBeforeCursor: "Can we",
            acceptedText: " make",
            currentTextBeforeCursor: "Can we make make this"
        ) == .duplicateText)
    }

    @Test("Detects literal Tab and selection changes after Tab accept")
    func detectsLiteralTabAndSelectionChanges() {
        let verifier = InsertionVerification()

        #expect(verifier.verify(
            previousTextBeforeCursor: "Can we",
            acceptedText: " make",
            currentTextBeforeCursor: "Can we\t"
        ) == .literalTab)

        #expect(verifier.verify(
            previousTextBeforeCursor: "Can we",
            acceptedText: " make",
            currentTextBeforeCursor: "Can we",
            previousTextAfterCursor: " keep writing",
            currentTextAfterCursor: " writing"
        ) == .selectionChangedUnexpectedly)
    }
}
