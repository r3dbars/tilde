import Foundation
import Testing
@testable import AutocompleteLabApp

@Suite("Tilde installation location")
struct TildeInstallationLocationTests {
    @Test("Mounted disk images require installation")
    func mountedDiskImage() {
        let url = URL(fileURLWithPath: "/Volumes/Tilde/Tilde.app")
        #expect(TildeInstallationLocation.requiresMove(bundleURL: url, volumeIsReadOnly: false))
    }

    @Test("Read-only volumes require installation")
    func readOnlyVolume() {
        let url = URL(fileURLWithPath: "/private/tmp/Tilde.app")
        #expect(TildeInstallationLocation.requiresMove(bundleURL: url, volumeIsReadOnly: true))
    }

    @Test("Applications is accepted on a writable volume")
    func applications() {
        let url = URL(fileURLWithPath: "/Applications/Tilde.app")
        #expect(!TildeInstallationLocation.requiresMove(bundleURL: url, volumeIsReadOnly: false))
    }
}
