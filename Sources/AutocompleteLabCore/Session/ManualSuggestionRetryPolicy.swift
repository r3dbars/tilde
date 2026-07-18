public struct ManualSuggestionRetryPolicy: Equatable, Sendable {
    public let delayMilliseconds: Int

    public init(delayMilliseconds: Int = 150) {
        self.delayMilliseconds = max(1, delayMilliseconds)
    }
}
