import Foundation

public enum FocusedTextSignalMode: String, Equatable, Sendable {
    case eventDriven
    case polling
    case hybrid
}

public enum FocusedTextSignalObservation: Equatable, Sendable {
    case eventConfirmedRead
    case keyDown(axNotificationObservedSinceLastKeyDown: Bool)
}

public struct FocusedTextSignalModeTransition: Equatable, Sendable {
    public let previousMode: FocusedTextSignalMode
    public let mode: FocusedTextSignalMode

    public var didChangeMode: Bool {
        previousMode != mode
    }

    public init(previousMode: FocusedTextSignalMode, mode: FocusedTextSignalMode) {
        self.previousMode = previousMode
        self.mode = mode
    }
}

public struct FocusedTextSignalModeState: Equatable, Sendable {
    fileprivate var apps: [String: FocusedTextSignalAppState]

    public init() {
        apps = [:]
    }
}

public struct FocusedTextSignalModePolicy: Equatable, Sendable {
    public let eventPromotionThreshold: Int
    public let silentKeyDownDemotionThreshold: Int
    public let pollingIntervalSeconds: TimeInterval
    public let hybridHeartbeatIntervalSeconds: TimeInterval
    public let eventDrivenWatchdogIntervalSeconds: TimeInterval

    public init(
        eventPromotionThreshold: Int = 3,
        silentKeyDownDemotionThreshold: Int = 2,
        pollingIntervalSeconds: TimeInterval = 0.08,
        hybridHeartbeatIntervalSeconds: TimeInterval = 0.5,
        eventDrivenWatchdogIntervalSeconds: TimeInterval = 1.5
    ) {
        self.eventPromotionThreshold = max(1, eventPromotionThreshold)
        self.silentKeyDownDemotionThreshold = max(1, silentKeyDownDemotionThreshold)
        self.pollingIntervalSeconds = max(0.08, pollingIntervalSeconds)
        self.hybridHeartbeatIntervalSeconds = max(
            self.pollingIntervalSeconds,
            hybridHeartbeatIntervalSeconds
        )
        self.eventDrivenWatchdogIntervalSeconds = max(
            self.hybridHeartbeatIntervalSeconds,
            eventDrivenWatchdogIntervalSeconds
        )
    }

    public func mode(
        for bundleIdentifier: String,
        state: FocusedTextSignalModeState
    ) -> FocusedTextSignalMode {
        state.apps[bundleIdentifier]?.mode ?? .hybrid
    }

    public func heartbeatInterval(
        for bundleIdentifier: String,
        state: FocusedTextSignalModeState
    ) -> TimeInterval {
        switch mode(for: bundleIdentifier, state: state) {
        case .eventDriven:
            eventDrivenWatchdogIntervalSeconds
        case .polling:
            pollingIntervalSeconds
        case .hybrid:
            hybridHeartbeatIntervalSeconds
        }
    }

    @discardableResult
    public func record(
        _ observation: FocusedTextSignalObservation,
        for bundleIdentifier: String,
        state: inout FocusedTextSignalModeState
    ) -> FocusedTextSignalModeTransition {
        var appState = state.apps[bundleIdentifier] ?? FocusedTextSignalAppState()
        let previousMode = appState.mode

        switch observation {
        case .eventConfirmedRead:
            appState.consecutiveEventConfirmedReads += 1
            appState.consecutiveSilentKeyDowns = 0
            if appState.consecutiveEventConfirmedReads >= eventPromotionThreshold {
                appState.mode = .eventDriven
            }

        case let .keyDown(axNotificationObservedSinceLastKeyDown):
            if axNotificationObservedSinceLastKeyDown {
                appState.consecutiveSilentKeyDowns = 0
            } else {
                appState.consecutiveEventConfirmedReads = 0
                appState.consecutiveSilentKeyDowns += 1
                if appState.consecutiveSilentKeyDowns >= silentKeyDownDemotionThreshold {
                    appState.mode = .polling
                }
            }
        }

        state.apps[bundleIdentifier] = appState
        return FocusedTextSignalModeTransition(previousMode: previousMode, mode: appState.mode)
    }

    public func reset(
        bundleIdentifier: String,
        state: inout FocusedTextSignalModeState
    ) {
        state.apps.removeValue(forKey: bundleIdentifier)
    }
}

private struct FocusedTextSignalAppState: Equatable, Sendable {
    var mode: FocusedTextSignalMode = .hybrid
    var consecutiveEventConfirmedReads = 0
    var consecutiveSilentKeyDowns = 0
}
