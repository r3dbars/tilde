import Foundation

public struct DescendantTextFallbackPolicy: Equatable, Sendable {
    public init() {}

    public func allowsFallback(
        bundleIdentifier: String?,
        role: String?,
        directText: String?,
        windowTitle: String?
    ) -> Bool {
        guard role == "AXWebArea",
              directText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false else {
            return false
        }

        switch bundleIdentifier {
        case "md.obsidian":
            return true

        case "com.apple.mail":
            return windowTitle == "New Message"

        case "com.google.Chrome":
            guard let searchableTitle = windowTitle?.lowercased() else {
                return false
            }

            return searchableTitle.contains("steadytype chrome")
                && searchableTitle.contains("smoke")

        default:
            return false
        }
    }
}
