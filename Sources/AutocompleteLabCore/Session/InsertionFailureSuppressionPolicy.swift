public struct InsertionFailureSuppressionPolicy: Equatable, Sendable {
    public init() {}

    public func shouldSuppressField(
        profile: CompatibilityProfile,
        failureReason: String
    ) -> Bool {
        profile.suppressesAfterInsertionFailure && !failureReason.isEmpty
    }
}
