import Testing
@testable import AutocompleteLabCore

@Suite("Obsidian insertion verification fast path")
struct ObsidianInsertionVerificationFastPathPolicyTests {
    private let policy = ObsidianInsertionVerificationFastPathPolicy()

    @Test("Verifies long Obsidian suffix insertion when repaired AX lengths match")
    func verifiesLengthMatchedSuffixInsertion() {
        let before = String(repeating: "Autocomplete Lab Obsidian proof line\n", count: 8) + "Smoke proof feels instant and stays inst"

        #expect(policy.canVerifyLengthMatchedSuffix(
            appBundleIdentifier: "md.obsidian",
            previousTextBeforeCursor: before,
            acceptedText: "ant",
            currentTextBeforeCursor: before + "ant",
            previousTextAfterCursor: "",
            currentTextAfterCursor: "",
            verificationResult: .changedUnexpectedly
        ))
    }

    @Test("Rejects short or after-cursor Obsidian mismatches")
    func rejectsUnsafeMismatches() {
        #expect(!policy.canVerifyLengthMatchedSuffix(
            appBundleIdentifier: "md.obsidian",
            previousTextBeforeCursor: "short inst",
            acceptedText: "ant",
            currentTextBeforeCursor: "short instant",
            previousTextAfterCursor: "",
            currentTextAfterCursor: "",
            verificationResult: .changedUnexpectedly
        ))

        #expect(!policy.canVerifyLengthMatchedSuffix(
            appBundleIdentifier: "md.obsidian",
            previousTextBeforeCursor: String(repeating: "line\n", count: 40) + "inst",
            acceptedText: "ant",
            currentTextBeforeCursor: String(repeating: "line\n", count: 40) + "instant",
            previousTextAfterCursor: "",
            currentTextAfterCursor: "later text",
            verificationResult: .changedUnexpectedly
        ))

        #expect(!policy.canVerifyLengthMatchedSuffix(
            appBundleIdentifier: "md.obsidian",
            previousTextBeforeCursor: String(repeating: "line\n", count: 40) + "inst",
            acceptedText: "ant",
            currentTextBeforeCursor: String(repeating: "line\n", count: 40) + "instxxx",
            previousTextAfterCursor: "",
            currentTextAfterCursor: "",
            verificationResult: .changedUnexpectedly
        ))
    }

    @Test("Does not apply the Obsidian fast path to another app")
    func rejectsNonObsidianBundle() {
        let before = String(repeating: "line\n", count: 40) + "inst"

        #expect(!policy.canVerifyLengthMatchedSuffix(
            appBundleIdentifier: "com.apple.TextEdit",
            previousTextBeforeCursor: before,
            acceptedText: "ant",
            currentTextBeforeCursor: before + "ant",
            previousTextAfterCursor: "",
            currentTextAfterCursor: "",
            verificationResult: .changedUnexpectedly
        ))
    }
}
