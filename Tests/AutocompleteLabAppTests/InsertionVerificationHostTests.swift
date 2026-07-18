import Foundation
import Testing

@Suite("Insertion verification host wiring")
struct InsertionVerificationHostTests {
    @Test("AppDelegate delegates delayed verification and cancellation")
    func appDelegateDelegatesDelayedVerificationAndCancellation() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let appDelegate = try String(
            contentsOf: root.appendingPathComponent("Sources/AutocompleteLabApp/App/AppDelegate.swift"),
            encoding: .utf8
        )
        let host = try String(
            contentsOf: root.appendingPathComponent("Sources/AutocompleteLabApp/App/InsertionVerificationHost.swift"),
            encoding: .utf8
        )

        #expect(appDelegate.contains("InsertionVerificationHost(handler: self)"))
        #expect(appDelegate.contains("extension AppDelegate: InsertionVerificationHandling"))
        #expect(appDelegate.contains("insertionVerificationHost.cancel()"))
        #expect(!appDelegate.contains("insertionVerificationScheduler.scheduleAsync"))
        #expect(host.contains("InsertionVerificationTimingPolicy"))
        #expect(host.contains("ObsidianInsertionVerificationFastPathPolicy"))
        #expect(host.contains("InsertionRetryPolicy"))
        #expect(host.contains("handleInsertionVerificationSuccess"))
    }
}
