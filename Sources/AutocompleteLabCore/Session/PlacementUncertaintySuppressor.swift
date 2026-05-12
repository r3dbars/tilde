import Foundation

public struct PlacementUncertaintyDecision: Equatable, Sendable {
    public let fieldIdentifier: String
    public let reason: String
    public let count: Int
    public let threshold: Int

    public init(
        fieldIdentifier: String,
        reason: String,
        count: Int,
        threshold: Int
    ) {
        self.fieldIdentifier = fieldIdentifier
        self.reason = reason
        self.count = count
        self.threshold = threshold
    }

    public var shouldSuppressField: Bool {
        count >= threshold
    }

    public var metadata: [String: String] {
        [
            "placementUncertaintyReason": reason,
            "placementUncertaintyCount": String(count),
            "placementUncertaintyThreshold": String(threshold),
            "placementUncertaintyFieldSuppressed": String(shouldSuppressField)
        ]
    }
}

public struct PlacementUncertaintySuppressor: Equatable, Sendable {
    public let threshold: Int

    private var countsByField: [String: Int] = [:]

    public init(threshold: Int = 2) {
        self.threshold = max(1, threshold)
    }

    public mutating func record(
        reason: String,
        fieldIdentifier: String
    ) -> PlacementUncertaintyDecision {
        guard !fieldIdentifier.isEmpty else {
            return PlacementUncertaintyDecision(
                fieldIdentifier: fieldIdentifier,
                reason: reason,
                count: 0,
                threshold: threshold
            )
        }

        let count = (countsByField[fieldIdentifier] ?? 0) + 1
        countsByField[fieldIdentifier] = count

        return PlacementUncertaintyDecision(
            fieldIdentifier: fieldIdentifier,
            reason: reason,
            count: count,
            threshold: threshold
        )
    }

    public mutating func reset(fieldIdentifier: String) {
        countsByField[fieldIdentifier] = nil
    }

    public mutating func resetAll() {
        countsByField.removeAll(keepingCapacity: true)
    }
}
