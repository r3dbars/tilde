import Testing
@testable import AutocompleteLabCore

@Suite("Commit-unsafe host detection")
struct CommitUnsafeHostPolicyTests {
    @Test("Known Chromium browsers require an external surface")
    func knownBrowsersMatch() {
        for prefix in CommitUnsafeHostPolicy.chromiumBrowserPrefixes {
            #expect(CommitUnsafeHostPolicy.requiresExternalSurface(
                bundleIdentifier: prefix,
                hasElectronFramework: false
            ))
        }
    }

    @Test("Electron requires an external surface regardless of bundle ID")
    func electronMatches() {
        #expect(CommitUnsafeHostPolicy.requiresExternalSurface(
            bundleIdentifier: "com.tinyspeck.slackmacgap",
            hasElectronFramework: true
        ))
    }

    @Test("Native apps keep inline marked text")
    func nativeAppsStayInline() {
        #expect(!CommitUnsafeHostPolicy.requiresExternalSurface(
            bundleIdentifier: "com.apple.TextEdit",
            hasElectronFramework: false
        ))
    }
}
