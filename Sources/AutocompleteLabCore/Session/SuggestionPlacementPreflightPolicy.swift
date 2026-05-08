public struct SuggestionPlacementPreflightDecision: Equatable {
    public let canRequest: Bool
    public let suppression: PlacementHealthSuppression?

    public init(canRequest: Bool, suppression: PlacementHealthSuppression?) {
        self.canRequest = canRequest
        self.suppression = suppression
    }
}

public struct SuggestionPlacementPreflightPolicy: Equatable {
    public init() {}

    public func decision(for plan: PlacementHealthPlan) -> SuggestionPlacementPreflightDecision {
        switch plan {
        case .present:
            return SuggestionPlacementPreflightDecision(canRequest: true, suppression: nil)
        case let .suppress(suppression):
            return SuggestionPlacementPreflightDecision(canRequest: false, suppression: suppression)
        }
    }
}
