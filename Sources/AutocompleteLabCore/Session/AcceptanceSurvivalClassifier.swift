import Foundation

public enum AcceptanceSurvivalCheckpoint: String, Codable, Equatable, Sendable {
    case twoSeconds = "2s"
    case tenSeconds = "10s"
    case thirtySeconds = "30s"
    case fieldBlur

    public var isStrongMetricCheckpoint: Bool {
        self == .tenSeconds || self == .fieldBlur
    }

    public var isFinalMetricCheckpoint: Bool {
        self == .thirtySeconds || self == .fieldBlur
    }
}

public enum AcceptanceSurvivalClass: String, Codable, Equatable, Sendable {
    case exactKept
    case lightlyEditedKept
    case partiallyKept
    case rejectedAfterAccept

    public var countsAsKept: Bool {
        switch self {
        case .exactKept, .lightlyEditedKept, .partiallyKept:
            true
        case .rejectedAfterAccept:
            false
        }
    }
}

public struct AcceptanceSurvivalMeasurement: Equatable, Sendable {
    public let checkpoint: AcceptanceSurvivalCheckpoint
    public let tokenRecall: Double
    public let normalizedEditDistance: Double
    public let firstEditDelayMilliseconds: Int?
    public let survivalClass: AcceptanceSurvivalClass
    public let deletedWithinTwoSeconds: Bool

    public init(
        checkpoint: AcceptanceSurvivalCheckpoint,
        tokenRecall: Double,
        normalizedEditDistance: Double,
        firstEditDelayMilliseconds: Int? = nil,
        survivalClass: AcceptanceSurvivalClass,
        deletedWithinTwoSeconds: Bool = false
    ) {
        self.checkpoint = checkpoint
        self.tokenRecall = tokenRecall
        self.normalizedEditDistance = normalizedEditDistance
        self.firstEditDelayMilliseconds = firstEditDelayMilliseconds
        self.survivalClass = survivalClass
        self.deletedWithinTwoSeconds = deletedWithinTwoSeconds
    }

    public var isStrongAcceptedAndKept: Bool {
        checkpoint.isStrongMetricCheckpoint
            && tokenRecall >= 0.7
            && !deletedWithinTwoSeconds
    }

    public var isFinalAcceptedAndKept: Bool {
        checkpoint.isFinalMetricCheckpoint
            && tokenRecall >= 0.5
    }

    public var traceMetadata: [String: String] {
        var metadata = [
            "checkpoint": checkpoint.rawValue,
            "tokenRecall": Self.format(tokenRecall),
            "normalizedEditDistance": Self.format(normalizedEditDistance),
            "survivalClass": survivalClass.rawValue,
            "deletedWithinTwoSeconds": String(deletedWithinTwoSeconds),
            "strongAcceptedAndKept": String(isStrongAcceptedAndKept),
            "finalAcceptedAndKept": String(isFinalAcceptedAndKept)
        ]

        if let firstEditDelayMilliseconds {
            metadata["firstEditDelayMs"] = String(firstEditDelayMilliseconds)
        }

        return metadata
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.3f", value)
    }
}

public struct AcceptanceSurvivalClassifier: Equatable, Sendable {
    public init() {}

    public func classify(
        acceptedText: String,
        currentTextWindow: String,
        checkpoint: AcceptanceSurvivalCheckpoint,
        firstEditDelayMilliseconds: Int? = nil,
        deletedWithinTwoSeconds: Bool = false
    ) -> AcceptanceSurvivalMeasurement {
        let acceptedTokens = Self.looseTokens(in: acceptedText)
        let currentTokens = Self.looseTokens(in: currentTextWindow)
        let tokenRecall = Self.tokenRecall(
            acceptedTokens: acceptedTokens,
            currentTokens: currentTokens
        )
        let editDistance = Self.bestNormalizedEditDistance(
            acceptedTokens: acceptedTokens,
            currentTokens: currentTokens
        )
        let survivalClass = Self.survivalClass(
            tokenRecall: tokenRecall,
            normalizedEditDistance: editDistance
        )

        return AcceptanceSurvivalMeasurement(
            checkpoint: checkpoint,
            tokenRecall: tokenRecall,
            normalizedEditDistance: editDistance,
            firstEditDelayMilliseconds: firstEditDelayMilliseconds,
            survivalClass: survivalClass,
            deletedWithinTwoSeconds: deletedWithinTwoSeconds
        )
    }

    public func classifyAroundExpectedInsertion(
        acceptedText: String,
        currentFullText: String,
        expectedInsertionUTF16Offset: Int,
        checkpoint: AcceptanceSurvivalCheckpoint,
        firstEditDelayMilliseconds: Int? = nil,
        deletedWithinTwoSeconds: Bool = false,
        radius: Int = 160
    ) -> AcceptanceSurvivalMeasurement {
        classify(
            acceptedText: acceptedText,
            currentTextWindow: Self.localTextWindow(
                in: currentFullText,
                expectedInsertionUTF16Offset: expectedInsertionUTF16Offset,
                acceptedTextUTF16Length: acceptedText.utf16.count,
                radius: radius
            ),
            checkpoint: checkpoint,
            firstEditDelayMilliseconds: firstEditDelayMilliseconds,
            deletedWithinTwoSeconds: deletedWithinTwoSeconds
        )
    }

