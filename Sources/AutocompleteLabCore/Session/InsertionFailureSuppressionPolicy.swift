public struct InsertionFailureSuppressionPolicy: Equatable, Sendable {
    public let automaticSuppressionEnabled: Bool

    public init(automaticSuppressionEnabled: Bool = false) {
        self.automaticSuppressionEnabled = automaticSuppressionEnabled
    }

    public func shouldSuppressField(
        profile: CompatibilityProfile,
        failureReason: String
    ) -> Bool {
        automaticSuppressionEnabled
            && profile.suppressesAfterInsertionFailure
            && !failureReason.isEmpty
    }
}
