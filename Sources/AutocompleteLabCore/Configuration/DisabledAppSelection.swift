import Foundation

public struct DisabledAppSelection: Equatable, Sendable {
    public private(set) var bundleIdentifiers: Set<String>

    public init(bundleIdentifiers: Set<String> = []) {
        self.bundleIdentifiers = bundleIdentifiers.filter { !$0.isEmpty }
    }

    public init(persistedBundleIdentifiers: [String]) {
        self.init(bundleIdentifiers: Set(persistedBundleIdentifiers))
    }

    public init(defaultOffProfileStore profileStore: CompatibilityProfileStore) {
        self.init(bundleIdentifiers: Set(
            profileStore.profiles.values.compactMap { profile in
                guard profile.canPresentSuggestions, !profile.isSensitive else {
                    return nil
                }

                return profile.bundleIdentifier
            }
        ))
    }

    public var persistedBundleIdentifiers: [String] {
        bundleIdentifiers.sorted()
    }

    public var isEmpty: Bool {
        bundleIdentifiers.isEmpty
    }

    public var count: Int {
        bundleIdentifiers.count
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

    public mutating func set(_ bundleIdentifier: String, disabled: Bool) {
        guard !bundleIdentifier.isEmpty else {
            return
        }

        if disabled {
            bundleIdentifiers.insert(bundleIdentifier)
        } else {
            bundleIdentifiers.remove(bundleIdentifier)
        }
    }

    public mutating func clear() {
        bundleIdentifiers.removeAll(keepingCapacity: false)
    }

    public mutating func temporarilyEnable(bundleIdentifiers rawValue: String?) {
        for bundleIdentifier in Self.parseBundleIdentifierList(rawValue) {
            set(bundleIdentifier, disabled: false)
        }
    }

    public static func parseBundleIdentifierList(_ rawValue: String?) -> [String] {
        guard let rawValue else {
            return []
        }

        return rawValue
            .split { character in
                character == "," || character == "\n" || character == " "
            }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
