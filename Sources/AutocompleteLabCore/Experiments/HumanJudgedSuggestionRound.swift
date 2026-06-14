public enum HumanJudgedSuggestionWinner: String, Equatable, Sendable {
    case left
    case right
    case tie
    case neither
}

public struct HumanJudgedSuggestionCandidate: Equatable, Sendable {
    public let id: String
    public let visibleText: String

    public init(id: String, visibleText: String) {
        self.id = id
        self.visibleText = visibleText
    }
}

public struct HumanJudgedSuggestionPairSeed: Equatable, Sendable {
    public let pairID: String
    public let caseID: String
    public let textBeforeCursor: String
    public let firstCandidate: HumanJudgedSuggestionCandidate
    public let secondCandidate: HumanJudgedSuggestionCandidate

    public init(
        pairID: String,
        caseID: String,
        textBeforeCursor: String,
        firstCandidate: HumanJudgedSuggestionCandidate,
        secondCandidate: HumanJudgedSuggestionCandidate
    ) {
        self.pairID = pairID
        self.caseID = caseID
        self.textBeforeCursor = textBeforeCursor
        self.firstCandidate = firstCandidate
        self.secondCandidate = secondCandidate
    }
}

public struct HumanJudgedSuggestionRoundItem: Equatable, Sendable {
    public let itemID: String
    public let caseID: String
    public let textBeforeCursor: String
    public let leftSuggestion: String
    public let rightSuggestion: String

    public init(
        itemID: String,
        caseID: String,
        textBeforeCursor: String,
        leftSuggestion: String,
        rightSuggestion: String
    ) {
        self.itemID = itemID
        self.caseID = caseID
        self.textBeforeCursor = textBeforeCursor
        self.leftSuggestion = leftSuggestion
        self.rightSuggestion = rightSuggestion
    }
}

public struct HumanJudgedSuggestionRoundKeyRow: Equatable, Sendable {
    public let itemID: String
    public let pairID: String
    public let leftCandidateID: String
    public let rightCandidateID: String

    public init(
        itemID: String,
        pairID: String,
        leftCandidateID: String,
        rightCandidateID: String
    ) {
        self.itemID = itemID
        self.pairID = pairID
        self.leftCandidateID = leftCandidateID
        self.rightCandidateID = rightCandidateID
    }
}

public struct HumanJudgedSuggestionJudgmentRow: Equatable, Sendable {
    public let itemID: String
    public let winner: HumanJudgedSuggestionWinner?
    public let reasonTags: [String]
    public let notes: String

    public init(
        itemID: String,
        winner: HumanJudgedSuggestionWinner?,
        reasonTags: [String],
        notes: String
    ) {
        self.itemID = itemID
        self.winner = winner
        self.reasonTags = reasonTags
        self.notes = notes
    }
}

public struct HumanJudgedSuggestionRound: Equatable, Sendable {
    public static let defaultPairCount = 50

    public let items: [HumanJudgedSuggestionRoundItem]
    public let answerKey: [HumanJudgedSuggestionRoundKeyRow]
    public let blankJudgments: [HumanJudgedSuggestionJudgmentRow]

    public init(
        items: [HumanJudgedSuggestionRoundItem],
        answerKey: [HumanJudgedSuggestionRoundKeyRow],
        blankJudgments: [HumanJudgedSuggestionJudgmentRow]
    ) {
        self.items = items
        self.answerKey = answerKey
        self.blankJudgments = blankJudgments
    }

    public var containsCompletedJudgments: Bool {
        blankJudgments.contains { judgment in
            judgment.winner != nil || !judgment.reasonTags.isEmpty || !judgment.notes.isEmpty
        }
    }

