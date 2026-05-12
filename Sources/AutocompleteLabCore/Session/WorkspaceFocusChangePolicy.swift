import Foundation

public struct WorkspaceFocusChangePolicy: Sendable {
    public enum ChangeKind: Sendable {
        case activated
        case deactivated
    }

    public init() {}

    public func shouldClearFocus(
        kind: ChangeKind,
        notificationBundleIdentifier: String?,
        frontmostBundleIdentifier: String?,
        currentFieldIdentity: FocusedFieldIdentity?
    ) -> Bool {
        guard let currentBundleIdentifier = currentFieldIdentity?.bundleIdentifier else {
            return true
        }

        switch kind {
        case .activated:
            return notificationBundleIdentifier != currentBundleIdentifier
        case .deactivated:
            if frontmostBundleIdentifier == currentBundleIdentifier {
                return false
            }
            guard let notificationBundleIdentifier else {
                return true
            }
            return notificationBundleIdentifier == currentBundleIdentifier
        }
    }
}
