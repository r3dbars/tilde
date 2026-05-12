import Foundation
import Testing
@testable import AutocompleteLabApp

@Suite("Privacy export proof command")
struct PrivacyExportProofCommandTests {
    @Test("Privacy proof flag is recognized")
    func recognizesProofFlag() {
        #expect(
            PrivacyExportProofCommand.isRequested(
                arguments: ["AutocompleteLab", "--privacy-export-proof"]
            )
        )
        #expect(
            !PrivacyExportProofCommand.isRequested(arguments: ["AutocompleteLab"])
        )
    }

    @Test("Privacy proof command exports only redacted default artifacts")
    func exportsOnlyRedactedDefaultArtifacts() throws {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PrivacyExportProofCommandTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: outputURL)
        }

        let exitCode = PrivacyExportProofCommand.run(
            arguments: [
                "AutocompleteLab",
                "--privacy-export-proof",
                "--output",
                outputURL.path
            ]
        )

        #expect(exitCode == 0)
        #expect(FileManager.default.fileExists(atPath: outputURL.appendingPathComponent("privacy-export").path))
        #expect(!FileManager.default.fileExists(atPath: outputURL.appendingPathComponent("traces.jsonl").path))

        let exportedText = try recursiveTextContents(at: outputURL)
        #expect(exportedText.contains("rawTextIncludedInDefaultArtifact"))
        #expect(exportedText.contains("privacyExportPathRedacted"))
        #expect(exportedText.contains("false"))
        #expect(!exportedText.contains(outputURL.path))
        #expect(!exportedText.contains("proof-private-before-redbars"))
        #expect(!exportedText.contains("proof-private-after-redbars"))
        #expect(!exportedText.contains("proof-private-system-prompt-redbars"))
        #expect(!exportedText.contains("proof-private-user-prompt-redbars"))
        #expect(!exportedText.contains("proof-private-model-output-redbars"))
        #expect(!exportedText.contains("proof-private-visible-suggestion-redbars"))
        #expect(!exportedText.contains("proof-private-accepted-redbars"))
        #expect(!exportedText.contains("proof-private-remaining-redbars"))
        #expect(!exportedText.contains("https://private.example/redbars"))
        #expect(!exportedText.contains("/tmp/proof-private-screenshot-redbars.png"))
        #expect(!exportedText.contains("/Users/redbars/Library/Application Support/SteadyType/private-cache-redbars"))
        #expect(!exportedText.contains("loaded from /Users/redbars/private/freeform-reason-redbars.md"))
        #expect(!exportedText.contains("proof private document title redbars"))
        #expect(!exportedText.contains("proof-private-recipient@example.com"))
        #expect(!exportedText.contains("proof private subject redbars"))
    }

    private func recursiveTextContents(at folderURL: URL) throws -> String {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return ""
        }

        var contents = ""
        for case let fileURL as URL in enumerator {
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else {
                continue
            }

            contents += (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
            contents += "\n"
        }

        return contents
    }
}
