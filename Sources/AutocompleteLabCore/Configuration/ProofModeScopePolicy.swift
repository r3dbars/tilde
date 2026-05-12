import Foundation

public struct ProofModeScopePolicy: Equatable, Sendable {
    public let scopedBundleIdentifiers: Set<String>

    public init(scopedBundleIdentifiers: Set<String> = []) {
        self.scopedBundleIdentifiers = scopedBundleIdentifiers
    }

    public var isActive: Bool {
        !scopedBundleIdentifiers.isEmpty
    }

    public func allows(
        appBundleIdentifier: String,
        suggestionBundleIdentifier: String
    ) -> Bool {
        guard isActive else {
            return true
        }

        return scopedBundleIdentifiers.contains(appBundleIdentifier)
            || scopedBundleIdentifiers.contains(suggestionBundleIdentifier)
    }
}
