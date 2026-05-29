import Foundation

public struct TypingBurstSample: Equatable, Sendable {
    public let timestampMilliseconds: Int
    public let insertedCharacterCount: Int

    public init(timestampMilliseconds: Int, insertedCharacterCount: Int) {
        self.timestampMilliseconds = timestampMilliseconds
        self.insertedCharacterCount = max(0, insertedCharacterCount)
    }
}

public struct TypingBurstState: Equatable, Sendable {
    public fileprivate(set) var samples: [TypingBurstSample]

    public init(samples: [TypingBurstSample] = []) {
        self.samples = samples
    }

    public mutating func reset() {
        samples.removeAll(keepingCapacity: true)
    }
}

public enum TypingBurstDecision: Equatable, Sendable {
    case idle
    case burst(insertedCharacterCount: Int, eventCount: Int)

    public var shouldSuppressSuggestions: Bool {
        switch self {
        case .idle:
            false
        case .burst:
            true
        }
    }

    public var shouldSuppressPhraseContinuation: Bool {
        shouldSuppressSuggestions
    }

    public func shouldSuppress(requestMode: CompletionRequestMode?) -> Bool {
        guard let requestMode else {
            return false
        }

        return requestMode.isContinuation && shouldSuppressPhraseContinuation
    }

    public var traceMetadata: [String: String] {
        switch self {
        case .idle:
            return [
                "typingBurst": "false"
            ]
        case let .burst(insertedCharacterCount, eventCount):
            return [
                "typingBurst": "true",
                "typingBurstInsertedCharacters": String(insertedCharacterCount),
                "typingBurstEvents": String(eventCount)
            ]
        }
    }
}

public struct TypingBurstPolicy: Equatable, Sendable {
    public let windowMilliseconds: Int
    public let minimumInsertedCharacters: Int
    public let minimumEvents: Int
    public let maximumSingleChangeCharacters: Int

    public init(
        windowMilliseconds: Int = 1_100,
        minimumInsertedCharacters: Int = 6,
        minimumEvents: Int = 4,
        maximumSingleChangeCharacters: Int = 4
    ) {
        self.windowMilliseconds = max(1, windowMilliseconds)
        self.minimumInsertedCharacters = max(1, minimumInsertedCharacters)
        self.minimumEvents = max(1, minimumEvents)
        self.maximumSingleChangeCharacters = max(1, maximumSingleChangeCharacters)
    }

    public func observe(
        previousTextBeforeCursor: String?,
        currentTextBeforeCursor: String,
        nowMilliseconds: Int,
        state: inout TypingBurstState
    ) -> TypingBurstDecision {
        guard let previousTextBeforeCursor,
              currentTextBeforeCursor.hasPrefix(previousTextBeforeCursor),
              currentTextBeforeCursor != previousTextBeforeCursor else {
            state.reset()
            return .idle
        }

        let insertedCount = currentTextBeforeCursor.count - previousTextBeforeCursor.count
        guard insertedCount > 0, insertedCount <= maximumSingleChangeCharacters else {
            state.reset()
            return .idle
        }

        state.samples.append(
            TypingBurstSample(
                timestampMilliseconds: nowMilliseconds,
                insertedCharacterCount: insertedCount
            )
        )
        state.samples = state.samples.filter {
            nowMilliseconds - $0.timestampMilliseconds <= windowMilliseconds
        }

        let insertedInWindow = state.samples.reduce(0) { $0 + $1.insertedCharacterCount }
        guard state.samples.count >= minimumEvents,
              insertedInWindow >= minimumInsertedCharacters else {
            return .idle
        }

        return .burst(
            insertedCharacterCount: insertedInWindow,
            eventCount: state.samples.count
        )
    }
}
