import Foundation

public enum RuntimeResourcePressureEvent: String, Equatable, Sendable {
    case memoryWarning
    case memoryCritical
    case thermalFair
    case thermalSerious
    case thermalCritical
}

public enum RuntimeResourcePressureAction: String, Equatable, Sendable {
    case continueRunning
    case reduceWork
    case unloadAndSuspend
}

public struct RuntimeResourcePressureDecision: Equatable, Sendable {
    public let action: RuntimeResourcePressureAction
    public let reason: String

    public init(action: RuntimeResourcePressureAction, reason: String) {
        self.action = action
        self.reason = reason
    }

    public var shouldUnloadRuntime: Bool {
        action == .unloadAndSuspend
    }

    public var shouldSuspendSuggestions: Bool {
        action != .continueRunning
    }
}

public struct RuntimeResourcePressurePolicy: Equatable, Sendable {
    public init() {}

    public func decision(for event: RuntimeResourcePressureEvent) -> RuntimeResourcePressureDecision {
        switch event {
        case .thermalFair:
            return RuntimeResourcePressureDecision(
                action: .reduceWork,
                reason: "thermal-fair"
            )

        case .memoryWarning:
            return RuntimeResourcePressureDecision(
                action: .reduceWork,
                reason: "memory-warning"
            )

        case .thermalSerious:
            return RuntimeResourcePressureDecision(
                action: .unloadAndSuspend,
                reason: "thermal-serious"
            )

        case .thermalCritical:
            return RuntimeResourcePressureDecision(
                action: .unloadAndSuspend,
                reason: "thermal-critical"
            )

        case .memoryCritical:
            return RuntimeResourcePressureDecision(
                action: .unloadAndSuspend,
                reason: "memory-critical"
            )
        }
    }
}
