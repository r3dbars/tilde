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

    private enum InjectedFailure: Error, Equatable {
        case beforePublication
        case afterPublication
        case generationPersistence
    }

    @Test("Analysis alone remains path-free but cannot claim a terminal decision-grade snapshot")
    func unsealedAnalysis() throws {
        let receipt = try receiptData()
        let event = acceptedEvent(at: rotation.addingTimeInterval(120))
        let report = try closeout(receipt: receipt, events: [event])

        #expect(report.schema == LabF03CloseoutReport.currentSchema)
        #expect(report.profile == TildeProductProfile.preview9B.rawValue)
        #expect(report.runnerSHA256 == String(repeating: "9", count: 64))
        #expect(report.invocationProfile == "preview9b-owner-approved-v1")
        #expect(!report.terminalSnapshotSealed)
        #expect(!report.decisionGradeEligible)
        #expect(report.blockers == [.terminalSnapshotUnsealed])
        #expect(report.eventRows == 1)
        #expect(report.eventSchemaCounts == [LabOnlineExperimentEvent.currentSchema: 1])
        #expect(report.aggregateReport.retentionAt5Seconds.observedEvents == 1)
        #expect(report.aggregateReport.retentionAt30Seconds.observedEvents == 1)
        #expect(report.aggregateReport.retentionAtSegmentClose.observedEvents == 1)
        #expect(
            report.sourcePackageIdentity.signingTeamIdentifier
                == LabF03RunReceipt.registeredHelperTeamIdentifier
        )
        #expect(report.sourcePackageIdentity.appleToolchainSHA256
            == fixtureToolchainIdentitySHA256())
        #expect(report.sourcePackageIdentity.xcodeBuild == "17F113")
        #expect(report.sourcePackageIdentity.macOSSDKBuild == "25F70")
        #expect(report.sourcePackageIdentity.macOSSDKSettingsSHA256 == String(repeating: "e", count: 64))
        #expect(
            report.sourcePackageIdentity.approvedHelperTeamIdentifier
                == LabF03RunReceipt.registeredHelperTeamIdentifier
        )
        #expect(
            report.sourcePackageIdentity.installedHelperSHA256
                == LabF03RunReceipt.registeredHelperInputSHA256
        )
        #expect(report.sourcePackageIdentity.modelBytes == LabF03RunReceipt.registeredModelBytes)
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

        for field in [
            "sourceCommit", "sourceTree", "sourceSnapshotSHA256", "runnerSHA256",
            "appleToolchainSHA256", "swiftVersionSHA256", "swiftExecutableSHA256",
            "macOSSDKSettingsSHA256", "approvedHelperInputSHA256", "modelSHA256",
        ] {
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

        var badInvocation = receiptObject()
        badInvocation["invocationProfile"] = "ad-hoc"
        #expect(throws: LabF03CloseoutError.invalidReceiptField("invocationProfile")) {
            try LabF03RunReceipt.decode(try json(badInvocation))
        }

        for field in ["xcodeVersion", "macOSSDKVersion"] {
            var malformed = receiptObject()
            malformed[field] = "26/path"
            #expect(throws: LabF03CloseoutError.invalidReceiptField(field)) {
                try LabF03RunReceipt.decode(try json(malformed))
            }
        }

        for field in ["xcodeBuild", "macOSSDKBuild"] {
            var malformed = receiptObject()
            malformed[field] = "build value"
            #expect(throws: LabF03CloseoutError.invalidReceiptField(field)) {
                try LabF03RunReceipt.decode(try json(malformed))
            }
        }

        var mismatchedHelperTeam = receiptObject()
        mismatchedHelperTeam["approvedHelperTeamIdentifier"] = "OTHERID123"
        #expect(throws: LabF03CloseoutError.invalidReceiptField(
            "approvedHelperTeamIdentifier"
        )) {
            try LabF03RunReceipt.decode(try json(mismatchedHelperTeam))
        }

        var unregisteredHelper = receiptObject()
        unregisteredHelper["approvedHelperInputSHA256"] = String(repeating: "f", count: 64)
        #expect(throws: LabF03CloseoutError.invalidReceiptField(
            "approvedHelperInputSHA256"
        )) {
            try LabF03RunReceipt.decode(try json(unregisteredHelper))
        }

        var mismatchedInstalledHelper = receiptObject()
        mismatchedInstalledHelper["installedHelperSHA256"] = String(repeating: "f", count: 64)
        #expect(throws: LabF03CloseoutError.invalidReceiptField("installedHelperSHA256")) {
            try LabF03RunReceipt.decode(try json(mismatchedInstalledHelper))
        }

        var unregisteredModel = receiptObject()
        unregisteredModel["modelSHA256"] = String(repeating: "f", count: 64)
        #expect(throws: LabF03CloseoutError.invalidReceiptField("modelSHA256")) {
            try LabF03RunReceipt.decode(try json(unregisteredModel))
        }

        var wrongModelBytes = receiptObject()
        wrongModelBytes["modelBytes"] = LabF03RunReceipt.registeredModelBytes - 1
        #expect(throws: LabF03CloseoutError.invalidReceiptField("modelBytes")) {
            try LabF03RunReceipt.decode(try json(wrongModelBytes))
        }
    }

    @Test("The guarded shell producer emits a receipt the Swift closeout accepts")
    func shellProducerReceiptCompatibility() throws {
        let root = URL(fileURLWithPath: "/private/tmp", isDirectory: true)
            .appendingPathComponent("tilde-f03-contract-\(UUID().uuidString)", isDirectory: true)
        let receiptURL = root.appendingPathComponent("receipt.json")
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        defer { try? FileManager.default.removeItem(at: root) }

        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [
            repository.appendingPathComponent("script/f03_preview_run.sh").path,
            "--selftest-write-receipt",
            receiptURL.path,
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)

        let attributes = try FileManager.default.attributesOfItem(atPath: receiptURL.path)
        #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
        let receipt = try LabF03RunReceipt.decode(Data(contentsOf: receiptURL))
        #expect(receipt.runnerSHA256 == String(repeating: "9", count: 64))
        #expect(receipt.invocationProfile == "preview9b-owner-approved-v1")
        #expect(receipt.sourcePackageIdentity.appleToolchainSHA256
            == String(repeating: "a", count: 64))
        #expect(receipt.sourcePackageIdentity.macOSSDKSettingsSHA256 == String(repeating: "e", count: 64))
        #expect(
            receipt.sourcePackageIdentity.approvedHelperTeamIdentifier
                == LabF03RunReceipt.registeredHelperTeamIdentifier
        )
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
        #expect(unverifiedReport.blockers == [
            .inputMethodRegistrationUnverified,
            .terminalSnapshotUnsealed,
        ])

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

    @Test("Process classification catches relocated Preview9B code and helpers without a live probe")
    func previewProcessClassification() {
        let expected = LabF03Closeout.previewProcessURLs(
            profile: .preview9B,
            homeDirectory: URL(fileURLWithPath: "/private/tmp/synthetic-owner")
        )
        let helperIdentity = LabF03Closeout.PreviewProcessSigningIdentity(
            identifier: "llama-server",
            teamIdentifier: "XG6WL66WUQ",
            cdHash: Data(repeating: 0xA5, count: 20)
        )
        func kind(
            path: String,
            identity: LabF03Closeout.PreviewProcessSigningIdentity? = nil
        ) -> LabF03Closeout.PreviewProcessKind? {
            LabF03Closeout.previewProcessKind(
                .init(executablePath: path, signingIdentity: identity),
                expectedExecutables: expected,
                expectedHelperIdentity: helperIdentity
            )
        }

        #expect(kind(path: expected[0].path) == .app)
        #expect(kind(path: expected[1].path) == .helper)
        #expect(kind(path: expected[2].path) == .inputMethod)
        #expect(kind(
            path: "/private/tmp/moved/Tilde",
            identity: .init(
                identifier: TildeProductProfile.preview9B.appBundleIdentifier,
                teamIdentifier: "XG6WL66WUQ",
                cdHash: Data(repeating: 0x11, count: 20)
            )
        ) == .app)
        #expect(kind(
            path: "/private/tmp/replaced/InlineGhostIME",
            identity: .init(
                identifier: TildeProductProfile.preview9B.inputMethodBundleIdentifier,
                teamIdentifier: "XG6WL66WUQ",
                cdHash: Data(repeating: 0x22, count: 20)
            )
        ) == .inputMethod)
        #expect(kind(
            path: "/private/tmp/renamed-helper",
            identity: helperIdentity
        ) == .helper)
        #expect(kind(
            path: "/private/tmp/Tilde 9B Preview.app.f03-backup/Contents/Helpers/llama-server"
        ) == .helper)
        #expect(kind(path: "/private/tmp/llama-server-preview9b") == .helper)

        #expect(kind(
            path: "/Applications/Tilde Model Preview.app/Contents/Helpers/llama-server",
            identity: helperIdentity
        ) == nil)
        #expect(kind(
            path: "/Applications/Tilde 26B Preview.app/Contents/Helpers/llama-server",
            identity: helperIdentity
        ) == nil)
        #expect(kind(
            path: "/Applications/Tilde.app/Contents/Helpers/llama-server",
            identity: helperIdentity
        ) == nil)
        #expect(kind(
            path: "/private/tmp/unrelated/Tilde",
            identity: .init(
                identifier: "example.unrelated",
                teamIdentifier: nil,
                cdHash: nil
            )
        ) == nil)
        #expect(kind(path: "relative/llama-server-preview9b") == nil)
        #expect(LabF03Closeout.isPotentialPreviewExecutableName("Tilde"))
        #expect(LabF03Closeout.isPotentialPreviewExecutableName("InlineGhostIME"))
        #expect(LabF03Closeout.isPotentialPreviewExecutableName("llama-server (deleted)"))
        #expect(!LabF03Closeout.isPotentialPreviewExecutableName("swift-frontend"))
        #expect(!LabF03Closeout.isPotentialPreviewExecutableName("TildeLab"))
    }

    @Test("lsof result parsing fails closed on malformed or diagnostic output")
    func lsofResultParsing() {
        #expect(LabF03Closeout.lsofReportsProcesses(
            terminationStatus: 1,
            standardOutput: Data(),
            standardError: Data()
        ) == false)
        #expect(LabF03Closeout.lsofReportsProcesses(
            terminationStatus: 0,
            standardOutput: Data("56927\n56451\n".utf8),
            standardError: Data()
        ) == true)
        for (status, output, error) in [
            (Int32(0), Data(), Data()),
            (Int32(0), Data("not-a-pid\n".utf8), Data()),
            (Int32(1), Data("56927\n".utf8), Data()),
            (Int32(2), Data(), Data()),
            (Int32(1), Data(), Data("diagnostic".utf8)),
        ] {
            #expect(LabF03Closeout.lsofReportsProcesses(
                terminationStatus: status,
                standardOutput: output,
                standardError: error
            ) == nil)
        }
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
        #expect(throws: LabF03CloseoutError.terminalSealFailed) {
            try LabF03Closeout.capture(
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
        }
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
        #expect(throws: LabF03CloseoutError.terminalSealFailed) {
            try fixture.capture(generatedAt: generated)
        }

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

    @Test("An unfinished maintenance journal blocks closeout at entry and at the terminal gate")
    func unfinishedMaintenanceTransactionBlocksCloseout() throws {
        for name in [".f03-transaction.json", ".f03-transaction.tmp"] {
            try withFixture { fixture in
                let journal = fixture.maintenanceLockURL.deletingLastPathComponent()
                    .appendingPathComponent(name)
                try Data().write(to: journal)
                try FileManager.default.setAttributes(
                    [.posixPermissions: 0o600], ofItemAtPath: journal.path
                )
                #expect(throws: LabF03CloseoutError.unfinishedMaintenanceTransaction) {
                    try fixture.capture(generatedAt: generated)
                }
            }
        }

        try withFixture { fixture in
            let output = fixture.root.appendingPathComponent("closeout.json")
            let journal = fixture.maintenanceLockURL.deletingLastPathComponent()
                .appendingPathComponent(".f03-transaction.json")
            let closed = fixture.eventURL.deletingLastPathComponent().appendingPathComponent(
                "events.closed-11111111-1111-1111-1111-111111111111.jsonl"
            )
            var identityChecks = 0
            #expect(throws: LabF03CloseoutError.unfinishedMaintenanceTransaction) {
                try LabF03Closeout.capture(
                    receiptURL: fixture.receiptURL,
                    homeDirectory: fixture.home,
                    generatedAt: generated,
                    preferencesProvider: { _ in fixture.defaults },
                    stoppedProcessProvider: { _ in true },
                    installedIdentityProvider: { _, _ in
                        identityChecks += 1
                        if identityChecks == 2 {
                            #expect(FileManager.default.createFile(
                                atPath: journal.path, contents: Data()
                            ))
                        }
                        return true
                    },
                    outputURL: output
                )
            }
            #expect(identityChecks == 2)
            #expect(fixture.defaults.integer(
                forKey: PersonalHistorySettingsContract.outcomeLedgerGenerationKey
            ) == 7)
            #expect(FileManager.default.fileExists(atPath: fixture.eventURL.path))
            #expect(!FileManager.default.fileExists(atPath: closed.path))
            #expect(!FileManager.default.fileExists(atPath: output.path))
        }

    }

    @Test("Closeout rejects support-directory namespace replacement after locking")
    func maintenanceLockBindsVisibleSupportDirectory() throws {
        let fixture = try SecureFixture(receipt: receiptData(), events: [
            acceptedEvent(at: rotation.addingTimeInterval(120)),
        ])
        defer { fixture.cleanUp() }
        let support = fixture.maintenanceLockURL.deletingLastPathComponent()
        let movedSupport = support.deletingLastPathComponent().appendingPathComponent(
            "Tilde 9B Preview moved", isDirectory: true
        )
        let replacementOutcome = support.appendingPathComponent(
            "Outcome Ledger", isDirectory: true
        )
        let output = fixture.root.appendingPathComponent("closeout.json")
        var processChecks = 0

        #expect(throws: LabF03CloseoutError.unsafeMaintenanceLock) {
            try LabF03Closeout.capture(
                receiptURL: fixture.receiptURL,
                homeDirectory: fixture.home,
                generatedAt: generated,
                preferencesProvider: { _ in fixture.defaults },
                stoppedProcessProvider: { _ in
                    processChecks += 1
                    guard processChecks == 1 else { return true }
                    try! FileManager.default.moveItem(at: support, to: movedSupport)
                    try! FileManager.default.createDirectory(
                        at: support,
                        withIntermediateDirectories: false,
                        attributes: [.posixPermissions: 0o700]
                    )
                    try! FileManager.default.createDirectory(
                        at: replacementOutcome,
                        withIntermediateDirectories: false,
                        attributes: [.posixPermissions: 0o700]
                    )
                    let movedEvent = movedSupport
                        .appendingPathComponent("Outcome Ledger", isDirectory: true)
                        .appendingPathComponent("events.jsonl")
                    try! Data(contentsOf: movedEvent).write(to: fixture.eventURL)
                    try! FileManager.default.setAttributes(
                        [.posixPermissions: 0o600], ofItemAtPath: fixture.eventURL.path
                    )
                    try! Data().write(to: fixture.maintenanceLockURL)
                    try! FileManager.default.setAttributes(
                        [.posixPermissions: 0o600],
                        ofItemAtPath: fixture.maintenanceLockURL.path
                    )
                    return true
                },
                installedIdentityProvider: { _, _ in true },
                outputURL: output
            )
        }
        #expect(processChecks == 1)
        #expect(fixture.defaults.integer(
            forKey: PersonalHistorySettingsContract.outcomeLedgerGenerationKey
        ) == 7)
        #expect(!FileManager.default.fileExists(atPath: output.path))
    }

    @Test("Installed package identity is rechecked immediately before closeout publication")
    func installedIdentityIsRecheckedLate() throws {
        try withFixture { fixture in
            var identityChecks = 0
            let report = try LabF03Closeout.capture(
                receiptURL: fixture.receiptURL,
                homeDirectory: fixture.home,
                generatedAt: generated,
                preferencesProvider: { _ in fixture.defaults },
                stoppedProcessProvider: { _ in true },
                installedIdentityProvider: { _, _ in
                    identityChecks += 1
                    return identityChecks == 1
                }
            )
            #expect(identityChecks == 2)
            #expect(!report.decisionGradeEligible)
            #expect(report.blockers.contains(.installedIdentityMismatch))
        }

        try withFixture { fixture in
            let output = fixture.root.appendingPathComponent("closeout.json")
            let closed = fixture.eventURL.deletingLastPathComponent().appendingPathComponent(
                "events.closed-11111111-1111-1111-1111-111111111111.jsonl"
            )
            var identityChecks = 0
            #expect(throws: LabF03CloseoutError.installedIdentityChanged) {
                try LabF03Closeout.capture(
                    receiptURL: fixture.receiptURL,
                    homeDirectory: fixture.home,
                    generatedAt: generated,
                    preferencesProvider: { _ in fixture.defaults },
                    stoppedProcessProvider: { _ in true },
                    installedIdentityProvider: { _, _ in
                        identityChecks += 1
                        return identityChecks == 1
                    },
                    outputURL: output
                )
            }
            #expect(identityChecks == 2)
            #expect(fixture.defaults.integer(
                forKey: PersonalHistorySettingsContract.outcomeLedgerGenerationKey
            ) == 7)
            #expect(FileManager.default.fileExists(atPath: fixture.eventURL.path))
            #expect(!FileManager.default.fileExists(atPath: closed.path))
            #expect(!FileManager.default.fileExists(atPath: output.path))
        }

        try withFixture { fixture in
            let output = fixture.root.appendingPathComponent("closeout.json")
            let closed = fixture.eventURL.deletingLastPathComponent().appendingPathComponent(
                "events.closed-11111111-1111-1111-1111-111111111111.jsonl"
            )
            var identityChecks = 0
            #expect(throws: LabF03CloseoutError.installedIdentityChanged) {
                try LabF03Closeout.capture(
                    receiptURL: fixture.receiptURL,
                    homeDirectory: fixture.home,
                    generatedAt: generated,
                    preferencesProvider: { _ in fixture.defaults },
                    stoppedProcessProvider: { _ in true },
                    installedIdentityProvider: { _, _ in
                        identityChecks += 1
                        // The first snapshot and pre-seal recheck both pass;
                        // replacement is exposed only at the report's atomic
                        // before-commit gate.
                        return identityChecks < 3
                    },
                    outputURL: output
                )
            }
            #expect(identityChecks == 3)
            #expect(fixture.defaults.integer(
                forKey: PersonalHistorySettingsContract.outcomeLedgerGenerationKey
            ) == 7)
            #expect(FileManager.default.fileExists(atPath: fixture.eventURL.path))
            #expect(!FileManager.default.fileExists(atPath: closed.path))
            #expect(!FileManager.default.fileExists(atPath: output.path))
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
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
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

        let unsafe = URL(fileURLWithPath: "/private/tmp", isDirectory: true)
            .appendingPathComponent("tilde-f03-unsafe-output-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: unsafe,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o755]
        )
        defer { try? FileManager.default.removeItem(at: unsafe) }
        #expect(throws: LabF03CloseoutError.outputWriteFailed) {
            try LabF03Closeout.writeNew(report, to: unsafe.appendingPathComponent("closeout.json"))
        }
        let decoded = try JSONDecoder.withISO8601.decode(
            LabF03CloseoutReport.self, from: Data(contentsOf: output)
        )
        #expect(decoded == report)
    }

    @Test("Eligible closeout seals its generation before a waiting writer can continue")
    func terminalCloseoutSealsGeneration() throws {
        let fixture = try SecureFixture(receipt: receiptData(), events: [
            acceptedEvent(at: rotation.addingTimeInterval(120)),
        ])
        defer { fixture.cleanUp() }
        let outputDirectory = fixture.root.appendingPathComponent("closeout", isDirectory: true)
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700], ofItemAtPath: outputDirectory.path
        )
        let output = outputDirectory.appendingPathComponent("closeout.json")
        let closed = fixture.eventURL.deletingLastPathComponent().appendingPathComponent(
            "events.closed-11111111-1111-1111-1111-111111111111.jsonl"
        )
        let started = fixture.root.appendingPathComponent("writer-started")
        let acquired = fixture.root.appendingPathComponent("writer-acquired")
        var checks = 0
        var writer: Process?

        let report = try LabF03Closeout.capture(
            receiptURL: fixture.receiptURL,
            homeDirectory: fixture.home,
            generatedAt: generated,
            preferencesProvider: { _ in fixture.defaults },
            stoppedProcessProvider: { _ in
                checks += 1
                guard checks == 2 else { return true }
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
                process.arguments = [
                    "-I", "-c",
                    """
                    import fcntl, os, sys
                    directory, started, acquired, output, closed = sys.argv[1:]
                    marker = os.open(started, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
                    os.close(marker)
                    descriptor = os.open(directory, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
                    try:
                        fcntl.flock(descriptor, fcntl.LOCK_EX)
                        value = f"{int(os.path.exists(output))}\\t{int(os.path.exists(closed))}\\n".encode()
                        marker = os.open(acquired, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
                        os.write(marker, value)
                        os.close(marker)
                    finally:
                        os.close(descriptor)
                    """,
                    fixture.eventURL.deletingLastPathComponent().path,
                    started.path,
                    acquired.path,
                    output.path,
                    closed.path,
                ]
                process.standardOutput = FileHandle.nullDevice
                process.standardError = FileHandle.nullDevice
                do { try process.run() } catch { return false }
                writer = process
                for _ in 0..<200 where !FileManager.default.fileExists(atPath: started.path) {
                    Thread.sleep(forTimeInterval: 0.005)
                }
                return FileManager.default.fileExists(atPath: started.path)
                    && !FileManager.default.fileExists(atPath: acquired.path)
            },
            installedIdentityProvider: { _, _ in true },
            outputURL: output
        )
        writer?.waitUntilExit()

        #expect(report.decisionGradeEligible)
        #expect(report.terminalSnapshotSealed)
        #expect(report.blockers.isEmpty)
        #expect(checks == 3)
        #expect(fixture.defaults.integer(
            forKey: PersonalHistorySettingsContract.outcomeLedgerGenerationKey
        ) == 8)
        #expect(!FileManager.default.fileExists(atPath: fixture.eventURL.path))
        #expect(FileManager.default.fileExists(atPath: closed.path))
        #expect(FileManager.default.fileExists(atPath: output.path))
        let persistedReport = try JSONDecoder.withISO8601.decode(
            LabF03CloseoutReport.self, from: Data(contentsOf: output)
        )
        #expect(persistedReport == report)
        #expect(persistedReport.terminalSnapshotSealed)
        #expect(try String(contentsOf: acquired, encoding: .utf8) == "1\t1\n")
    }

    @Test("Terminal closeout re-reads old-generation write accounting after sealing")
    func terminalCloseoutUsesFinalWriteAccounting() throws {
        let mutations: [(name: String, attempted: Int, written: Int, dropped: Int)] = [
            ("attempted-only", 2, 1, 0),
            ("dropped-write", 2, 1, 1),
            ("completed-write", 2, 2, 0),
        ]

        for mutation in mutations {
            let fixture = try SecureFixture(receipt: receiptData(), events: [
                acceptedEvent(at: rotation.addingTimeInterval(120)),
            ])
            defer { fixture.cleanUp() }
            let output = fixture.root.appendingPathComponent(
                "closeout-\(mutation.name).json"
            )
            let closed = fixture.eventURL.deletingLastPathComponent().appendingPathComponent(
                "events.closed-11111111-1111-1111-1111-111111111111.jsonl"
            )
            let countsKey = PersonalHistorySettingsContract.outcomeLedgerWriteCountsKey(7)
            var persistedGenerations: [Int] = []
            var terminalWriterCalled = false

            #expect(throws: LabF03CloseoutError.terminalSealFailed) {
                try LabF03Closeout.capture(
                    receiptURL: fixture.receiptURL,
                    homeDirectory: fixture.home,
                    generatedAt: generated,
                    preferencesProvider: { _ in fixture.defaults },
                    stoppedProcessProvider: { _ in true },
                    installedIdentityProvider: { _, _ in true },
                    outputURL: output,
                    terminalReportWriter: { _, _, beforeCommit in
                        terminalWriterCalled = true
                        try beforeCommit()
                        return .committed(postCommitChecksPassed: true)
                    },
                    generationPersister: { generation, defaults in
                        persistedGenerations.append(generation)
                        try persistGeneration(generation, in: defaults)
                        guard generation == 8 else { return }
                        defaults.set(
                            [
                                "attempted": mutation.attempted,
                                "written": mutation.written,
                                "dropped": mutation.dropped,
                                "flushedAttempted": 1,
                                "flushedWritten": 1,
                                "flushedDropped": 0,
                                "flushedAtMilliseconds": Int64(1_777_593_780_000),
                            ],
                            forKey: countsKey
                        )
                    }
                )
            }
            #expect(!terminalWriterCalled, "mutation: \(mutation.name)")
            #expect(persistedGenerations == [8, 7], "mutation: \(mutation.name)")
            #expect(fixture.defaults.integer(
                forKey: PersonalHistorySettingsContract.outcomeLedgerGenerationKey
            ) == 7, "mutation: \(mutation.name)")
            #expect(FileManager.default.fileExists(atPath: fixture.eventURL.path))
            #expect(!FileManager.default.fileExists(atPath: closed.path))
            #expect(!FileManager.default.fileExists(atPath: output.path))
        }
    }

    @Test("Terminal commit gate rejects a late old-generation accounting mutation")
    func terminalCloseoutRechecksWriteAccountingBeforeCommit() throws {
        let fixture = try SecureFixture(receipt: receiptData(), events: [
            acceptedEvent(at: rotation.addingTimeInterval(120)),
        ])
        defer { fixture.cleanUp() }
        let output = fixture.root.appendingPathComponent("closeout.json")
        let closed = fixture.eventURL.deletingLastPathComponent().appendingPathComponent(
            "events.closed-11111111-1111-1111-1111-111111111111.jsonl"
        )
        let countsKey = PersonalHistorySettingsContract.outcomeLedgerWriteCountsKey(7)
        var persistedGenerations: [Int] = []
        var beforeCommitCalled = false

        #expect(throws: LabF03CloseoutError.terminalSealFailed) {
            try LabF03Closeout.capture(
                receiptURL: fixture.receiptURL,
                homeDirectory: fixture.home,
                generatedAt: generated,
                preferencesProvider: { _ in fixture.defaults },
                stoppedProcessProvider: { _ in true },
                installedIdentityProvider: { _, _ in true },
                outputURL: output,
                terminalReportWriter: { report, output, beforeCommit in
                    try LabF03Closeout.writeNew(
                        report,
                        to: output,
                        beforeCommit: {
                            fixture.defaults.set(
                                [
                                    "attempted": 2,
                                    "written": 1,
                                    "dropped": 0,
                                    "flushedAttempted": 1,
                                    "flushedWritten": 1,
                                    "flushedDropped": 0,
                                    "flushedAtMilliseconds": Int64(1_777_593_780_000),
                                ],
                                forKey: countsKey
                            )
                            beforeCommitCalled = true
                            try beforeCommit()
                        }
                    )
                },
                generationPersister: { generation, defaults in
                    persistedGenerations.append(generation)
                    try persistGeneration(generation, in: defaults)
                }
            )
        }
        #expect(beforeCommitCalled)
        #expect(persistedGenerations == [8, 7])
        #expect(fixture.defaults.integer(
            forKey: PersonalHistorySettingsContract.outcomeLedgerGenerationKey
        ) == 7)
        #expect(FileManager.default.fileExists(atPath: fixture.eventURL.path))
        #expect(!FileManager.default.fileExists(atPath: closed.path))
        #expect(!FileManager.default.fileExists(atPath: output.path))
        let stagedOutputs = try FileManager.default.contentsOfDirectory(
            at: fixture.root,
            includingPropertiesForKeys: nil
        ).filter { $0.lastPathComponent.hasPrefix(".f03-closeout.") }
        #expect(stagedOutputs.isEmpty)
    }

    @Test("Failed terminal publication restores the event name and generation")
    func terminalCloseoutPublicationRollback() throws {
        let fixture = try SecureFixture(receipt: receiptData(), events: [
            acceptedEvent(at: rotation.addingTimeInterval(120)),
        ])
        defer { fixture.cleanUp() }
        let outputDirectory = fixture.root.appendingPathComponent("closeout", isDirectory: true)
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        let output = outputDirectory.appendingPathComponent("closeout.json")
        let existing = Data("existing-closeout".utf8)
        try existing.write(to: output)
        let closed = fixture.eventURL.deletingLastPathComponent().appendingPathComponent(
            "events.closed-11111111-1111-1111-1111-111111111111.jsonl"
        )

        #expect(throws: LabF03CloseoutError.outputExists) {
            try LabF03Closeout.capture(
                receiptURL: fixture.receiptURL,
                homeDirectory: fixture.home,
                generatedAt: generated,
                preferencesProvider: { _ in fixture.defaults },
                stoppedProcessProvider: { _ in true },
                installedIdentityProvider: { _, _ in true },
                outputURL: output
            )
        }
        #expect(fixture.defaults.integer(
            forKey: PersonalHistorySettingsContract.outcomeLedgerGenerationKey
        ) == 7)
        #expect(FileManager.default.fileExists(atPath: fixture.eventURL.path))
        #expect(!FileManager.default.fileExists(atPath: closed.path))
        #expect(try Data(contentsOf: output) == existing)
    }

    @Test("A post-rename path race preserves the seal but returns indeterminate evidence")
    func terminalCloseoutRejectsIndeterminatePublication() throws {
        let fixture = try SecureFixture(receipt: receiptData(), events: [
            acceptedEvent(at: rotation.addingTimeInterval(120)),
        ])
        defer { fixture.cleanUp() }
        let output = fixture.root.appendingPathComponent("closeout.json")
        let closed = fixture.eventURL.deletingLastPathComponent().appendingPathComponent(
            "events.closed-11111111-1111-1111-1111-111111111111.jsonl"
        )
        var postCommitProbeObserved = false
        var persistedGenerations: [Int] = []

        let report = try LabF03Closeout.capture(
            receiptURL: fixture.receiptURL,
            homeDirectory: fixture.home,
            generatedAt: generated,
            preferencesProvider: { _ in fixture.defaults },
            stoppedProcessProvider: { _ in true },
            installedIdentityProvider: { _, _ in true },
            outputURL: output,
            terminalReportWriter: { report, output, beforeCommit in
                #expect(report.terminalSnapshotSealed)
                #expect(report.decisionGradeEligible)
                #expect(FileManager.default.fileExists(atPath: closed.path))
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                return try NewOwnerFile.write(
                    try encoder.encode(report),
                    to: output,
                    beforeCommit: beforeCommit,
                    postCommitProbe: {
                        postCommitProbeObserved = true
                        #expect(FileManager.default.fileExists(atPath: output.path))
                        try FileManager.default.removeItem(at: output)
                        try Data("replacement-output".utf8).write(to: output)
                    }
                )
            },
            generationPersister: { generation, defaults in
                persistedGenerations.append(generation)
                try persistGeneration(generation, in: defaults)
            }
        )
        #expect(report.terminalSnapshotSealed)
        #expect(!report.decisionGradeEligible)
        #expect(report.blockers == [.terminalPublicationIndeterminate])
        #expect(postCommitProbeObserved)
        #expect(persistedGenerations == [8])
        #expect(fixture.defaults.integer(
            forKey: PersonalHistorySettingsContract.outcomeLedgerGenerationKey
        ) == 8)
        #expect(!FileManager.default.fileExists(atPath: fixture.eventURL.path))
        #expect(FileManager.default.fileExists(atPath: closed.path))
        #expect(try Data(contentsOf: output) == Data("replacement-output".utf8))
    }

    @Test("Rollback restores the generation before reopening its event file")
    func terminalCloseoutRollbackOrdering() throws {
        let fixture = try SecureFixture(receipt: receiptData(), events: [
            acceptedEvent(at: rotation.addingTimeInterval(120)),
        ])
        defer { fixture.cleanUp() }
        let output = fixture.root.appendingPathComponent("closeout.json")
        let closed = fixture.eventURL.deletingLastPathComponent().appendingPathComponent(
            "events.closed-11111111-1111-1111-1111-111111111111.jsonl"
        )
        var persistenceStates: [String] = []

        #expect(throws: InjectedFailure.beforePublication) {
            try LabF03Closeout.capture(
                receiptURL: fixture.receiptURL,
                homeDirectory: fixture.home,
                generatedAt: generated,
                preferencesProvider: { _ in fixture.defaults },
                stoppedProcessProvider: { _ in true },
                installedIdentityProvider: { _, _ in true },
                outputURL: output,
                terminalReportWriter: { _, _, _ in
                    throw InjectedFailure.beforePublication
                },
                generationPersister: { generation, defaults in
                    persistenceStates.append(
                        "\(generation):"
                            + "\(FileManager.default.fileExists(atPath: fixture.eventURL.path)):"
                            + "\(FileManager.default.fileExists(atPath: closed.path))"
                    )
                    try persistGeneration(generation, in: defaults)
                }
            )
        }
        #expect(persistenceStates == ["8:true:false", "7:false:true"])
        #expect(fixture.defaults.integer(
            forKey: PersonalHistorySettingsContract.outcomeLedgerGenerationKey
        ) == 7)
        #expect(FileManager.default.fileExists(atPath: fixture.eventURL.path))
        #expect(!FileManager.default.fileExists(atPath: closed.path))
    }

    @Test("A failed generation restore leaves the old event file sealed on the next generation")
    func terminalCloseoutFailedRestoreResealsGeneration() throws {
        let fixture = try SecureFixture(receipt: receiptData(), events: [
            acceptedEvent(at: rotation.addingTimeInterval(120)),
        ])
        defer { fixture.cleanUp() }
        let output = fixture.root.appendingPathComponent("closeout.json")
        let closed = fixture.eventURL.deletingLastPathComponent().appendingPathComponent(
            "events.closed-11111111-1111-1111-1111-111111111111.jsonl"
        )
        var persistedGenerations: [Int] = []

        #expect(throws: LabF03CloseoutError.terminalSealFailed) {
            try LabF03Closeout.capture(
                receiptURL: fixture.receiptURL,
                homeDirectory: fixture.home,
                generatedAt: generated,
                preferencesProvider: { _ in fixture.defaults },
                stoppedProcessProvider: { _ in true },
                installedIdentityProvider: { _, _ in true },
                outputURL: output,
                terminalReportWriter: { _, _, _ in
                    throw InjectedFailure.beforePublication
                },
                generationPersister: { generation, defaults in
                    persistedGenerations.append(generation)
                    if generation == 7 {
                        defaults.set(
                            generation,
                            forKey: PersonalHistorySettingsContract.outcomeLedgerGenerationKey
                        )
                        throw InjectedFailure.generationPersistence
                    }
                    try persistGeneration(generation, in: defaults)
                }
            )
        }
        #expect(persistedGenerations == [8, 7, 8])
        #expect(fixture.defaults.integer(
            forKey: PersonalHistorySettingsContract.outcomeLedgerGenerationKey
        ) == 8)
        #expect(!FileManager.default.fileExists(atPath: fixture.eventURL.path))
        #expect(FileManager.default.fileExists(atPath: closed.path))
    }

    @Test("Locked reads reject final file-mode and parent-identity races")
    func lockedReadRevalidatesVisibleIdentities() throws {
        try withFixture { fixture in
            defer {
                try? FileManager.default.setAttributes(
                    [.posixPermissions: 0o600], ofItemAtPath: fixture.receiptURL.path
                )
            }
            #expect(throws: LabF03CloseoutError.unsafeReceiptFile) {
                try LockedOwnerFile.withRead(
                    fixture.receiptURL,
                    maximumBytes: 64 * 1_024,
                    unsafeError: .unsafeReceiptFile,
                    tooLargeError: .receiptTooLarge
                ) { _ in
                    try FileManager.default.setAttributes(
                        [.posixPermissions: 0o644], ofItemAtPath: fixture.receiptURL.path
                    )
                }
            }
        }

        try withFixture { fixture in
            let parent = fixture.receiptURL.deletingLastPathComponent()
            let moved = fixture.root.appendingPathComponent("receipt-moved", isDirectory: true)
            defer {
                if FileManager.default.fileExists(atPath: moved.path) {
                    try? FileManager.default.moveItem(at: moved, to: parent)
                }
            }
            #expect(throws: LabF03CloseoutError.unsafeReceiptFile) {
                try LockedOwnerFile.withRead(
                    fixture.receiptURL,
                    maximumBytes: 64 * 1_024,
                    unsafeError: .unsafeReceiptFile,
                    tooLargeError: .receiptTooLarge
                ) { _ in
                    try FileManager.default.moveItem(at: parent, to: moved)
                }
            }
        }
    }

    @Test("Atomic closeout output preserves collisions and rejects parent replacement")
    func atomicOutputAdversarialPublication() throws {
        let root = URL(fileURLWithPath: "/private/tmp", isDirectory: true)
            .appendingPathComponent("tilde-f03-atomic-output-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let output = root.appendingPathComponent("closeout.json")
        let collision = Data("existing-owner-output".utf8)
        #expect(throws: LabF03CloseoutError.outputExists) {
            try NewOwnerFile.write(Data("new-output".utf8), to: output) {
                try collision.write(to: output)
            }
        }
        #expect(try Data(contentsOf: output) == collision)
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).allSatisfy {
            !$0.hasPrefix(".f03-closeout.")
        })

        try FileManager.default.removeItem(at: output)
        var postCommitProbeObserved = false
        let committed = try NewOwnerFile.write(
            Data("new-output".utf8),
            to: output,
            postCommitProbe: {
                postCommitProbeObserved = true
                #expect(FileManager.default.fileExists(atPath: output.path))
                throw InjectedFailure.afterPublication
            }
        )
        #expect(committed.committed)
        #expect(!committed.postCommitChecksPassed)
        #expect(postCommitProbeObserved)
        #expect(try Data(contentsOf: output) == Data("new-output".utf8))
        try FileManager.default.removeItem(at: output)

        let moved = root.deletingLastPathComponent().appendingPathComponent(
            "\(root.lastPathComponent)-moved", isDirectory: true
        )
        defer {
            try? FileManager.default.removeItem(at: root)
            if FileManager.default.fileExists(atPath: moved.path) {
                try? FileManager.default.moveItem(at: moved, to: root)
            }
        }
        #expect(throws: LabF03CloseoutError.outputWriteFailed) {
            try NewOwnerFile.write(Data("new-output".utf8), to: output) {
                try FileManager.default.moveItem(at: root, to: moved)
                try FileManager.default.createDirectory(
                    at: root,
                    withIntermediateDirectories: false,
                    attributes: [.posixPermissions: 0o700]
                )
            }
        }
        #expect(!FileManager.default.fileExists(atPath: output.path))
        #expect(try FileManager.default.contentsOfDirectory(atPath: moved.path).allSatisfy {
            !$0.hasPrefix(".f03-closeout.")
        })
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

    @Test("Installed app and IME plist provenance must exactly match the run receipt")
    func installedPlistProvenanceIsRelationallyBound() throws {
        let receipt = try LabF03RunReceipt.decode(receiptData())
        let app = try provenancePlistData(
            receipt: receipt,
            bundleIdentifier: receipt.profile.appBundleIdentifier
        )
        let inputMethod = try provenancePlistData(
            receipt: receipt,
            bundleIdentifier: receipt.profile.inputMethodBundleIdentifier
        )
        #expect(LabF03Closeout.installedPlistProvenanceMatches(
            receipt, appPlistData: app, inputMethodPlistData: inputMethod
        ))

        let sharedKeys = [
            "TildeSourceCommit", "TildeSourceTree", "TildeSourceSnapshotSHA256",
            "TildeSourceState", "TildeEvidenceClass", "TildeAppleToolchainSHA256",
            "TildeAppleToolchainIdentitySchema", "TildeXcodeVersion", "TildeXcodeBuild",
            "TildeXcodeCDHash", "TildeSwiftVersionSHA256",
            "TildeSwiftExecutableSHA256", "TildeSwiftBuildExecutableSHA256",
            "TildeSwiftDriverExecutableSHA256", "TildeClangExecutableSHA256",
            "TildeLinkerExecutableSHA256", "TildeLibtoolExecutableSHA256",
            "TildeArchiverExecutableSHA256", "TildeMacOSSDKVersion", "TildeMacOSSDKBuild",
            "TildeMacOSSDKSettingsSHA256", "TildeApprovedHelperInputSHA256",
            "TildeApprovedHelperTeamIdentifier", "TildeF03RunnerSHA256",
            "CFBundleShortVersionString", "CFBundleVersion", "TildeProductProfile",
        ]
        for key in sharedKeys {
            let changedApp = try provenancePlistData(
                receipt: receipt,
                bundleIdentifier: receipt.profile.appBundleIdentifier,
                overrides: [key: "fabricated-value"]
            )
            #expect(!LabF03Closeout.installedPlistProvenanceMatches(
                receipt, appPlistData: changedApp, inputMethodPlistData: inputMethod
            ))

            let changedInputMethod = try provenancePlistData(
                receipt: receipt,
                bundleIdentifier: receipt.profile.inputMethodBundleIdentifier,
                overrides: [key: "fabricated-value"]
            )
            #expect(!LabF03Closeout.installedPlistProvenanceMatches(
                receipt, appPlistData: app, inputMethodPlistData: changedInputMethod
            ))
        }

        let wrongAppID = try provenancePlistData(
            receipt: receipt,
            bundleIdentifier: receipt.profile.inputMethodBundleIdentifier
        )
        let wrongInputMethodID = try provenancePlistData(
            receipt: receipt,
            bundleIdentifier: receipt.profile.appBundleIdentifier
        )
        #expect(!LabF03Closeout.installedPlistProvenanceMatches(
            receipt, appPlistData: wrongAppID, inputMethodPlistData: inputMethod
        ))
        #expect(!LabF03Closeout.installedPlistProvenanceMatches(
            receipt, appPlistData: app, inputMethodPlistData: wrongInputMethodID
        ))

        let missingRunner = try provenancePlistData(
            receipt: receipt,
            bundleIdentifier: receipt.profile.appBundleIdentifier,
            removing: ["TildeF03RunnerSHA256"]
        )
        let numericBuild = try provenancePlistData(
            receipt: receipt,
            bundleIdentifier: receipt.profile.appBundleIdentifier,
            overrides: ["CFBundleVersion": 123]
        )
        #expect(!LabF03Closeout.installedPlistProvenanceMatches(
            receipt, appPlistData: missingRunner, inputMethodPlistData: inputMethod
        ))
        #expect(!LabF03Closeout.installedPlistProvenanceMatches(
            receipt, appPlistData: numericBuild, inputMethodPlistData: inputMethod
        ))
        #expect(!LabF03Closeout.installedPlistProvenanceMatches(
            receipt, appPlistData: Data("not-a-plist".utf8), inputMethodPlistData: inputMethod
        ))

        var fabricatedObject = receiptObject()
        fabricatedObject["sourceCommit"] = String(repeating: "f", count: 40)
        fabricatedObject["appleToolchainSHA256"] = String(repeating: "d", count: 64)
        fabricatedObject["runnerSHA256"] = String(repeating: "8", count: 64)
        let fabricatedReceipt = try LabF03RunReceipt.decode(try json(fabricatedObject))
        #expect(!LabF03Closeout.installedPlistProvenanceMatches(
            fabricatedReceipt, appPlistData: app, inputMethodPlistData: inputMethod
        ))
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

    private func persistGeneration(_ generation: Int, in defaults: UserDefaults) throws {
        let key = PersonalHistorySettingsContract.outcomeLedgerGenerationKey
        defaults.set(generation, forKey: key)
        guard defaults.synchronize(), defaults.object(forKey: key) as? Int == generation else {
            throw InjectedFailure.generationPersistence
        }
    }

    private func provenancePlistData(
        receipt: LabF03RunReceipt,
        bundleIdentifier: String,
        overrides: [String: Any] = [:],
        removing: Set<String> = []
    ) throws -> Data {
        let identity = receipt.sourcePackageIdentity
        var values: [String: Any] = [
            "TildeSourceCommit": identity.sourceCommit,
            "TildeSourceTree": identity.sourceTree,
            "TildeSourceSnapshotSHA256": identity.sourceSnapshotSHA256,
            "TildeSourceState": "clean",
            "TildeEvidenceClass": "decision-grade",
            "TildeAppleToolchainSHA256": identity.appleToolchainSHA256,
            "TildeAppleToolchainIdentitySchema": "tilde-apple-toolchain-v2",
            "TildeXcodeVersion": identity.xcodeVersion,
            "TildeXcodeBuild": identity.xcodeBuild,
            "TildeXcodeCDHash": fixtureXcodeCDHash,
            "TildeSwiftVersionSHA256": identity.swiftVersionSHA256,
            "TildeSwiftExecutableSHA256": identity.swiftExecutableSHA256,
            "TildeSwiftBuildExecutableSHA256": fixtureSwiftBuildSHA256,
            "TildeSwiftDriverExecutableSHA256": fixtureSwiftDriverSHA256,
            "TildeClangExecutableSHA256": fixtureClangSHA256,
            "TildeLinkerExecutableSHA256": fixtureLinkerSHA256,
            "TildeLibtoolExecutableSHA256": fixtureLibtoolSHA256,
            "TildeArchiverExecutableSHA256": fixtureArchiverSHA256,
            "TildeMacOSSDKVersion": identity.macOSSDKVersion,
            "TildeMacOSSDKBuild": identity.macOSSDKBuild,
            "TildeMacOSSDKSettingsSHA256": identity.macOSSDKSettingsSHA256,
            "TildeApprovedHelperInputSHA256": identity.approvedHelperInputSHA256,
            "TildeApprovedHelperTeamIdentifier": identity.approvedHelperTeamIdentifier,
            "TildeF03RunnerSHA256": receipt.runnerSHA256,
            "CFBundleShortVersionString": identity.bundleVersion,
            "CFBundleVersion": identity.bundleBuild,
            "TildeProductProfile": receipt.profile.rawValue,
            "CFBundleIdentifier": bundleIdentifier,
        ]
        for key in removing { values.removeValue(forKey: key) }
        for (key, value) in overrides { values[key] = value }
        return try PropertyListSerialization.data(
            fromPropertyList: values, format: .binary, options: 0
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
            "runnerSHA256": String(repeating: "9", count: 64),
            "invocationProfile": "preview9b-owner-approved-v1",
            "appleToolchainSHA256": fixtureToolchainIdentitySHA256(),
            "xcodeVersion": "26.6",
            "xcodeBuild": "17F113",
            "swiftVersionSHA256": String(repeating: "b", count: 64),
            "swiftExecutableSHA256": String(repeating: "c", count: 64),
            "macOSSDKVersion": "26.5",
            "macOSSDKBuild": "25F70",
            "macOSSDKSettingsSHA256": String(repeating: "e", count: 64),
            "approvedHelperInputSHA256": LabF03RunReceipt.registeredHelperInputSHA256,
            "approvedHelperTeamIdentifier": LabF03RunReceipt.registeredHelperTeamIdentifier,
            "bundleVersion": "0.1.0-preview9b",
            "bundleBuild": "123",
            "installedAppBinarySHA256": String(repeating: "3", count: 64),
            "installedIMEBinarySHA256": String(repeating: "4", count: 64),
            "installedHelperSHA256": LabF03RunReceipt.registeredHelperInputSHA256,
            "installedAppInfoPlistSHA256": String(repeating: "6", count: 64),
            "installedIMEInfoPlistSHA256": String(repeating: "7", count: 64),
            "rotationTimestamp": "2026-05-01T00:00:00Z",
            "completedTimestamp": "2026-05-01T00:01:00Z",
            "previousLedgerDisposition": "absent",
            "previousLedgerBytes": 0,
            "previousLedgerSHA256": NSNull(),
            "outcomeLedgerGeneration": 7,
            "signingTeamIdentifier": LabF03RunReceipt.registeredHelperTeamIdentifier,
            "modelSHA256": LabF03RunReceipt.registeredModelSHA256,
            "modelBytes": LabF03RunReceipt.registeredModelBytes,
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

    private var fixtureXcodeCDHash: String { String(repeating: "d", count: 40) }
    private var fixtureSwiftBuildSHA256: String { String(repeating: "f", count: 64) }
    private var fixtureSwiftDriverSHA256: String { String(repeating: "0", count: 64) }
    private var fixtureClangSHA256: String { String(repeating: "1", count: 64) }
    private var fixtureLinkerSHA256: String { String(repeating: "2", count: 64) }
    private var fixtureLibtoolSHA256: String { String(repeating: "3", count: 64) }
    private var fixtureArchiverSHA256: String { String(repeating: "4", count: 64) }

    private func fixtureToolchainIdentitySHA256() -> String {
        let values = [
            "26.6", "17F113", fixtureXcodeCDHash,
            "26.5", "25F70", String(repeating: "e", count: 64),
            String(repeating: "c", count: 64), String(repeating: "b", count: 64),
            fixtureSwiftBuildSHA256, fixtureSwiftDriverSHA256, fixtureClangSHA256,
            fixtureLinkerSHA256, fixtureLibtoolSHA256, fixtureArchiverSHA256,
        ]
        var hasher = SHA256()
        hasher.update(data: Data("tilde-apple-toolchain-v2\0".utf8))
        for value in values {
            let bytes = Data(value.utf8)
            var bigEndianLength = UInt64(bytes.count).bigEndian
            withUnsafeBytes(of: &bigEndianLength) { raw in
                hasher.update(data: Data(raw))
            }
            hasher.update(data: bytes)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
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