    public static func localTextWindow(
        in text: String,
        expectedInsertionUTF16Offset: Int,
        acceptedTextUTF16Length: Int,
        radius: Int = 160
    ) -> String {
        let safeStart = max(0, expectedInsertionUTF16Offset - radius)
        let safeEnd = min(
            text.utf16.count,
            max(expectedInsertionUTF16Offset, expectedInsertionUTF16Offset + acceptedTextUTF16Length) + radius
        )
        let startIndex = String.Index(utf16Offset: safeStart, in: text)
        let endIndex = String.Index(utf16Offset: max(safeStart, safeEnd), in: text)
        return String(text[startIndex..<endIndex])
    }

    public static func looseTokens(in text: String) -> [String] {
        var normalized = ""
        for scalar in text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                normalized.unicodeScalars.append(scalar)
            } else {
                normalized.append(" ")
            }
        }

        return normalized
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
    }

    public static func tokenRecall(
        acceptedTokens: [String],
        currentTokens: [String]
    ) -> Double {
        guard !acceptedTokens.isEmpty else {
            return 0
        }

        guard !currentTokens.isEmpty else {
            return 0
        }

        let keptTokenCount = longestCommonSubsequenceLength(
            acceptedTokens,
            currentTokens
        )

        return Double(keptTokenCount) / Double(acceptedTokens.count)
    }

    private static func survivalClass(
        tokenRecall: Double,
        normalizedEditDistance: Double
    ) -> AcceptanceSurvivalClass {
        if tokenRecall >= 1.0 && normalizedEditDistance <= 0.05 {
            return .exactKept
        }

        if tokenRecall >= 0.8 {
            return .lightlyEditedKept
        }

        if tokenRecall >= 0.5 {
            return .partiallyKept
        }

        return .rejectedAfterAccept
    }

    private static func bestNormalizedEditDistance(
        acceptedTokens: [String],
        currentTokens: [String]
    ) -> Double {
        guard !acceptedTokens.isEmpty else {
            return 1
        }

        guard !currentTokens.isEmpty else {
            return 1
        }

        let accepted = acceptedTokens.joined(separator: " ")
        let acceptedCount = acceptedTokens.count
        let minWindow = max(1, acceptedCount - 2)
        let maxWindow = min(currentTokens.count, acceptedCount + 2)
        var bestDistance = normalizedEditDistance(accepted, currentTokens.joined(separator: " "))

        if minWindow <= maxWindow {
            for size in minWindow...maxWindow {
                guard size <= currentTokens.count else {
                    continue
                }

                for start in 0...(currentTokens.count - size) {
                    let window = currentTokens[start..<(start + size)].joined(separator: " ")
                    bestDistance = min(bestDistance, normalizedEditDistance(accepted, window))
                }
            }
        }

        return bestDistance
    }

    private static func normalizedEditDistance(_ lhs: String, _ rhs: String) -> Double {
        let lhsCharacters = Array(lhs)
        let rhsCharacters = Array(rhs)
        let longestLength = max(lhsCharacters.count, rhsCharacters.count)
        guard longestLength > 0 else {
            return 0
        }

        return Double(editDistance(lhsCharacters, rhsCharacters)) / Double(longestLength)
    }

    private static func editDistance(_ lhs: [Character], _ rhs: [Character]) -> Int {
        if lhs.isEmpty {
            return rhs.count
        }

        if rhs.isEmpty {
            return lhs.count
        }

        var previous = Array(0...rhs.count)
        var current = Array(repeating: 0, count: rhs.count + 1)

        for lhsIndex in 1...lhs.count {
            current[0] = lhsIndex

            for rhsIndex in 1...rhs.count {
                let substitutionCost = lhs[lhsIndex - 1] == rhs[rhsIndex - 1] ? 0 : 1
                current[rhsIndex] = min(
                    previous[rhsIndex] + 1,
                    current[rhsIndex - 1] + 1,
                    previous[rhsIndex - 1] + substitutionCost
                )
            }

            swap(&previous, &current)
        }

        return previous[rhs.count]
    }

    private static func longestCommonSubsequenceLength(
        _ lhs: [String],
        _ rhs: [String]
    ) -> Int {
        var previous = Array(repeating: 0, count: rhs.count + 1)
        var current = Array(repeating: 0, count: rhs.count + 1)

        for lhsIndex in 1...lhs.count {
            for rhsIndex in 1...rhs.count {
                if lhs[lhsIndex - 1] == rhs[rhsIndex - 1] {
                    current[rhsIndex] = previous[rhsIndex - 1] + 1
                } else {
                    current[rhsIndex] = max(previous[rhsIndex], current[rhsIndex - 1])
                }
            }

            swap(&previous, &current)
            current = Array(repeating: 0, count: rhs.count + 1)
        }

        return previous[rhs.count]
    }
}