    public static func makeRound(
        from seeds: [HumanJudgedSuggestionPairSeed],
        count: Int = defaultPairCount,
        seed: UInt64 = 4
    ) throws -> HumanJudgedSuggestionRound {
        guard count > 0 else {
            throw HumanJudgedSuggestionRoundError.invalidCount(count)
        }

        try validate(seeds: seeds)

        guard seeds.count >= count else {
            throw HumanJudgedSuggestionRoundError.notEnoughPairs(
                required: count,
                available: seeds.count
            )
        }

        var random = DeterministicRandom(seed: seed)
        let selectedSeeds = Array(shuffled(seeds, using: &random).prefix(count))

        var items: [HumanJudgedSuggestionRoundItem] = []
        var answerKey: [HumanJudgedSuggestionRoundKeyRow] = []
        var blankJudgments: [HumanJudgedSuggestionJudgmentRow] = []

        for (index, pair) in selectedSeeds.enumerated() {
            let itemID = roundItemID(for: index)
            let firstGoesLeft = random.nextBool()
            let left = firstGoesLeft ? pair.firstCandidate : pair.secondCandidate
            let right = firstGoesLeft ? pair.secondCandidate : pair.firstCandidate

            items.append(HumanJudgedSuggestionRoundItem(
                itemID: itemID,
                caseID: pair.caseID,
                textBeforeCursor: pair.textBeforeCursor,
                leftSuggestion: left.visibleText,
                rightSuggestion: right.visibleText
            ))
            answerKey.append(HumanJudgedSuggestionRoundKeyRow(
                itemID: itemID,
                pairID: pair.pairID,
                leftCandidateID: left.id,
                rightCandidateID: right.id
            ))
            blankJudgments.append(HumanJudgedSuggestionJudgmentRow(
                itemID: itemID,
                winner: nil,
                reasonTags: [],
                notes: ""
            ))
        }

        return HumanJudgedSuggestionRound(
            items: items,
            answerKey: answerKey,
            blankJudgments: blankJudgments
        )
    }

    private static func validate(seeds: [HumanJudgedSuggestionPairSeed]) throws {
        var seenPairIDs = Set<String>()

        for pair in seeds {
            if pair.pairID.isBlank {
                throw HumanJudgedSuggestionRoundError.blankPairID
            }
            if !seenPairIDs.insert(pair.pairID).inserted {
                throw HumanJudgedSuggestionRoundError.duplicatePairID(pair.pairID)
            }
            if pair.caseID.isBlank || pair.textBeforeCursor.isBlank {
                throw HumanJudgedSuggestionRoundError.invalidPair(pair.pairID)
            }
            if pair.firstCandidate.id.isBlank || pair.secondCandidate.id.isBlank {
                throw HumanJudgedSuggestionRoundError.invalidPair(pair.pairID)
            }
            if pair.firstCandidate.visibleText.isBlank || pair.secondCandidate.visibleText.isBlank {
                throw HumanJudgedSuggestionRoundError.invalidPair(pair.pairID)
            }
            if pair.firstCandidate.id == pair.secondCandidate.id {
                throw HumanJudgedSuggestionRoundError.invalidPair(pair.pairID)
            }
        }
    }

    private static func shuffled<T>(
        _ values: [T],
        using random: inout DeterministicRandom
    ) -> [T] {
        guard values.count > 1 else {
            return values
        }

        var result = values
        for index in stride(from: result.count - 1, through: 1, by: -1) {
            let swapIndex = random.nextInt(upperBound: index + 1)
            if swapIndex != index {
                result.swapAt(index, swapIndex)
            }
        }
        return result
    }

    private static func roundItemID(for index: Int) -> String {
        let itemNumber = index + 1
        if itemNumber < 10 {
            return "round-00\(itemNumber)"
        }
        if itemNumber < 100 {
            return "round-0\(itemNumber)"
        }
        return "round-\(itemNumber)"
    }
}

public enum HumanJudgedSuggestionRoundError: Error, Equatable, Sendable {
    case invalidCount(Int)
    case blankPairID
    case duplicatePairID(String)
    case invalidPair(String)
    case notEnoughPairs(required: Int, available: Int)
}

private struct DeterministicRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    mutating func next() -> UInt64 {
        state = state &* 2862933555777941757 &+ 3037000493
        return state
    }

    mutating func nextBool() -> Bool {
        next() & 1 == 0
    }

    mutating func nextInt(upperBound: Int) -> Int {
        precondition(upperBound > 0)
        return Int(next() % UInt64(upperBound))
    }
}

private extension String {
    var isBlank: Bool {
        allSatisfy(\.isWhitespace)
    }
}
