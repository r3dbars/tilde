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
        _ = profileStore
        self.init()
    }

    public init(
        persistedBundleIdentifiers: [String]?,
        defaultOffProfileStore profileStore: CompatibilityProfileStore
    ) {
        if let persistedBundleIdentifiers {
            self.init(persistedBundleIdentifiers: persistedBundleIdentifiers)
        } else {
            self.init(defaultOffProfileStore: profileStore)
        }
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

    public mutating func removeLegacyDefaultOffBundleIdentifiers(profileStore: CompatibilityProfileStore) {
        bundleIdentifiers.subtract(Self.legacyDefaultOffBundleIdentifiers(profileStore: profileStore))
    }

    public mutating func temporarilyEnable(bundleIdentifiers rawValue: String?) {
        for bundleIdentifier in Self.parseBundleIdentifierList(rawValue) {
            set(bundleIdentifier, disabled: false)
        }
    }

    public func applyingTemporaryEnablement(bundleIdentifiers rawValue: String?) -> Self {
        var selection = self
        selection.temporarilyEnable(bundleIdentifiers: rawValue)
        return selection
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

    private static func legacyDefaultOffBundleIdentifiers(
        profileStore: CompatibilityProfileStore
    ) -> Set<String> {
        Set(
            profileStore.profiles.values.compactMap { profile in
                guard profile.canPresentSuggestions, !profile.isSensitive else {
                    return nil
                }

                return profile.bundleIdentifier
            }
        )
    }
}
