import Foundation

public enum SuggestionControlState: Equatable, Sendable {
    case running
    case paused

    public init(isPaused: Bool) {
        self = isPaused ? .paused : .running
    }

    public var isPaused: Bool {
        self == .paused
    }

    public var statusName: String {
        switch self {
        case .running:
            "running"
        case .paused:
            "paused"
        }
    }

    public var toggleTitle: String {
        switch self {
        case .running:
            "Pause Suggestions"
        case .paused:
            "Resume Suggestions"
        }
    }
}

public enum SuggestionControlBlockReason: String, Equatable, Sendable {
    case globalPause = "global-pause"

    public var decisionText: String {
        switch self {
        case .globalPause:
            "Paused"
        }
    }

    public var hideReason: String {
        rawValue
    }
}

public enum SuggestionControlDecision: Equatable, Sendable {
    case allowed
    case blocked(SuggestionControlBlockReason)

    public var isAllowed: Bool {
        switch self {
        case .allowed:
            true
        case .blocked:
            false
        }
    }
}

public struct SuggestionControlTransition: Equatable, Sendable {
    public let previousState: SuggestionControlState
    public let nextState: SuggestionControlState

    public init(previousState: SuggestionControlState, nextState: SuggestionControlState) {
        self.previousState = previousState
        self.nextState = nextState
    }

    public var decisionText: String {
        switch nextState {
        case .running:
            "Ready: resumed"
        case .paused:
            "Paused"
        }
    }

    public var shouldClearFocusedField: Bool {
        nextState == .paused
    }

    public var shouldStopKeyboardCapture: Bool {
        nextState == .paused
    }

    public var cleanupReason: SuggestionControlBlockReason? {
        nextState == .paused ? .globalPause : nil
    }
}

public struct SuggestionControlPolicy: Equatable, Sendable {
    public init() {}

    public func state(isPaused: Bool) -> SuggestionControlState {
        SuggestionControlState(isPaused: isPaused)
    }

    public func startupState(persistedIsPaused: Bool?) -> SuggestionControlState {
        // A fresh install starts running: the product is useless if the first
        // experience is a menu bar icon that silently does nothing.
        SuggestionControlState(isPaused: persistedIsPaused ?? false)
    }

    public func suggestionAvailability(for state: SuggestionControlState) -> SuggestionControlDecision {
        switch state {
        case .running:
            .allowed
        case .paused:
            .blocked(.globalPause)
        }
    }

    public func toggle(_ state: SuggestionControlState) -> SuggestionControlTransition {
        switch state {
        case .running:
            SuggestionControlTransition(previousState: state, nextState: .paused)
        case .paused:
            SuggestionControlTransition(previousState: state, nextState: .running)
        }
    }
}
