import Foundation

public struct DisabledAppSelection: Equatable, Sendable {
    public private(set) var bundleIdentifiers: Set<String>

    public init(bundleIdentifiers: Set<String> = []) {
        self.bundleIdentifiers = bundleIdentifiers.filter { !$0.isEmpty }
    }

    public init(persistedBundleIdentifiers: [String]) {
        self.init(bundleIdentifiers: Set(persistedBundleIdentifiers))
    }

    public var persistedBundleIdentifiers: [String] {
        bundleIdentifiers.sorted()
    }

    public func contains(_ bundleIdentifier: String) -> Bool {
        bundleIdentifiers.contains(bundleIdentifier)
    }

    public mutating func toggle(_ bundleIdentifier: String) {
        guard !bundleIdentifier.isEmpty else {
            return
        }

        if bundleIdentifiers.contains(bundleIdentifier) {
            bundleIdentifiers.remove(bundleIdentifier)
        } else {
            bundleIdentifiers.insert(bundleIdentifier)
        }
    }
}
