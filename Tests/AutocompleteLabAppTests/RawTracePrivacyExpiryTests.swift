import Foundation
import Testing
@testable import AutocompleteLabApp

@Suite("Raw trace privacy expiry")
struct RawTracePrivacyExpiryTests {
    @Test("Raw text and screenshot capture expire and delete clears both")
    func rawTextAndScreenshotCaptureExpireAndDeleteClearsBoth() {
        let suiteName = "RawTracePrivacyExpiryTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let temporaryFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent("RawTracePrivacyExpiryTests-\(UUID().uuidString)")
        let clock = TestClock(Date(timeIntervalSince1970: 1_000))
        let log = RawAutocompleteTraceLog(
            logURL: temporaryFolder.appendingPathComponent("traces.jsonl"),
            screenshotsURL: temporaryFolder.appendingPathComponent("screenshots"),
            userDefaults: defaults,
            environment: [:],
            debugCaptureDuration: 60,
            now: { clock.current }
        )

        log.setRawContentTracingEnabled(true)
        log.setScreenshotTracingEnabled(true)

        #expect(log.rawContentTracingEnabled)
        #expect(log.screenshotTracingEnabled)
        #expect(log.rawContentTracingExpiresAt == Date(timeIntervalSince1970: 1_060))
        #expect(log.screenshotTracingExpiresAt == Date(timeIntervalSince1970: 1_060))

        clock.current = Date(timeIntervalSince1970: 1_061)

        #expect(!log.rawContentTracingEnabled)
        #expect(!log.screenshotTracingEnabled)
        #expect(log.rawContentTracingExpiresAt == nil)
        #expect(log.screenshotTracingExpiresAt == nil)

        log.setRawContentTracingEnabled(true)
        log.setScreenshotTracingEnabled(true)
        log.deleteAll()

        #expect(!log.rawContentTracingEnabled)
        #expect(!log.screenshotTracingEnabled)
    }
}

private final class TestClock {
    var current: Date

    init(_ current: Date) {
        self.current = current
    }
}
