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

    @Test("Expired raw and screenshot tracing removes durable debug artifacts")
    func expiryRemovesDurableDebugArtifacts() throws {
        let suiteName = "RawTracePrivacyExpiryTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let temporaryFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent("RawTracePrivacyExpiryTests-\(UUID().uuidString)")
        let screenshots = temporaryFolder.appendingPathComponent("screenshots")
        let screenshotFile = screenshots.appendingPathComponent("debug.png")
        let clock = TestClock(Date(timeIntervalSince1970: 2_000))
        let log = RawAutocompleteTraceLog(
            logURL: temporaryFolder.appendingPathComponent("traces.jsonl"),
            screenshotsURL: screenshots,
            userDefaults: defaults,
            environment: [:],
            debugCaptureDuration: 60,
            now: { clock.current }
        )

        log.setRawContentTracingEnabled(true)
        log.setScreenshotTracingEnabled(true)
        log.record(
            type: .suggestionPresented,
            suggestionID: "raw-one",
            appBundleIdentifier: "com.apple.TextEdit",
            fieldIdentity: "field",
            requestMode: "wordCompletion",
            textBeforeCursor: "private draft text",
            screenshotPath: screenshotFile.path
        )
        try FileManager.default.createDirectory(at: screenshots, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: screenshotFile.path, contents: Data("png".utf8))

        #expect(log.recentEvents(limit: 1).first?.textBeforeCursor == "private draft text")
        #expect(FileManager.default.fileExists(atPath: screenshotFile.path))

        clock.current = Date(timeIntervalSince1970: 2_061)

        #expect(!log.rawContentTracingEnabled)
        #expect(!log.screenshotTracingEnabled)
        let redacted = try #require(log.recentEvents(limit: 1).first)
        #expect(redacted.textBeforeCursor == "")
        #expect(redacted.metadata["textBeforeCursorChars"] == "18")
        #expect(!FileManager.default.fileExists(atPath: screenshotFile.path))
    }

    @Test("Delete all removes generated local report artifacts too")
    func deleteAllRemovesGeneratedReportArtifacts() throws {
        let suiteName = "RawTracePrivacyExpiryTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let temporaryFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent("RawTracePrivacyExpiryTests-\(UUID().uuidString)")
        let screenshots = temporaryFolder.appendingPathComponent("screenshots")
        let privacyExport = temporaryFolder.appendingPathComponent("privacy-export")
        let log = RawAutocompleteTraceLog(
            logURL: temporaryFolder.appendingPathComponent("traces.jsonl"),
            screenshotsURL: screenshots,
            userDefaults: defaults,
            environment: [:]
        )

        try FileManager.default.createDirectory(at: screenshots, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: privacyExport, withIntermediateDirectories: true)
        for file in [
            temporaryFolder.appendingPathComponent("traces.jsonl"),
            temporaryFolder.appendingPathComponent("raw-traces.jsonl"),
            temporaryFolder.appendingPathComponent("trace-report.html"),
            temporaryFolder.appendingPathComponent("survival-report.json"),
            privacyExport.appendingPathComponent("manifest.json"),
            screenshots.appendingPathComponent("debug.png")
        ] {
            FileManager.default.createFile(atPath: file.path, contents: Data("debug".utf8))
        }

        log.deleteAll()

        for path in [
            temporaryFolder.appendingPathComponent("traces.jsonl"),
            temporaryFolder.appendingPathComponent("raw-traces.jsonl"),
            temporaryFolder.appendingPathComponent("trace-report.html"),
            temporaryFolder.appendingPathComponent("survival-report.json"),
            privacyExport,
            screenshots
        ] {
            #expect(!FileManager.default.fileExists(atPath: path.path))
        }
    }
}

private final class TestClock {
    var current: Date

    init(_ current: Date) {
        self.current = current
    }
}
