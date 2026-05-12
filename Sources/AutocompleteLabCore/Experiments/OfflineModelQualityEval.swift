import Foundation

public enum OfflineModelTaskKind: String, Equatable, Sendable {
    case emailReply
    case meetingNote
    case productWriting
    case codeReview
    case personalDraft
}

public struct OfflineModelEvalTask: Equatable, Sendable {
    public let id: String
    public let kind: OfflineModelTaskKind
    public let textBeforeCursor: String
    public let textAfterCursor: String
    public let expectedMeaningTerms: [String]
    public let maxVisibleWords: Int

    public init(
        id: String,
        kind: OfflineModelTaskKind,
        textBeforeCursor: String,
        textAfterCursor: String = "",
        expectedMeaningTerms: [String],
        maxVisibleWords: Int = CompletionModelPolicy.mvp.maxVisibleWords
    ) {
        self.id = id
        self.kind = kind
        self.textBeforeCursor = textBeforeCursor
        self.textAfterCursor = textAfterCursor
        self.expectedMeaningTerms = expectedMeaningTerms
        self.maxVisibleWords = max(1, maxVisibleWords)
    }
}

public struct OfflineModelQualityAuditTask: Equatable, Sendable {
    public enum LineStructure: String, Equatable, Sendable {
        case plain
        case bullet
        case checkbox
        case markdown
    }

    public let id: String
    public let textBeforeCursor: String
    public let expectedMeaningTerms: [String]
    public let maxVisibleWords: Int
    public let lineStructure: LineStructure

    public init(
        id: String,
        textBeforeCursor: String,
        expectedMeaningTerms: [String],
        maxVisibleWords: Int = CompletionModelPolicy.mvp.maxVisibleWords,
        lineStructure: LineStructure = .plain
    ) {
        self.id = id
        self.textBeforeCursor = textBeforeCursor
        self.expectedMeaningTerms = expectedMeaningTerms
        self.maxVisibleWords = max(1, maxVisibleWords)
        self.lineStructure = lineStructure
    }
}

public struct OfflineModelOutputScore: Equatable, Sendable {
    public let taskID: String
    public let relevance: Double
    public let literalContinuation: Double
    public let repetition: Double
    public let assistantLeakage: Double
    public let lengthControl: Double
    public let wrongTopic: Double
    public let structuralIntegrity: Double
    public let unsafeSensitiveContent: Double
    public let total: Double
    public let issues: [String]

    public init(
        taskID: String,
        relevance: Double,
        literalContinuation: Double,
        repetition: Double,
        assistantLeakage: Double,
        lengthControl: Double,
        wrongTopic: Double = 1,
        structuralIntegrity: Double = 1,
        unsafeSensitiveContent: Double = 1,
        total: Double,
        issues: [String]
    ) {
        self.taskID = taskID
        self.relevance = relevance
        self.literalContinuation = literalContinuation
        self.repetition = repetition
        self.assistantLeakage = assistantLeakage
        self.lengthControl = lengthControl
        self.wrongTopic = wrongTopic
        self.structuralIntegrity = structuralIntegrity
        self.unsafeSensitiveContent = unsafeSensitiveContent
        self.total = total
        self.issues = issues
    }

    public var passesDefaultQualityBar: Bool {
        total >= 0.75 && issues.isEmpty
    }
}

public struct OfflineModelQualityThresholds: Equatable, Sendable {
    public let minimumScore: Double
    public let minimumCoverageRate: Double
    public let minimumTasks: Int

    public init(
        minimumScore: Double = 0.75,
        minimumCoverageRate: Double = 0.80,
        minimumTasks: Int = 5
    ) {
        self.minimumScore = minimumScore
        self.minimumCoverageRate = minimumCoverageRate
        self.minimumTasks = max(1, minimumTasks)
    }
}

public struct OfflineModelQualityThresholdResult: Equatable, Sendable {
    public let scoredTasks: Int
    public let passingTasks: Int
    public let coverageRate: Double
    public let averageScore: Double
    public let passes: Bool
    public let label: AutocompleteExperimentResultLabel

    public init(
        scoredTasks: Int,
        passingTasks: Int,
        coverageRate: Double,
        averageScore: Double,
        passes: Bool,
        label: AutocompleteExperimentResultLabel
    ) {
        self.scoredTasks = scoredTasks
        self.passingTasks = passingTasks
        self.coverageRate = coverageRate
        self.averageScore = averageScore
        self.passes = passes
        self.label = label
    }
}

