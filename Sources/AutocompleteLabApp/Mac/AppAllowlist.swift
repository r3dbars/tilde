import Foundation

struct AppAllowlist: Equatable {
    let bundleIdentifiers: Set<String>

    static let `default` = AppAllowlist(bundleIdentifiers: [
        "com.apple.TextEdit",
        "com.apple.Notes",
        "com.apple.mail",
        "md.obsidian"
    ])

    func allows(bundleIdentifier: String) -> Bool {
        bundleIdentifiers.contains(bundleIdentifier)
    }
}
