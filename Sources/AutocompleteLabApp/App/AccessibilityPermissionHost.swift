import AppKit

@MainActor
protocol AccessibilityPermissionClient: AnyObject {
    var isTrusted: Bool { get }
    func requestPermissionIfNeeded()
}

extension AccessibilityClient: AccessibilityPermissionClient {}

/// Owns native Accessibility permission requests and the System Settings URL.
/// AppDelegate keeps the product response and Settings presentation around them.
@MainActor
final class AccessibilityPermissionHost {
    private static let accessibilitySettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    )!

    private let client: any AccessibilityPermissionClient
    private let openURL: (URL) -> Bool

    init(
        client: any AccessibilityPermissionClient,
        openURL: @escaping (URL) -> Bool = { url in
            NSWorkspace.shared.open(url)
        }
    ) {
        self.client = client
        self.openURL = openURL
    }

    var isTrusted: Bool {
        client.isTrusted
    }

    func requestPermissionIfNeeded() {
        client.requestPermissionIfNeeded()
    }

    @discardableResult
    func requestPermission() -> Bool {
        client.requestPermissionIfNeeded()
        return client.isTrusted
    }

    @discardableResult
    func openAccessibilitySettings() -> Bool {
        openURL(Self.accessibilitySettingsURL)
    }
}
