import CryptoKit
import Foundation

public enum LabTaskmasterAdapter {
    public static func loadScenarios(
        from sourceURL: URL,
        descriptor: LabCorpusDescriptor = LabCorpusRegistry.taskmaster1,
        limit: Int
    ) throws -> [LabScenario] {
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw LabCorpusError.missingSource(descriptor.displayName)
        }
        let data = try Data(contentsOf: sourceURL, options: [.mappedIfSafe])
        if let expected = descriptor.expectedSHA256,
           sha256(data) != expected {
            throw LabCorpusError.digestMismatch(descriptor.displayName)
        }

        let dialogues = try JSONDecoder().decode([TaskmasterDialogue].self, from: data)
            .sorted { stableDigest($0.conversationID) < stableDigest($1.conversationID) }
        var scenarios: [LabScenario] = []
        var signatures = Set<String>()
        scenarios.reserveCapacity(limit)

        for dialogue in dialogues {
            guard scenarios.count < max(0, limit),
                  let scenario = scenario(from: dialogue, descriptor: descriptor) else { continue }
            let signature = scenarioSignature(scenario)
            guard signatures.insert(signature).inserted else { continue }
            scenarios.append(scenario)
        }

        guard scenarios.count == max(0, limit) else {
            throw LabCorpusError.insufficientEligibleSituations(
                expected: max(0, limit),
                actual: scenarios.count
            )
        }
        return scenarios
    }

    private static func scenario(
        from dialogue: TaskmasterDialogue,
        descriptor: LabCorpusDescriptor
    ) -> LabScenario? {
        let cleaned = dialogue.utterances.map {
            CleanTurn(index: $0.index, speaker: $0.speaker, text: clean($0.text))
        }
        let eligible = cleaned.indices.filter { index in
            guard index > 0 else { return false }
            let text = cleaned[index].text
            return text.count >= 12
                && text.count <= 280
                && text.split(whereSeparator: \.isWhitespace).count >= 4
                && splitFirstWord(text) != nil
        }
        guard !eligible.isEmpty else { return nil }
        let selector = stableInteger(dialogue.conversationID) % eligible.count
        let targetIndex = eligible[selector]
        let target = cleaned[targetIndex]
        guard let split = splitFirstWord(target.text) else { return nil }

        let prior = Array(cleaned[..<targetIndex].suffix(6))
        let normalizedTarget = normalized(target.text)
        guard !prior.contains(where: { normalized($0.text).contains(normalizedTarget) }) else {
            return nil
        }

        let root = "taskmaster-\(stableDigest("\(dialogue.conversationID):\(target.index)").prefix(20))"
        let turns = prior.map { turn in
            LabSceneTurn(
                speaker: turn.speaker == target.speaker ? .selfSpeaker : .other,
                text: turn.text
            )
        }
        let accessibility = turns.map {
            "\($0.speaker == .selfSpeaker ? "Self" : "Other"): \($0.text)"
        }.joined(separator: "\n")

        return LabScenario(
            id: root,
            category: "reply.corpus.taskmaster.\(target.speaker.lowercased())",
            partition: .development,
            tone: .friendly,
            language: "en",
            tags: ["corpus", "task-oriented", "taskmaster", "word-boundary"],
            appBundleIdentifier: "org.tilde.lab.taskmaster",
            typedContext: split.prefix,
            scene: LabScene(mode: .replying, turns: turns),
            expectation: LabExpectation(
                shouldSuggest: true,
                goldenContinuation: split.remaining,
                acceptablePrefixes: [split.remaining],
                maximumWords: 40
            ),
            evaluation: LabEvaluationMetadata(
                source: .publicCorpus,
                checkpoint: .firstWord,
                contextVariant: .structuredThread,
                temporalIntegrity: .verified,
                evidence: LabContextEvidence(accessibilityText: accessibility),
                corpusID: descriptor.id,
                rootScenarioID: root
            )
        )
    }

    private static func splitFirstWord(_ text: String) -> (prefix: String, remaining: String)? {
        guard let whitespace = text.range(of: #"\s+"#, options: .regularExpression) else {
            return nil
        }
        let prefix = String(text[..<whitespace.lowerBound])
        let remaining = String(text[whitespace.lowerBound...])
        guard !prefix.isEmpty,
              remaining.trimmingCharacters(in: .whitespacesAndNewlines).count >= 4 else {
            return nil
        }
        return (prefix, remaining)
    }

    private static func scenarioSignature(_ scenario: LabScenario) -> String {
        let context = scenario.scene?.turns.map(\.text).joined(separator: "|") ?? ""
        return stableDigest("\(normalized(context))|\(normalized(scenario.typedContext))|\(normalized(scenario.expectation.goldenContinuation ?? ""))")
    }

    private static func clean(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\u{0000}", with: "")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalized(_ value: String) -> String {
        clean(value).lowercased()
    }

    private static func stableInteger(_ value: String) -> Int {
        Int(String(stableDigest(value).prefix(8)), radix: 16) ?? 0
    }

    private static func stableDigest(_ value: String) -> String {
        sha256(Data(value.utf8))
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private struct TaskmasterDialogue: Decodable {
        let conversationID: String
        let utterances: [TaskmasterUtterance]

        private enum CodingKeys: String, CodingKey {
            case conversationID = "conversation_id"
            case utterances
        }
    }

    private struct TaskmasterUtterance: Decodable {
        let index: Int
        let speaker: String
        let text: String
    }

    private struct CleanTurn {
        let index: Int
        let speaker: String
        let text: String
    }
}
