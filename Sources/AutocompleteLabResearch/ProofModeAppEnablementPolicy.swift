import Foundation
import AutocompleteLabCore

public struct ProofModeAppEnablementPolicy: Equatable, Sendable {
    public let disabledBundleIdentifiers: Set<String>
    public let activeProofBundleIdentifiers: Set<String>

    public init(
        disabledBundleIdentifiers: Set<String> = [],
        activeProofBundleIdentifiers: Set<String> = []
    ) {
        self.disabledBundleIdentifiers = disabledBundleIdentifiers
        self.activeProofBundleIdentifiers = activeProofBundleIdentifiers
    }

    public func isEnabled(
        appBundleIdentifier: String,
        suggestionBundleIdentifier: String
    ) -> Bool {
        if activeProofBundleIdentifiers.contains(appBundleIdentifier)
            || activeProofBundleIdentifiers.contains(suggestionBundleIdentifier) {
            return true
        }

        return !disabledBundleIdentifiers.contains(appBundleIdentifier)
    }
}
