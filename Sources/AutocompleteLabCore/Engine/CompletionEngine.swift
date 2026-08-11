/// A single completion request from the input method: the text being written
/// and where it's being written.
public struct CompletionRequest: Equatable, Sendable {
    public let textBeforeCursor: String
    public let appBundleIdentifier: String?

    public init(
        textBeforeCursor: String,
        appBundleIdentifier: String? = nil
    ) {
        self.textBeforeCursor = textBeforeCursor
        self.appBundleIdentifier = appBundleIdentifier
    }
}
