import Foundation

/// Apps that are excluded from BOTH Screen Memory capture and Personal
/// History, unconditionally — the owner's exclusion list
/// (`personalHistoryExcludedApps`) is additive on top of this set, never a
/// replacement for it. A user cannot un-exclude a password manager by
/// leaving it out of their own list, and a fresh install with an empty
/// settings store is still safe on first launch.
///
/// Scope is deliberately narrow: apps whose ENTIRE reason for existing is
/// displaying secrets on screen. General-purpose apps that sometimes show a
/// password field (a browser, Mail) stay off this list — that is what the
/// redaction layer itself and the user's own exclusion list are for.
public enum DefaultExcludedApps {
    /// Bundle identifiers, always lower-cased and exact-match (no prefix
    /// matching — `com.1password.1password7` is a distinct app from
    /// `com.1password.1password` and both are listed explicitly rather than
    /// pattern-matched, so a typo'd pattern can never silently fail open).
    public static let bundleIdentifiers: Set<String> = [
        // Apple
        "com.apple.keychainaccess",
        "com.apple.Passwords",
        // 1Password
        "com.1password.1password",
        "com.1password.1password7",
        "com.agilebits.onepassword7",
        "com.agilebits.onepassword-osx",
        // Bitwarden
        "com.bitwarden.desktop",
        // Dashlane
        "com.dashlane.dashlanephonefinal",
        // LastPass
        "com.lastpass.LastPass",
        // KeePass family
        "org.keepassxc.KeePassXC",
        "com.KeePass.mac",
        // NordPass
        "com.nordsec.nordpass",
        // Enpass
        "in.sinew.Enpass-Desktop",
    ]

    /// Every capture-eligibility check the app makes should union its
    /// caller-configurable exclusion set with this one — never check either
    /// list alone. Kept as a function rather than requiring every call site
    /// to remember the union so the "always" guarantee cannot be dropped by
    /// a future refactor that reads only the user's list.
    public static func isAlwaysExcluded(_ bundleIdentifier: String) -> Bool {
        bundleIdentifiers.contains(bundleIdentifier)
    }

    public static func union(with excludedApps: Set<String>) -> Set<String> {
        excludedApps.union(bundleIdentifiers)
    }
}
