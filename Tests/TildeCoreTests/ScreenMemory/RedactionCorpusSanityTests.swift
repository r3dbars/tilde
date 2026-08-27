import Foundation
import Testing
@testable import TildeCore

/// Not part of the blocking eval bar (that's `script/redaction_eval.py`,
/// which measures the shipped end-to-end path including the model layer).
/// This is a fast, CI-friendly sanity check that the committed synthetic
/// corpus's `structured_secrets` are actually well-formed enough for
/// `SecretRules` to catch — i.e. the corpus generator didn't produce a
/// Luhn-invalid card number or a malformed IBAN that would silently make
/// the Python eval's structured-recall number meaningless. If this test
/// fails, the corpus (or the generator) is broken, not `SecretRules`.
@Suite("Redaction corpus sanity")
struct RedactionCorpusSanityTests {
    private struct Record: Decodable {
        let id: String
        let text: String
        let structuredSecrets: [String]

        enum CodingKeys: String, CodingKey {
            case id, text
            case structuredSecrets = "structured_secrets"
        }
    }

    private func loadCorpus() throws -> [Record] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // ScreenMemory
            .deletingLastPathComponent() // TildeCoreTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // repo root
            .appendingPathComponent("script/testdata/redaction_eval_corpus.jsonl")
        let contents = try String(contentsOf: url, encoding: .utf8)
        let decoder = JSONDecoder()
        return try contents.split(separator: "\n").map { line in
            try decoder.decode(Record.self, from: Data(line.utf8))
        }
    }

    @Test("Every planted structured secret is fully removed by SecretRules.scrub")
    func everyStructuredSecretIsCaught() throws {
        let records = try loadCorpus()
        #expect(!records.isEmpty)
        var misses: [(id: String, secret: String)] = []
        for record in records {
            let (clean, _) = SecretRules.scrub(record.text)
            for secret in record.structuredSecrets where clean.contains(secret) {
                misses.append((record.id, secret))
            }
        }
        #expect(misses.isEmpty, "Rules layer missed: \(misses)")
    }

    @Test("Corpus is non-trivial: has both structured and unstructured secrets across records")
    func corpusHasBothKinds() throws {
        let records = try loadCorpus()
        #expect(records.contains { !$0.structuredSecrets.isEmpty })
        #expect(records.count >= 20)
    }
}