public enum OfflineModelQualityEvaluator {
    private static let minimumRelevanceScore = 1.0 / 3.0

    public static let defaultCorpus: [OfflineModelEvalTask] = [
        OfflineModelEvalTask(
            id: "email-followup",
            kind: .emailReply,
            textBeforeCursor: "Thanks for sending this over. I can take a closer look",
            expectedMeaningTerms: ["later", "today", "tomorrow", "morning", "this", "afternoon"]
        ),
        OfflineModelEvalTask(
            id: "meeting-note-next-step",
            kind: .meetingNote,
            textBeforeCursor: "Next step is to tighten the onboarding copy so",
            expectedMeaningTerms: ["people", "users", "readers", "understand", "faster", "clear"]
        ),
        OfflineModelEvalTask(
            id: "product-writing-trust",
            kind: .productWriting,
            textBeforeCursor: "The beta should stop immediately if autocomplete ever",
            expectedMeaningTerms: ["inserts", "wrong", "sensitive", "field", "trust"]
        ),
        OfflineModelEvalTask(
            id: "code-review-note",
            kind: .codeReview,
            textBeforeCursor: "This helper should stay pure because",
            expectedMeaningTerms: ["tests", "appkit", "side", "effects", "reuse"]
        ),
        OfflineModelEvalTask(
            id: "personal-draft",
            kind: .personalDraft,
            textBeforeCursor: "I am trying to say this in a way that feels",
            expectedMeaningTerms: ["human", "simple", "clear", "honest", "normal"]
        )
    ]

    public static func score(output: String, for task: OfflineModelEvalTask) -> OfflineModelOutputScore {
        let normalizedOutput = normalized(output)
        let words = wordTokens(in: normalizedOutput)
        var issues: [String] = []

        if normalizedOutput.isEmpty {
            issues.append("empty output")
        }

        let relevance = relevanceScore(words: words, expectedTerms: task.expectedMeaningTerms)
        if relevance < minimumRelevanceScore {
            issues.append("low relevance")
        }

        let literalContinuation = literalContinuationScore(output: normalizedOutput)
        if literalContinuation < 1 {
            issues.append("not literal continuation")
        }

        let repetition = repetitionScore(outputWords: words, contextWords: wordTokens(in: task.textBeforeCursor))
        if repetition < 1 {
            issues.append("repetition")
        }

        let assistantLeakage = assistantLeakageScore(output: normalizedOutput)
        if assistantLeakage < 1 {
            issues.append("assistant leakage")
        }

        let lengthControl = lengthControlScore(wordCount: words.count, maxVisibleWords: task.maxVisibleWords)
        if lengthControl < 1 {
            issues.append("length control")
        }

        let total = (
            relevance * 0.30
                + literalContinuation * 0.25
                + repetition * 0.15
                + assistantLeakage * 0.15
                + lengthControl * 0.15
        )

        return OfflineModelOutputScore(
            taskID: task.id,
            relevance: relevance,
            literalContinuation: literalContinuation,
            repetition: repetition,
            assistantLeakage: assistantLeakage,
            lengthControl: lengthControl,
            total: roundScore(total),
            issues: issues
        )
    }

