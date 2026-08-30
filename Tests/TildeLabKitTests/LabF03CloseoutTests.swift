import CryptoKit
import Darwin
import Foundation
import Testing
@testable import TildeLabKit
@testable import TildeCore

@Suite("F03 decision-grade closeout", .serialized)
struct LabF03CloseoutTests {
    private let rotation = Date(timeIntervalSince1970: 1_777_593_600)
    private let generated = Date(timeIntervalSince1970: 1_777_593_900)

    @Test("A current stopped flushed Preview9B run closes as path-free decision-grade evidence")
    func eligibleCloseout() throws {
        let receipt = try receiptData()
        let event = acceptedEvent(at: rotation.addingTimeInterval(120))
        let report = try closeout(receipt: receipt, events: [event])

        #expect(report.schema == LabF03CloseoutReport.currentSchema)
        #expect(report.profile == TildeProductProfile.preview9B.rawValue)
        #expect(report.decisionGradeEligible)
        #expect(report.blockers.isEmpty)
        #expect(report.eventRows == 1)
        #expect(report.eventSchemaCounts == [LabOnlineExperimentEvent.currentSchema: 1])
        #expect(report.aggregateReport.retentionAt5Seconds.observedEvents == 1)
        #expect(report.aggregateReport.retentionAt30Seconds.observedEvents == 1)
        #expect(report.aggregateReport.retentionAtSegmentClose.observedEvents == 1)
        #expect(report.sourcePackageIdentity.signingTeamIdentifier == "TEAMID1234")
        #expect(report.sourcePackageIdentity.modelBytes == 5_629_109_312)
        #expect(report.environmentIdentity.hardwareModel == "Mac16,7")
        #expect(report.installedIdentityVerified)
        #expect(report.receiptSHA256.count == 64)
        #expect(report.eventFileSHA256.count == 64)
        #expect(!report.containsRawText)
        #expect(!report.containsLocalPaths)

        let encoded = try JSONEncoder().encode(report)
        let json = String(decoding: encoded, as: UTF8.self)
        #expect(!json.contains("/Users/"))
        #expect(!json.contains("/private/"))
    }

    @Test("Receipt validation rejects wrong profile, unknown keys, and malformed provenance")
    func strictReceiptValidation() throws {
        var wrongProfile = receiptObject()
        wrongProfile["profile"] = "production"
        #expect(throws: LabF03CloseoutError.unsupportedProfile) {
            try LabF03RunReceipt.decode(try json(wrongProfile))
        }

