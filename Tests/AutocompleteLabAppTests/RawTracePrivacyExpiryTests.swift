import Foundation
import Testing
@testable import AutocompleteLabApp
@testable import AutocompleteLabCore

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
        let survivalInspectorDebug = temporaryFolder.appendingPathComponent("survival-inspector-debug.json")
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
        FileManager.default.createFile(
            atPath: survivalInspectorDebug.path,
            contents: Data(#"{"acceptedText":"private draft text"}"#.utf8)
        )

        #expect(log.recentEvents(limit: 1).first?.textBeforeCursor == "private draft text")
        #expect(FileManager.default.fileExists(atPath: screenshotFile.path))
        #expect(FileManager.default.fileExists(atPath: survivalInspectorDebug.path))

        clock.current = Date(timeIntervalSince1970: 2_061)

        #expect(!log.rawContentTracingEnabled)
        #expect(!log.screenshotTracingEnabled)
        let redacted = try #require(log.recentEvents(limit: 1).first)
        #expect(redacted.textBeforeCursor == "")
        #expect(redacted.metadata["textBeforeCursorChars"] == "18")
        #expect(!FileManager.default.fileExists(atPath: screenshotFile.path))
        #expect(!FileManager.default.fileExists(atPath: survivalInspectorDebug.path))
    }

    @Test("Sensitive surfaces stay redacted when raw tracing is enabled")
    func sensitiveSurfacesOverrideRawTracing() throws {
        let suiteName = "RawTracePrivacyExpiryTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let temporaryFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent("RawTracePrivacyExpiryTests-\(UUID().uuidString)")
        let log = RawAutocompleteTraceLog(
            logURL: temporaryFolder.appendingPathComponent("traces.jsonl"),
            screenshotsURL: temporaryFolder.appendingPathComponent("screenshots"),
            userDefaults: defaults,
            environment: [:]
        )
        log.setRawContentTracingEnabled(true)
        log.setScreenshotTracingEnabled(true)

        let systemPrompt = "synthetic-system-prompt-sentinel"
        let userPrompt = "synthetic-user-prompt-sentinel"
        let cleanedVisibleText = "synthetic-cleaned-visible-sentinel"
        let displayedText = "synthetic-displayed-sentinel"
        let remainingVisibleText = "synthetic-remaining-visible-sentinel"
        log.record(
            type: .suggestionSuppressed,
            suggestionID: "sensitive-one",
            appBundleIdentifier: "com.example.synthetic",
            textBeforeCursor: "synthetic-password-sentinel",
            textAfterCursor: "synthetic-otp-sentinel",
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            rawOutput: "synthetic-output-sentinel",
            cleanedVisibleText: cleanedVisibleText,
            displayedText: displayedText,
            acceptedText: "synthetic-accepted-sentinel",
            remainingVisibleText: remainingVisibleText,
            reason: "blocked-field-kind",
            screenshotPath: "/synthetic/sensitive-screenshot.png",
            contentSensitivity: .sensitiveSurface,
            metadata: ["privatePrompt": "synthetic-metadata-sentinel"]
        )

        let event = try #require(log.recentEvents(limit: 1).first)
        #expect(event.textBeforeCursor == "String(27 chars)")
        #expect(event.textAfterCursor == "String(22 chars)")
        #expect(event.systemPrompt == "String(\(systemPrompt.count) chars)")
        #expect(event.userPrompt == "String(\(userPrompt.count) chars)")
        #expect(event.rawOutput == "String(25 chars)")
        #expect(event.cleanedVisibleText == "String(\(cleanedVisibleText.count) chars)")
        #expect(event.displayedText == "String(\(displayedText.count) chars)")
        #expect(event.acceptedText == "String(27 chars)")
        #expect(event.remainingVisibleText == "String(\(remainingVisibleText.count) chars)")
        #expect(event.screenshotPath.isEmpty)
        #expect(event.metadata["privatePrompt"] == "String(27 chars)")
    }

    @MainActor
    @Test("Sensitive-content activation blocks mark ordinary fields sensitive for tracing")
    func activationSensitiveContentFailsClosedAtAppDelegateSeam() {
        let ordinaryField = AXFieldClassification(kind: .multilineCompose, reason: "synthetic-compose")

        #expect(AppDelegate.traceContentSensitivity(
            fieldClassification: ordinaryField,
            activationDecision: .block(.sensitiveContent)
        ) == .sensitiveSurface)
        #expect(AppDelegate.traceContentSensitivity(
            fieldClassification: ordinaryField,
            activationDecision: .block(.tooLittleContext)
        ) == .standard)
    }

    @Test("Suppressed field metadata fails closed at the logger boundary")
    func suppressedFieldMetadataOverridesRawTracing() throws {
        let suiteName = "RawTracePrivacyExpiryTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let temporaryFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent("RawTracePrivacyExpiryTests-\(UUID().uuidString)")
        let log = RawAutocompleteTraceLog(
            logURL: temporaryFolder.appendingPathComponent("traces.jsonl"),
            screenshotsURL: temporaryFolder.appendingPathComponent("screenshots"),
            userDefaults: defaults,
            environment: [:]
        )
        log.setRawContentTracingEnabled(true)
        log.setScreenshotTracingEnabled(true)

        log.record(
            type: .suggestionSuppressed,
            suggestionID: "metadata-sensitive-one",
            textBeforeCursor: "synthetic-secret-sentinel",
            screenshotPath: "/synthetic/sensitive-screenshot.png",
            metadata: [
                "fieldKind": "secure",
                "fieldKindSuppressed": "true"
            ]
        )

        let event = try #require(log.recentEvents(limit: 1).first)
        #expect(event.textBeforeCursor == "String(25 chars)")
        #expect(event.screenshotPath.isEmpty)
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
            temporaryFolder.appendingPathComponent("survival-inspector-debug.json"),
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
            temporaryFolder.appendingPathComponent("survival-inspector-debug.json"),
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
