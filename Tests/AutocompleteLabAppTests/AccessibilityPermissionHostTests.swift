import Foundation
import Testing
@testable import AutocompleteLabApp

@MainActor
struct AccessibilityPermissionHostTests {
    @Test
    func requestDelegatesToClientAndReturnsCurrentTrust() {
        let client = FakeAccessibilityPermissionClient(isTrusted: false)
        let host = AccessibilityPermissionHost(client: client)

        #expect(!host.requestPermission())
        #expect(client.requestCount == 1)

        client.isTrusted = true
        #expect(host.requestPermission())
        #expect(client.requestCount == 2)
    }

    @Test
    func openAccessibilitySettingsUsesTheNativeSettingsURL() {
        let client = FakeAccessibilityPermissionClient(isTrusted: true)
        var openedURL: URL?
        let host = AccessibilityPermissionHost(client: client) { url in
            openedURL = url
            return true
        }

        #expect(host.openAccessibilitySettings())
        #expect(openedURL?.scheme == "x-apple.systempreferences")
        #expect(openedURL?.absoluteString.contains("Privacy_Accessibility") == true)
    }
}

@MainActor
private final class FakeAccessibilityPermissionClient: AccessibilityPermissionClient {
    var isTrusted: Bool
    var requestCount = 0

    init(isTrusted: Bool) {
        self.isTrusted = isTrusted
    }

    func requestPermissionIfNeeded() {
        requestCount += 1
    }
}