        var unknown = receiptObject()
        unknown["localPath"] = "/private/owner-data"
        #expect(throws: LabF03CloseoutError.malformedReceipt) {
            try LabF03RunReceipt.decode(try json(unknown))
        }

        for field in ["sourceCommit", "sourceTree", "sourceSnapshotSHA256", "modelSHA256"] {
            var malformed = receiptObject()
            malformed[field] = "NOT-A-DIGEST"
            #expect(throws: LabF03CloseoutError.invalidReceiptField(field)) {
                try LabF03RunReceipt.decode(try json(malformed))
            }
        }

        var badTeam = receiptObject()
        badTeam["signingTeamIdentifier"] = "team"
        #expect(throws: LabF03CloseoutError.invalidReceiptField("signingTeamIdentifier")) {
            try LabF03RunReceipt.decode(try json(badTeam))
        }
    }

    @Test("Generation, drop, and row-count failures are explicit blockers")
    func writeAccountingBlockers() throws {
        let event = acceptedEvent(at: rotation.addingTimeInterval(120))
        let receipt = try receiptData()
        let accounting = try LabF03WriteAccounting(attempted: 3, written: 2, dropped: 1)
        let report = try LabF03Closeout.analyze(
            receiptData: receipt,
            eventData: try eventData([event]),
            currentGeneration: 8,
            writeAccounting: accounting,
            flushAcknowledgement: acknowledgement(accounting),
            previewProcessesStopped: true,
            installedIdentityVerified: true,
            generatedAt: generated
        )
        #expect(!report.decisionGradeEligible)
        #expect(report.blockers.contains(.currentGenerationMismatch))
        #expect(report.blockers.contains(.droppedWrites))
        #expect(report.blockers.contains(.attemptedWrittenMismatch))
        #expect(report.blockers.contains(.writtenRowMismatch))
    }

    @Test("Flush acknowledgement must exist, match terminal counts, and follow rotation")
    func flushAcknowledgementGate() throws {
        let event = acceptedEvent(at: rotation.addingTimeInterval(120))
        let receipt = try receiptData()
        let accounting = try LabF03WriteAccounting(attempted: 1, written: 1, dropped: 0)
        let missing = try LabF03Closeout.analyze(
            receiptData: receipt,
            eventData: try eventData([event]),
            currentGeneration: 7,
            writeAccounting: accounting,
            flushAcknowledgement: nil,
            previewProcessesStopped: true,
            installedIdentityVerified: true,
            generatedAt: generated
        )
        #expect(missing.blockers.contains(.missingOrStaleFlushAcknowledgement))

        let stale = LabF03FlushAcknowledgement(
            writeAccounting: accounting,
            acknowledgedAt: rotation.addingTimeInterval(-1)
        )
        let staleReport = try LabF03Closeout.analyze(
            receiptData: receipt,
            eventData: try eventData([event]),
            currentGeneration: 7,
            writeAccounting: accounting,
            flushAcknowledgement: stale,
            previewProcessesStopped: true,
            installedIdentityVerified: true,
            generatedAt: generated
        )
        #expect(staleReport.blockers.contains(.missingOrStaleFlushAcknowledgement))

        let mismatched = try LabF03WriteAccounting(attempted: 2, written: 2, dropped: 0)
        let mismatchReport = try LabF03Closeout.analyze(
            receiptData: receipt,
            eventData: try eventData([event]),
            currentGeneration: 7,
            writeAccounting: accounting,
            flushAcknowledgement: acknowledgement(mismatched),
            previewProcessesStopped: true,
            installedIdentityVerified: true,
            generatedAt: generated
        )
        #expect(mismatchReport.blockers.contains(.missingOrStaleFlushAcknowledgement))

        let futureAcknowledgement = LabF03FlushAcknowledgement(
            writeAccounting: accounting,
            acknowledgedAt: generated.addingTimeInterval(1)
        )
        let futureReport = try LabF03Closeout.analyze(
            receiptData: receipt,
            eventData: try eventData([event]),
            currentGeneration: 7,
            writeAccounting: accounting,
            flushAcknowledgement: futureAcknowledgement,
            previewProcessesStopped: true,
            installedIdentityVerified: true,
            generatedAt: generated
        )
        #expect(futureReport.blockers.contains(.missingOrStaleFlushAcknowledgement))

        for eventDate in [rotation.addingTimeInterval(181), generated.addingTimeInterval(1)] {
            let postFlushEvent = acceptedEvent(at: eventDate)
            let postFlush = try LabF03Closeout.analyze(
                receiptData: receipt,
                eventData: try eventData([postFlushEvent]),
                currentGeneration: 7,
                writeAccounting: accounting,
                flushAcknowledgement: acknowledgement(accounting),
                previewProcessesStopped: true,
                installedIdentityVerified: true,
                generatedAt: generated
            )
            #expect(postFlush.blockers.contains(.missingOrStaleFlushAcknowledgement))
        }
    }

    @Test("Unverified IME registration and unstopped Preview processes block eligibility")
    func runtimePreconditions() throws {
        var unverified = receiptObject()
        unverified["inputMethodRegistrationVerified"] = false
        let event = acceptedEvent(at: rotation.addingTimeInterval(120))
        let unverifiedReport = try closeout(receipt: try json(unverified), events: [event])
        #expect(unverifiedReport.blockers == [.inputMethodRegistrationUnverified])

        let receipt = try receiptData()
        let accounting = try LabF03WriteAccounting(attempted: 1, written: 1, dropped: 0)
        let running = try LabF03Closeout.analyze(
            receiptData: receipt,
            eventData: try eventData([event]),
            currentGeneration: 7,
            writeAccounting: accounting,
            flushAcknowledgement: acknowledgement(accounting),
            previewProcessesStopped: false,
            installedIdentityVerified: true,
            generatedAt: generated
        )
        #expect(running.blockers.contains(.previewProcessesNotStopped))
        #expect(!running.decisionGradeEligible)

        let replacedInstall = try LabF03Closeout.analyze(
            receiptData: receipt,
            eventData: try eventData([event]),
            currentGeneration: 7,
            writeAccounting: accounting,
            flushAcknowledgement: acknowledgement(accounting),
            previewProcessesStopped: true,
            installedIdentityVerified: false,
            generatedAt: generated
        )
        #expect(replacedInstall.blockers.contains(.installedIdentityMismatch))
    }

    @Test("Legacy schemas, duplicate IDs, and conflicting duplicate IDs cannot close")
    func schemaAndDuplicateBlockers() throws {
        let id = UUID()
        let current = acceptedEvent(id: id, at: rotation.addingTimeInterval(120))
        let legacy = acceptedEvent(
            id: UUID(), at: rotation.addingTimeInterval(121),
            schema: LabOnlineExperimentEvent.legacySchemaV2
        )
        let schemaReport = try closeout(events: [current, legacy])
        #expect(schemaReport.blockers.contains(.nonCurrentEventSchema))

        let duplicate = try closeout(events: [current, current])
        #expect(duplicate.blockers.contains(.duplicateEventIDs))
        #expect(!duplicate.blockers.contains(.conflictingEventIDs))

        let conflict = acceptedEvent(
            id: id, at: rotation.addingTimeInterval(120), outcome: .acceptedWord
        )
        let conflicting = try closeout(events: [current, conflict])
        #expect(conflicting.blockers.contains(.duplicateEventIDs))
        #expect(conflicting.blockers.contains(.conflictingEventIDs))
    }

    @Test("Wrong campaign and pre-rotation rows remain visible but non-promotable")
    func attributionBlockers() throws {
        let wrongCampaign = acceptedEvent(
            campaignID: UUID(), at: rotation.addingTimeInterval(120)
        )
        let wrong = try closeout(events: [wrongCampaign])
        #expect(wrong.blockers.contains(.nonInstrumentCampaign))

        let early = acceptedEvent(at: rotation.addingTimeInterval(-1))
        let preRotation = try closeout(events: [early])
        #expect(preRotation.blockers.contains(.eventBeforeRotation))
    }

    @Test("A file without accepted retained observations cannot close F03")
    func acceptedCoverageRequired() throws {
        let report = try closeout(events: [dismissedEvent(at: rotation.addingTimeInterval(120))])
        #expect(report.blockers.contains(.missingAcceptedEvents))
        #expect(report.blockers.contains(.missingFiveSecondCoverage))
        #expect(report.blockers.contains(.missingThirtySecondCoverage))
        #expect(report.blockers.contains(.missingSegmentCoverage))
    }

    @Test("Capture derives Preview9B paths and suite, locks synthetic files, and refuses a running process")
    func secureCaptureAndProcessProbe() throws {
        let fixture = try SecureFixture(receipt: receiptData(), events: [
            acceptedEvent(at: rotation.addingTimeInterval(120)),
        ])
        defer { fixture.cleanUp() }
        var observedSuite: String?
        var processChecks = 0
        let report = try LabF03Closeout.capture(
            receiptURL: fixture.receiptURL,
            homeDirectory: fixture.home,
            generatedAt: generated,
            preferencesProvider: { suite in
                observedSuite = suite
                return fixture.defaults
            },
            stoppedProcessProvider: { urls in
                processChecks += 1
                #expect(urls.count == 3)
                #expect(urls[0].path == "/Applications/Tilde 9B Preview.app/Contents/MacOS/Tilde")
                #expect(urls[2].path.hasSuffix(
                    "/Library/Input Methods/InlineGhostIME 9B Preview.app/Contents/MacOS/InlineGhostIME"
                ))
                return true
            },
            installedIdentityProvider: { _, _ in true }
        )
        #expect(report.decisionGradeEligible)
        #expect(observedSuite == TildeProductProfile.preview9B.inputMethodBundleIdentifier)
        #expect(observedSuite != TildeProductProfile.production.inputMethodBundleIdentifier)
        #expect(processChecks == 2)

        let replacedInstall = try LabF03Closeout.capture(
            receiptURL: fixture.receiptURL,
            homeDirectory: fixture.home,
            generatedAt: generated,
            preferencesProvider: { _ in fixture.defaults },
            stoppedProcessProvider: { _ in true },
            installedIdentityProvider: { receipt, home in
                #expect(receipt.profile == .preview9B)
                #expect(home == fixture.home)
                return false
            }
        )
        #expect(replacedInstall.blockers.contains(.installedIdentityMismatch))

        do {
            let descriptor = open(fixture.maintenanceLockURL.path, O_RDWR | O_CLOEXEC)
            #expect(descriptor >= 0)
            defer { if descriptor >= 0 { close(descriptor) } }
            #expect(flock(descriptor, LOCK_EX | LOCK_NB) == 0)
            #expect(throws: LabF03CloseoutError.maintenanceLockUnavailable) {
                try fixture.capture(generatedAt: generated)
            }
        }

        fixture.defaults.set(
            [
                "attempted": 1, "written": 1,
                "flushedAttempted": 1, "flushedWritten": 1, "flushedDropped": 0,
                "flushedAtMilliseconds": Int64(1_777_593_780_000),
            ],
            forKey: PersonalHistorySettingsContract.outcomeLedgerWriteCountsKey(7)
        )
        let sparseZeroCounts = try fixture.capture(generatedAt: generated)
        #expect(sparseZeroCounts.decisionGradeEligible)

        fixture.defaults.set(
            [
                "attempted": 1, "written": 1, "unexpected": 0,
                "flushedAttempted": 1, "flushedWritten": 1, "flushedDropped": 0,
                "flushedAtMilliseconds": Int64(1_777_593_780_000),
            ],
            forKey: PersonalHistorySettingsContract.outcomeLedgerWriteCountsKey(7)
        )
        #expect(throws: LabF03CloseoutError.invalidWriteAccounting) {
            try fixture.capture(generatedAt: generated)
        }

        #expect(throws: LabF03CloseoutError.previewProcessesStillRunning) {
            try LabF03Closeout.capture(
                receiptURL: fixture.receiptURL,
                homeDirectory: fixture.home,
                generatedAt: generated,
                preferencesProvider: { _ in fixture.defaults },
                stoppedProcessProvider: { _ in false }
            )
        }
    }

    @Test("Capture rejects symlink, hard-link, file-mode, directory-mode, and receipt-mode attacks")
    func secureFileRefusals() throws {
        try withFixture { fixture in
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o644], ofItemAtPath: fixture.maintenanceLockURL.path
            )
            #expect(throws: LabF03CloseoutError.unsafeMaintenanceLock) {
                try fixture.capture(generatedAt: generated)
            }
        }
        try withFixture { fixture in
            let target = fixture.root.appendingPathComponent("receipt-target.json")
            try receiptData().write(to: target)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600], ofItemAtPath: target.path
            )
            try FileManager.default.removeItem(at: fixture.receiptURL)
            try FileManager.default.createSymbolicLink(
                at: fixture.receiptURL, withDestinationURL: target
            )
            #expect(throws: LabF03CloseoutError.unsafeReceiptFile) {
                try fixture.capture(generatedAt: generated)
            }
        }
        try withFixture { fixture in
            let link = fixture.root.appendingPathComponent("second-receipt-link.json")
            try FileManager.default.linkItem(at: fixture.receiptURL, to: link)
            #expect(throws: LabF03CloseoutError.unsafeReceiptFile) {
                try fixture.capture(generatedAt: generated)
            }
        }
        try withFixture { fixture in
            let target = fixture.root.appendingPathComponent("target.jsonl")
            try eventData([acceptedEvent(at: rotation.addingTimeInterval(120))]).write(to: target)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: target.path)
            try FileManager.default.removeItem(at: fixture.eventURL)
            try FileManager.default.createSymbolicLink(at: fixture.eventURL, withDestinationURL: target)
            try expectUnsafeEvent(fixture)
        }
        try withFixture { fixture in
            let link = fixture.root.appendingPathComponent("second-link.jsonl")
            try FileManager.default.linkItem(at: fixture.eventURL, to: link)
            try expectUnsafeEvent(fixture)
        }
        try withFixture { fixture in
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o644], ofItemAtPath: fixture.eventURL.path
            )
            try expectUnsafeEvent(fixture)
        }
        try withFixture { fixture in
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: fixture.eventURL.deletingLastPathComponent().path
            )
            try expectUnsafeEvent(fixture)
        }
        try withFixture { fixture in
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o644], ofItemAtPath: fixture.receiptURL.path
            )
            #expect(throws: LabF03CloseoutError.unsafeReceiptFile) {
                try fixture.capture(generatedAt: generated)
            }
        }
    }

    @Test("Closeout output is owner-only and never overwritten")
    func outputRefusesOverwrite() throws {
        let report = try closeout(events: [acceptedEvent(at: rotation.addingTimeInterval(120))])
        let root = URL(fileURLWithPath: "/private/tmp", isDirectory: true)
            .appendingPathComponent("tilde-f03-output-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let output = root.appendingPathComponent("closeout.json")
        try LabF03Closeout.writeNew(report, to: output)
        let permissions = try #require(
            try FileManager.default.attributesOfItem(atPath: output.path)[.posixPermissions] as? Int
        )
        #expect(permissions & 0o777 == 0o600)
        #expect(throws: LabF03CloseoutError.outputExists) {
            try LabF03Closeout.writeNew(report, to: output)
        }
        let decoded = try JSONDecoder.withISO8601.decode(
            LabF03CloseoutReport.self, from: Data(contentsOf: output)
        )
        #expect(decoded == report)
    }

    @Test("Installed identity files are owned, single-link, and never group/world writable")
    func installedIdentityFileSafety() throws {
        let root = URL(fileURLWithPath: "/private/tmp", isDirectory: true)
            .appendingPathComponent("tilde-f03-identity-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("artifact")
        let bytes = Data("synthetic-package-artifact".utf8)
        try bytes.write(to: file)
        let digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()

        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        #expect(LabF03Closeout.verifiedFileDigest(
            file, maximumBytes: 1_024, requiredMode: 0o600
        ) == digest)

        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: file.path)
        #expect(LabF03Closeout.verifiedFileDigest(
            file, maximumBytes: 1_024, requiredMode: 0o600
        ) == nil)
        #expect(LabF03Closeout.verifiedFileDigest(file, maximumBytes: 1_024) == digest)

        try FileManager.default.setAttributes([.posixPermissions: 0o666], ofItemAtPath: file.path)
        #expect(LabF03Closeout.verifiedFileDigest(file, maximumBytes: 1_024) == nil)

        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        try FileManager.default.linkItem(at: file, to: root.appendingPathComponent("second-link"))
        #expect(LabF03Closeout.verifiedFileDigest(
            file, maximumBytes: 1_024, requiredMode: 0o600
        ) == nil)
    }

    private func closeout(
        receipt: Data? = nil,
        events: [LabOnlineExperimentEvent]
    ) throws -> LabF03CloseoutReport {
        let receipt = try receipt ?? receiptData()
        let accounting = try LabF03WriteAccounting(
            attempted: events.count, written: events.count, dropped: 0
        )
        return try LabF03Closeout.analyze(
            receiptData: receipt,
            eventData: eventData(events),
            currentGeneration: 7,
            writeAccounting: accounting,
            flushAcknowledgement: acknowledgement(accounting),
            previewProcessesStopped: true,
            installedIdentityVerified: true,
            generatedAt: generated
        )
    }

    private func acknowledgement(
        _ accounting: LabF03WriteAccounting
    ) -> LabF03FlushAcknowledgement {
        LabF03FlushAcknowledgement(
            writeAccounting: accounting,
            acknowledgedAt: rotation.addingTimeInterval(180)
        )
    }

    private func receiptData() throws -> Data { try json(receiptObject()) }

    private func receiptObject() -> [String: Any] {
        [
            "schema": LabF03RunReceipt.currentSchema,
            "runID": "11111111-1111-1111-1111-111111111111",
            "profile": "preview-9b",
            "evidenceClass": "decision-grade",
            "sourceState": "clean",
            "sourceCommit": String(repeating: "0", count: 40),
            "sourceTree": String(repeating: "1", count: 40),
            "sourceSnapshotSHA256": String(repeating: "2", count: 64),
            "bundleVersion": "0.1.0-preview9b",
            "bundleBuild": "123",
            "installedAppBinarySHA256": String(repeating: "3", count: 64),
            "installedIMEBinarySHA256": String(repeating: "4", count: 64),
            "installedHelperSHA256": String(repeating: "5", count: 64),
            "installedAppInfoPlistSHA256": String(repeating: "6", count: 64),
            "installedIMEInfoPlistSHA256": String(repeating: "7", count: 64),
            "rotationTimestamp": "2026-05-01T00:00:00Z",
            "completedTimestamp": "2026-05-01T00:01:00Z",
            "previousLedgerDisposition": "absent",
            "previousLedgerBytes": 0,
            "previousLedgerSHA256": NSNull(),
            "outcomeLedgerGeneration": 7,
            "signingTeamIdentifier": "TEAMID1234",
            "modelSHA256": String(repeating: "8", count: 64),
            "modelBytes": 5_629_109_312,
            "operatingSystemVersion": "26.6.2",
            "operatingSystemBuild": "25G83",
            "architecture": "arm64",
            "hardwareModel": "Mac16,7",
            "powerSource": "ac",
            "appReady": true,
            "inputMethodBundleInstalled": true,
            "inputMethodRegistrationVerified": true,
            "helperReady": true,
        ]
    }

    private func json(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    private func eventData(_ events: [LabOnlineExperimentEvent]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        var data = Data()
        for event in events {
            data.append(try encoder.encode(event))
            data.append(0x0A)
        }
        return data
    }

    private func acceptedEvent(
        id: UUID = UUID(),
        campaignID: UUID = LabInstrumentCampaign.id,
        at date: Date,
        outcome: LabOnlineInteractionOutcome = .acceptedAll,
        schema: String = LabOnlineExperimentEvent.currentSchema
    ) -> LabOnlineExperimentEvent {
        LabOnlineExperimentEvent(
            id: id,
            campaignID: campaignID,
            occurredAt: date,
            sessionDigestSHA256: String(repeating: "f", count: 64),
            variant: .champion,
            appCategory: .prose,
            register: .prose,
            boundary: .wordBoundary,
            typingSpeedBucket: .medium,
            safeOpportunity: true,
            displayed: true,
            outcome: outcome,
            acceptedCharacters: 5,
            replacedCharactersWithin5Seconds: 0,
            candidateCharacters: 5,
            opportunityCharacters: 10,
            candidateSourceBucket: .generator,
            candidateLengthBucket: .oneWord,
            settledVisibleMilliseconds: 300,
            retentionAt5Seconds: try! RetainedCharacterObservation(retainedCharacters: 5),
            retentionAt30Seconds: try! RetainedCharacterObservation(retainedCharacters: 4),
            retentionAtSegmentClose: try! RetainedCharacterObservation(retainedCharacters: 3),
            schema: schema
        )
    }

    private func dismissedEvent(at date: Date) -> LabOnlineExperimentEvent {
        LabOnlineExperimentEvent(
            campaignID: LabInstrumentCampaign.id,
            occurredAt: date,
            sessionDigestSHA256: String(repeating: "e", count: 64),
            variant: .champion,
            appCategory: .prose,
            register: .prose,
            boundary: .wordBoundary,
            typingSpeedBucket: .medium,
            safeOpportunity: true,
            displayed: true,
            outcome: .dismissed,
            candidateCharacters: 5,
            opportunityCharacters: 10,
            candidateSourceBucket: .generator,
            candidateLengthBucket: .oneWord,
            settledVisibleMilliseconds: 300
        )
    }

    private func withFixture(_ body: (SecureFixture) throws -> Void) throws {
        let fixture = try SecureFixture(receipt: receiptData(), events: [
            acceptedEvent(at: rotation.addingTimeInterval(120)),
        ])
        defer { fixture.cleanUp() }
        try body(fixture)
    }

    private func expectUnsafeEvent(_ fixture: SecureFixture) throws {
        #expect(throws: LabF03CloseoutError.unsafeEventFile) {
            try fixture.capture(generatedAt: generated)
        }
    }

    private final class SecureFixture {
        let root: URL
        let home: URL
        let receiptURL: URL
        let eventURL: URL
        let maintenanceLockURL: URL
        let defaults: UserDefaults
        private let suite: String

        init(receipt: Data, events: [LabOnlineExperimentEvent]) throws {
            root = URL(fileURLWithPath: "/private/tmp", isDirectory: true)
                .appendingPathComponent("tilde-f03-closeout-\(UUID().uuidString)", isDirectory: true)
            home = root.appendingPathComponent("home", isDirectory: true)
            let receiptDirectory = root.appendingPathComponent("receipt", isDirectory: true)
            receiptURL = receiptDirectory.appendingPathComponent("receipt.json")
            eventURL = TextFreeOnlineEventFile.url(
                homeDirectory: home,
                supportDirectoryName: TildeProductProfile.preview9B.supportDirectoryName
            )
            let supportDirectory = eventURL.deletingLastPathComponent().deletingLastPathComponent()
            maintenanceLockURL = supportDirectory.appendingPathComponent(
                ".f03-maintenance.lock"
            )
            suite = "tilde.test.f03-closeout.\(UUID().uuidString)"
            defaults = try #require(UserDefaults(suiteName: suite))
            defaults.removePersistentDomain(forName: suite)

            try FileManager.default.createDirectory(
                at: receiptDirectory, withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            try FileManager.default.createDirectory(
                at: eventURL.deletingLastPathComponent(), withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o700], ofItemAtPath: receiptDirectory.path
            )
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o700],
                ofItemAtPath: eventURL.deletingLastPathComponent().path
            )
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o700], ofItemAtPath: supportDirectory.path
            )
            try receipt.write(to: receiptURL)
            try eventData(events).write(to: eventURL)
            try Data().write(to: maintenanceLockURL)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600], ofItemAtPath: receiptURL.path
            )
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600], ofItemAtPath: eventURL.path
            )
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600], ofItemAtPath: maintenanceLockURL.path
            )
            defaults.set(7, forKey: PersonalHistorySettingsContract.outcomeLedgerGenerationKey)
            let count = events.count
            defaults.set(
                [
                    "attempted": count, "written": count, "dropped": 0,
                    "flushedAttempted": count, "flushedWritten": count, "flushedDropped": 0,
                    "flushedAtMilliseconds": Int64(1_777_593_780_000),
                ],
                forKey: PersonalHistorySettingsContract.outcomeLedgerWriteCountsKey(7)
            )
        }

        func capture(generatedAt: Date) throws -> LabF03CloseoutReport {
            try LabF03Closeout.capture(
                receiptURL: receiptURL,
                homeDirectory: home,
                generatedAt: generatedAt,
                preferencesProvider: { _ in self.defaults },
                stoppedProcessProvider: { _ in true },
                installedIdentityProvider: { _, _ in true }
            )
        }

        func cleanUp() {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: root)
        }

        private func eventData(_ events: [LabOnlineExperimentEvent]) throws -> Data {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.sortedKeys]
            var data = Data()
            for event in events {
                data.append(try encoder.encode(event))
                data.append(0x0A)
            }
            return data
        }
    }
}

private extension JSONDecoder {
    static var withISO8601: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
