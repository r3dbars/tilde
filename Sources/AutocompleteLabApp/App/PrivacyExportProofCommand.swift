import Foundation
import AutocompleteLabCore

enum PrivacyExportProofCommand {
    private static let flag = "--privacy-export-proof"
    private static let outputFlag = "--output"

    private static let privateSentinels = [
        "proof-private-before-redbars",
        "proof-private-after-redbars",
        "proof-private-system-prompt-redbars",
        "proof-private-user-prompt-redbars",
        "proof-private-model-output-redbars",
        "proof-private-visible-suggestion-redbars",
        "proof-private-accepted-redbars",
        "proof-private-remaining-redbars",
        "https://private.example/redbars",
        "/tmp/proof-private-screenshot-redbars.png",
        "proof private document title redbars",
        "proof-private-recipient@example.com",
        "proof private subject redbars"
    ]

    static func isRequested(arguments: [String]) -> Bool {
        arguments.contains(flag)
    }

    @discardableResult
    static func run(arguments: [String]) -> Int32 {
        do {
            let outputURL = outputDirectory(arguments: arguments)
            let exportURL = try makeProofExport(outputURL: outputURL)
            print("Privacy export proof passed: \(exportURL.path)")
            return 0
        } catch {
            fputs("Privacy export proof failed: \(error)\n", stderr)
            return 1
        }
    }

    private static func outputDirectory(arguments: [String]) -> URL {
        if let output = argument(after: outputFlag, in: arguments), !output.isEmpty {
            return URL(fileURLWithPath: output)
        }

        if let output = ProcessInfo.processInfo.environment["AUTOCOMPLETE_LAB_PRIVACY_PROOF_OUTPUT"],
           !output.isEmpty {
            return URL(fileURLWithPath: output)
        }

        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("docs/diagnostics/runs/current-build-privacy-export-proof", isDirectory: true)
    }

    private static func argument(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag) else {
            return nil
        }

        let valueIndex = arguments.index(after: index)
        guard valueIndex < arguments.endIndex else {
            return nil
        }

        return arguments[valueIndex]
    }

    private static func makeProofExport(outputURL: URL) throws -> URL {
        let fileManager = FileManager.default
        let scratchURL = fileManager.temporaryDirectory
            .appendingPathComponent("AutocompletePrivacyExportProof-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? fileManager.removeItem(at: scratchURL)
        }

        try fileManager.createDirectory(at: scratchURL, withIntermediateDirectories: true)
        try writeSyntheticRawTrace(to: scratchURL.appendingPathComponent("traces.jsonl"))

        guard let redactedBundleURL = LocalReportExporter(folderURL: scratchURL).exportPrivacyBundle(limit: 20) else {
            throw ProofError.exportMissing
        }

        try failIfExportContainsPrivateSentinels(redactedBundleURL)

        try fileManager.createDirectory(at: outputURL, withIntermediateDirectories: true)
        let finalBundleURL = outputURL.appendingPathComponent("privacy-export", isDirectory: true)
        try? fileManager.removeItem(at: finalBundleURL)
        try fileManager.copyItem(at: redactedBundleURL, to: finalBundleURL)
        try writeProofManifest(to: outputURL, exportURL: finalBundleURL)

        return finalBundleURL
    }

    private static func writeSyntheticRawTrace(to traceURL: URL) throws {
        let events = [
            AutocompleteTraceEvent(
                timestamp: "2026-05-08T00:00:00Z",
                sessionID: "privacy-proof-session",
                suggestionID: "privacy-proof-one",
                type: .suggestionPresented,
                appBundleIdentifier: "com.apple.TextEdit",
                fieldIdentity: "com.apple.TextEdit|pid:123|element:456",
                requestMode: "wordCompletion",
                triggerReason: "privacy-proof",
                textBeforeCursor: "proof-private-before-redbars",
                textAfterCursor: "proof-private-after-redbars",
                systemPrompt: "proof-private-system-prompt-redbars",
                userPrompt: "proof-private-user-prompt-redbars",
                rawOutput: "proof-private-model-output-redbars",
                cleanedVisibleText: "proof-private-visible-suggestion-redbars",
                displayedText: "proof-private-visible-suggestion-redbars",
                latencyMilliseconds: 42,
                screenshotPath: "/tmp/proof-private-screenshot-redbars.png",
                metadata: [
                    "documentTitle": "proof private document title redbars",
                    "fieldKind": "multilineCompose",
                    "recipientEmail": "proof-private-recipient@example.com",
                    "subjectLine": "proof private subject redbars",
                    "visibleURL": "https://private.example/redbars"
                ]
            ),
            AutocompleteTraceEvent(
                timestamp: "2026-05-08T00:00:01Z",
                sessionID: "privacy-proof-session",
                suggestionID: "privacy-proof-one",
                type: .suggestionAccepted,
                appBundleIdentifier: "com.apple.TextEdit",
                requestMode: "wordCompletion",
                acceptedText: "proof-private-accepted-redbars",
                remainingVisibleText: "proof-private-remaining-redbars",
                outcome: "tab-word",
                metadata: [
                    "acceptanceID": "privacy-proof-acceptance",
                    "acceptedTextFingerprint": "proof-safe-hmac-shape"
                ]
            )
        ]

        let encoder = JSONEncoder()
        let jsonl = try events.map { event in
            let data = try encoder.encode(event)
            return String(decoding: data, as: UTF8.self)
        }
        .joined(separator: "\n")
        .appending("\n")

        try jsonl.write(to: traceURL, atomically: true, encoding: .utf8)
    }

    private static func failIfExportContainsPrivateSentinels(_ exportURL: URL) throws {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: exportURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw ProofError.exportMissing
        }

        for case let fileURL as URL in enumerator {
            let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            guard resourceValues.isRegularFile == true else {
                continue
            }

            let contents = try String(contentsOf: fileURL, encoding: .utf8)
            if let leaked = privateSentinels.first(where: contents.contains) {
                throw ProofError.privateSentinelFound(fileURL.path, leaked)
            }
        }
    }

    private static func writeProofManifest(to outputURL: URL, exportURL: URL) throws {
        let manifest: [String: String] = [
            "generatedAt": ISO8601DateFormatter().string(from: Date()),
            "sourceBinary": CommandLine.arguments.first ?? "unknown",
            "privacyExport": exportURL.path,
            "rawProofInputRetained": "false",
            "rawTextIncludedInDefaultArtifact": "false"
        ]

        let data = try JSONSerialization.data(
            withJSONObject: manifest,
            options: [.prettyPrinted, .sortedKeys]
        )
        try data.write(to: outputURL.appendingPathComponent("proof-manifest.json"), options: .atomic)
    }
}

private enum ProofError: Error, CustomStringConvertible {
    case exportMissing
    case privateSentinelFound(String, String)

    var description: String {
        switch self {
        case .exportMissing:
            "redacted privacy export was not created"
        case let .privateSentinelFound(path, sentinel):
            "private sentinel leaked into \(path): \(sentinel)"
        }
    }
}