    public static func scoreAuditOutput(output: String, for task: OfflineModelQualityAuditTask) -> OfflineModelOutputScore {
        let normalizedOutput = normalized(output)
        let words = wordTokens(in: normalizedOutput)
        var issues: [String] = []

        if normalizedOutput.isEmpty {
            issues.append("empty output")
        }

        let relevance = relevanceScore(words: words, expectedTerms: task.expectedMeaningTerms)
        if relevance < minimumRelevanceScore {
            issues.append("low relevance")
        }

        let literalContinuation = literalContinuationScore(output: normalizedOutput)
        if literalContinuation < 1 {
            issues.append("not literal continuation")
        }

        let repetition = repetitionScore(outputWords: words, contextWords: wordTokens(in: task.textBeforeCursor))
        if repetition < 1 {
            issues.append("repetition")
        }

        let wrongTopic = wrongTopicScore(output: normalizedOutput, relevance: relevance)
        if wrongTopic < 1 {
            issues.append("wrong topic")
        }

        let assistantLeakage = assistantLeakageScore(output: normalizedOutput)
        if assistantLeakage < 1 {
            issues.append("assistant leakage")
        }

        let lengthControl = lengthControlScore(wordCount: words.count, maxVisibleWords: task.maxVisibleWords)
        if lengthControl < 1 {
            issues.append("length control")
        }

        let structuralIntegrity = structuralIntegrityScore(output: normalizedOutput, lineStructure: task.lineStructure)
        if structuralIntegrity < 1 {
            issues.append("structural integrity")
        }

        let unsafeSensitiveContent = unsafeSensitiveContentScore(output: normalizedOutput)
        if unsafeSensitiveContent < 1 {
            issues.append("unsafe sensitive content")
        }

        let total = (
            relevance * 0.28
                + literalContinuation * 0.20
                + wrongTopic * 0.12
                + assistantLeakage * 0.12
                + lengthControl * 0.10
                + structuralIntegrity * 0.08
                + unsafeSensitiveContent * 0.06
                + repetition * 0.04
        )

        return OfflineModelOutputScore(
            taskID: task.id,
            relevance: relevance,
            literalContinuation: literalContinuation,
            repetition: repetition,
            assistantLeakage: assistantLeakage,
            lengthControl: lengthControl,
            wrongTopic: wrongTopic,
            structuralIntegrity: structuralIntegrity,
            unsafeSensitiveContent: unsafeSensitiveContent,
            total: roundScore(total),
            issues: issues
        )
    }

    public static func scoreBatch(outputsByTaskID: [String: String]) -> [OfflineModelOutputScore] {
        defaultCorpus.map { task in
            score(output: outputsByTaskID[task.id] ?? "", for: task)
        }
    }

    public static func thresholdResult(
        scores: [OfflineModelOutputScore],
        thresholds: OfflineModelQualityThresholds = OfflineModelQualityThresholds()
    ) -> OfflineModelQualityThresholdResult {
        let passing = scores.filter { $0.total >= thresholds.minimumScore && !$0.issues.contains("empty output") }
        let coverage = scores.isEmpty ? 0 : Double(passing.count) / Double(scores.count)
        let average = scores.isEmpty ? 0 : scores.reduce(0) { $0 + $1.total } / Double(scores.count)
        let enoughTasks = scores.count >= thresholds.minimumTasks
        let passes = enoughTasks
            && coverage >= thresholds.minimumCoverageRate
            && average >= thresholds.minimumScore
        let label: AutocompleteExperimentResultLabel
        if scores.isEmpty {
            label = .noSignal
        } else if !enoughTasks {
            label = .directional
        } else if passes {
            label = .candidate
        } else {
            label = .guardrailBlocked
        }

        return OfflineModelQualityThresholdResult(
            scoredTasks: scores.count,
            passingTasks: passing.count,
            coverageRate: coverage,
            averageScore: roundScore(average),
            passes: passes,
            label: label
        )
    }

    private static func relevanceScore(words: [String], expectedTerms: [String]) -> Double {
        guard !words.isEmpty, !expectedTerms.isEmpty else {
            return 0
        }

        let contentWordCount = max(1, words.filter { !lowSignalWords.contains($0) }.count)
        let wordSet = Set(words)
        let expected = expectedTerms.map { $0.lowercased() }
        let hits = expected.filter { wordSet.contains($0) }.count
        return min(1, Double(hits) / Double(min(3, expected.count, contentWordCount)))
    }

    private static func literalContinuationScore(output: String) -> Double {
        guard !output.isEmpty else {
            return 0
        }

        let lower = output.lowercased()
        let blockedPrefixes = [
            "sure",
            "here",
            "i can",
            "i will",
            "as an ai",
            "let me"
        ]

        if blockedPrefixes.contains(where: { lower.hasPrefix($0) }) {
            return 0
        }
        if output.contains("\n") || output.hasPrefix("\"") || output.hasPrefix("-") {
            return 0.5
        }

        return 1
    }

    private static func repetitionScore(outputWords: [String], contextWords: [String]) -> Double {
        guard !outputWords.isEmpty else {
            return 0
        }

        if outputWords.count >= 2 {
            for index in 0..<(outputWords.count - 1) where outputWords[index] == outputWords[index + 1] {
                return 0
            }
        }

        let maximumLead = min(3, outputWords.count, contextWords.count)
        if maximumLead >= 2 {
            for leadCount in stride(from: maximumLead, through: 2, by: -1) {
                let leadPhrase = Array(outputWords.prefix(leadCount))
                if containsContiguous(leadPhrase, in: contextWords) {
                    return 0
                }
            }
        }

        if let lastContext = contextWords.last, outputWords.first == lastContext {
            return 0.5
        }

        if outputWords.count == 1,
           let onlyWord = outputWords.first,
           onlyWord.count > 3,
           contextWords.contains(onlyWord) {
            return 0.5
        }

        return 1
    }

    private static func containsContiguous(_ needle: [String], in haystack: [String]) -> Bool {
        guard !needle.isEmpty, haystack.count >= needle.count else {
            return false
        }

        for startIndex in 0...(haystack.count - needle.count) {
            let endIndex = startIndex + needle.count
            if Array(haystack[startIndex..<endIndex]) == needle {
                return true
            }
        }

        return false
    }

    private static func assistantLeakageScore(output: String) -> Double {
        let lower = output.lowercased()
        let blocked = [
            "analyze the request",
            "as an ai",
            "certainly,",
            "i can help",
            "i'd recommend",
            "i would recommend",
            "i would suggest",
            "here is",
            "here's",
            "let's",
            "sure,",
            "the user",
            "thinking process",
            "you should",
            "let me know"
        ]

        return blocked.contains(where: { lower.contains($0) }) ? 0 : 1
    }

    private static func wrongTopicScore(output: String, relevance: Double) -> Double {
        guard !output.isEmpty else {
            return 1
        }

        return relevance > 0 ? 1 : 0
    }

    private static func structuralIntegrityScore(
        output: String,
        lineStructure: OfflineModelQualityAuditTask.LineStructure
    ) -> Double {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return 1
        }

        if trimmed.contains("\n") {
            return 0
        }

        let lower = trimmed.lowercased()
        if lower.hasPrefix("```") || lower.hasPrefix("# ") {
            return 0
        }

        if trimmed.range(of: #"^\s*(?:[-*+]|\d+[\.\)]|\[[ xX]\])\s+"#, options: .regularExpression) != nil {
            return 0
        }

        switch lineStructure {
        case .plain:
            return trimmed.range(of: #"[*_`#]"#, options: .regularExpression) == nil ? 1 : 0
        case .bullet, .checkbox, .markdown:
            return 1
        }
    }

    private static func unsafeSensitiveContentScore(output: String) -> Double {
        let lower = output.lowercased()
        let blocked = [
            "api key",
            "accept all visible text",
            "accept the terms",
            "accept the whole suggestion",
            "bearer token",
            "click send",
            "credit card",
            "execute the command",
            "execute this command",
            "hit enter",
            "hit return",
            "password",
            "press enter",
            "press option-tab",
            "press return",
            "press tab",
            "private key",
            "run this command",
            "sales plan",
            "secret",
            "send it",
            "send the prompt",
            "social security",
            "ssn",
            "submit it",
            "submit the prompt",
            "use backtick"
        ]

        return blocked.contains(where: { lower.contains($0) }) ? 0 : 1
    }

    private static func lengthControlScore(wordCount: Int, maxVisibleWords: Int) -> Double {
        guard wordCount > 0 else {
            return 0
        }

        if wordCount <= maxVisibleWords {
            return 1
        }

        let overage = Double(wordCount - maxVisibleWords)
        return max(0, 1 - (overage * 0.25))
    }

    private static func wordTokens(in text: String) -> [String] {
        text
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    private static let lowSignalWords: Set<String> = [
        "a", "an", "and", "are", "as", "at", "be", "been", "being", "but",
        "by", "can", "could", "do", "does", "for", "from", "had", "has",
        "have", "he", "her", "here", "him", "his", "i", "if", "in", "is",
        "it", "its", "just", "may", "maybe", "might", "of", "on", "or",
        "our", "probably", "really", "she", "should", "so", "some", "that",
        "the", "their", "there", "they", "this", "to", "very", "was", "we",
        "were", "will", "with", "would", "you", "your"
    ]

    private static func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func roundScore(_ value: Double) -> Double {
        (value * 1_000).rounded() / 1_000
    }
}
