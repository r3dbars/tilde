import CryptoKit
import Darwin
import Foundation
import Security
import TildeCore

public enum LabF03CloseoutError: Error, LocalizedError, Equatable, Sendable {
    case unsafeReceiptFile
    case receiptTooLarge
    case malformedReceipt
    case unsupportedReceiptSchema
    case unsupportedProfile
    case invalidReceiptField(String)
    case unsafeEventFile
    case eventFileTooLarge
    case malformedEventFile
    case forbiddenEventKey(String)
    case mixedCampaigns
    case preferencesUnavailable
    case invalidWriteAccounting
    case unsafeMaintenanceLock
    case maintenanceLockUnavailable
    case unfinishedMaintenanceTransaction
    case previewProcessesStillRunning
    case installedIdentityChanged
    case terminalSealFailed
    case outputExists
    case outputWriteFailed

    public var errorDescription: String? {
        switch self {
        case .unsafeReceiptFile:
            "The F03 receipt must be an owner-only regular single-link file inside an owner-only directory."
        case .receiptTooLarge: "The F03 receipt exceeds the 64 KiB limit."
        case .malformedReceipt: "The F03 receipt is malformed or contains unsupported fields."
        case .unsupportedReceiptSchema: "The F03 receipt schema is unsupported."
        case .unsupportedProfile: "This F03 receipt does not name the Preview9B profile."
        case .invalidReceiptField(let field): "The F03 receipt has an invalid \(field) field."
        case .unsafeEventFile:
            "The F03 event file must be an owner-only regular single-link file inside an owner-only directory."
        case .eventFileTooLarge: "The F03 event file exceeds the 64 MiB limit."
        case .malformedEventFile: "The F03 event file is empty, truncated, or malformed."
        case .forbiddenEventKey(let key): "The F03 event file contains forbidden raw-data key \(key)."
        case .mixedCampaigns: "The F03 event file mixes campaign identifiers."
        case .preferencesUnavailable: "The receipt-selected input-method preference suite is unavailable."
        case .invalidWriteAccounting: "The F03 write-accounting preference is malformed."
        case .unsafeMaintenanceLock:
            "The Preview9B maintenance lock or its support directory is unsafe."
        case .maintenanceLockUnavailable:
            "Another F03 maintenance operation holds the Preview9B maintenance lock."
        case .unfinishedMaintenanceTransaction:
            "An unfinished F03 maintenance journal must be recovered before closeout."
        case .previewProcessesStillRunning:
            "The exact Preview9B app, helper, and input-method processes must be stopped before closeout."
        case .installedIdentityChanged:
            "The installed Preview9B app, input method, helper, plist, or model changed during closeout."
        case .terminalSealFailed:
            "The F03 generation could not be sealed without risking a mixed terminal snapshot."
        case .outputExists: "The F03 closeout output already exists; refusing to overwrite it."
        case .outputWriteFailed: "The F03 closeout report could not be written safely."
        }
    }
}

public enum LabF03CloseoutBlocker: String, Codable, CaseIterable, Sendable {
    case currentGenerationMismatch = "current-generation-mismatch"
    case droppedWrites = "dropped-writes"
    case attemptedWrittenMismatch = "attempted-written-mismatch"
    case writtenRowMismatch = "written-row-mismatch"
    case nonCurrentEventSchema = "non-current-event-schema"
    case duplicateEventIDs = "duplicate-event-ids"
    case conflictingEventIDs = "conflicting-event-ids"
    case nonInstrumentCampaign = "non-instrument-campaign"
    case eventBeforeRotation = "event-before-rotation"
    case missingAcceptedEvents = "missing-accepted-events"
    case missingFiveSecondCoverage = "missing-five-second-retention-coverage"
    case missingThirtySecondCoverage = "missing-thirty-second-retention-coverage"
    case missingSegmentCoverage = "missing-segment-retention-coverage"
    case inputMethodRegistrationUnverified = "input-method-registration-unverified"
    case previewProcessesNotStopped = "preview-processes-not-stopped"
    case missingOrStaleFlushAcknowledgement = "missing-or-stale-flush-acknowledgement"
    case installedIdentityMismatch = "installed-identity-mismatch"
    case terminalSnapshotUnsealed = "terminal-snapshot-unsealed"
    case terminalPublicationIndeterminate = "terminal-publication-indeterminate"
}

public struct LabF03WriteAccounting: Codable, Equatable, Sendable {
    public let attempted: Int
    public let written: Int
    public let dropped: Int

    public init(attempted: Int, written: Int, dropped: Int) throws {
        guard attempted >= 0, written >= 0, dropped >= 0 else {
            throw LabF03CloseoutError.invalidWriteAccounting
        }
        self.attempted = attempted
        self.written = written
        self.dropped = dropped
    }
}

public struct LabF03SourcePackageIdentity: Codable, Equatable, Sendable {
    public let sourceCommit: String
    public let sourceTree: String
    public let sourceSnapshotSHA256: String
    public let appleToolchainSHA256: String
    public let xcodeVersion: String
    public let xcodeBuild: String
    public let swiftVersionSHA256: String
    public let swiftExecutableSHA256: String
    public let macOSSDKVersion: String
    public let macOSSDKBuild: String
    public let macOSSDKSettingsSHA256: String
    public let approvedHelperInputSHA256: String
    public let approvedHelperTeamIdentifier: String
    public let bundleVersion: String
    public let bundleBuild: String
    public let installedAppBinarySHA256: String
    public let installedIMEBinarySHA256: String
    public let installedHelperSHA256: String
    public let installedAppInfoPlistSHA256: String
    public let installedIMEInfoPlistSHA256: String
    public let signingTeamIdentifier: String
    public let modelSHA256: String
    public let modelBytes: Int64
}

public struct LabF03EnvironmentIdentity: Codable, Equatable, Sendable {
    public let operatingSystemVersion: String
    public let operatingSystemBuild: String
    public let architecture: String
    public let hardwareModel: String
    public let powerSource: String
}

public struct LabF03FlushAcknowledgement: Codable, Equatable, Sendable {
    public let writeAccounting: LabF03WriteAccounting
    public let acknowledgedAt: Date

    public init(writeAccounting: LabF03WriteAccounting, acknowledgedAt: Date) {
        self.writeAccounting = writeAccounting
        self.acknowledgedAt = acknowledgedAt
    }
}

public struct LabF03CloseoutReport: Codable, Equatable, Sendable {
    public static let currentSchema = "tilde-lab.f03-closeout.v2"

    public let schema: String
    public let generatedAt: Date
    public let runID: UUID
    public let profile: String
    public let evidenceClass: String
    public let sourceState: String
    public let runnerSHA256: String
    public let invocationProfile: String
    public let receiptSHA256: String
    public let rotationTimestamp: Date
    public let receiptCompletedTimestamp: Date
    public let receiptOutcomeLedgerGeneration: Int
    public let currentOutcomeLedgerGeneration: Int
    public let sourcePackageIdentity: LabF03SourcePackageIdentity
    public let environmentIdentity: LabF03EnvironmentIdentity
    public let inputMethodRegistrationVerified: Bool
    public let installedIdentityVerified: Bool
    public let previewProcessesStopped: Bool
    public let eventFileSHA256: String
    public let eventRows: Int
    public let writeAccounting: LabF03WriteAccounting
    public let flushAcknowledgement: LabF03FlushAcknowledgement?
    public let eventSchemaCounts: [String: Int]
    public let aggregateReport: LabOnlineExperimentReport
    public let terminalSnapshotSealed: Bool
    public let decisionGradeEligible: Bool
    public let blockers: [LabF03CloseoutBlocker]
    public let containsRawText: Bool
    public let containsLocalPaths: Bool
}

public struct LabF03RunReceipt: Equatable, Sendable {
    public static let currentSchema = "tilde.f03-local-run-receipt.v1"
    static let registeredHelperInputSHA256 =
        "e7b0946d81c2342d0d5afd1639dcb8af444c843b4fb50cef5ceeafa302a80546"
    static let registeredHelperTeamIdentifier = "XG6WL66WUQ"
    static let registeredModelSHA256 =
        "4171d5fec62a373744ca4f01ec9e2378c092a65f480c039e9c679d910351fda2"
    static let registeredModelBytes: Int64 = 5_629_109_312

    public let runID: UUID
    public let profile: TildeProductProfile
    public let evidenceClass: String
    public let sourceState: String
    public let runnerSHA256: String
    public let invocationProfile: String
    public let sourcePackageIdentity: LabF03SourcePackageIdentity
    public let environmentIdentity: LabF03EnvironmentIdentity
    public let rotationTimestamp: Date
    public let completedTimestamp: Date
    public let outcomeLedgerGeneration: Int
    public let inputMethodRegistrationVerified: Bool

    public static func decode(_ data: Data) throws -> LabF03RunReceipt {
        guard data.count <= 64 * 1_024 else { throw LabF03CloseoutError.receiptTooLarge }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(object.keys) == Raw.allowedKeys else {
            throw LabF03CloseoutError.malformedReceipt
        }
        let raw: Raw
        do {
            raw = try JSONDecoder().decode(Raw.self, from: data)
        } catch {
            throw LabF03CloseoutError.malformedReceipt
        }
        guard raw.schema == currentSchema else {
            throw LabF03CloseoutError.unsupportedReceiptSchema
        }
        guard let runID = UUID(uuidString: raw.runID),
              raw.runID == runID.uuidString.lowercased() else {
            throw LabF03CloseoutError.invalidReceiptField("runID")
        }
        guard raw.profile == TildeProductProfile.preview9B.rawValue else {
            throw LabF03CloseoutError.unsupportedProfile
        }
        guard raw.evidenceClass == "decision-grade" else {
            throw LabF03CloseoutError.invalidReceiptField("evidenceClass")
        }
        guard raw.sourceState == "clean" else {
            throw LabF03CloseoutError.invalidReceiptField("sourceState")
        }
        guard isLowerHex(raw.runnerSHA256, count: 64) else {
            throw LabF03CloseoutError.invalidReceiptField("runnerSHA256")
        }
        guard raw.invocationProfile == "preview9b-owner-approved-v1" else {
            throw LabF03CloseoutError.invalidReceiptField("invocationProfile")
        }
        for (name, value, length) in [
            ("sourceCommit", raw.sourceCommit, 40),
            ("sourceTree", raw.sourceTree, 40),
            ("sourceSnapshotSHA256", raw.sourceSnapshotSHA256, 64),
            ("appleToolchainSHA256", raw.appleToolchainSHA256, 64),
            ("swiftVersionSHA256", raw.swiftVersionSHA256, 64),
            ("swiftExecutableSHA256", raw.swiftExecutableSHA256, 64),
            ("macOSSDKSettingsSHA256", raw.macOSSDKSettingsSHA256, 64),
            ("approvedHelperInputSHA256", raw.approvedHelperInputSHA256, 64),
            ("installedAppBinarySHA256", raw.installedAppBinarySHA256, 64),
            ("installedIMEBinarySHA256", raw.installedIMEBinarySHA256, 64),
            ("installedHelperSHA256", raw.installedHelperSHA256, 64),
            ("installedAppInfoPlistSHA256", raw.installedAppInfoPlistSHA256, 64),
            ("installedIMEInfoPlistSHA256", raw.installedIMEInfoPlistSHA256, 64),
            ("modelSHA256", raw.modelSHA256, 64),
        ] where !isLowerHex(value, count: length) {
            throw LabF03CloseoutError.invalidReceiptField(name)
        }
        guard safeVersion(raw.bundleVersion) else {
            throw LabF03CloseoutError.invalidReceiptField("bundleVersion")
        }
        for (name, value) in [
            ("xcodeVersion", raw.xcodeVersion),
            ("macOSSDKVersion", raw.macOSSDKVersion),
        ] where !safeDottedVersion(value) {
            throw LabF03CloseoutError.invalidReceiptField(name)
        }
        for (name, value) in [
            ("xcodeBuild", raw.xcodeBuild),
            ("macOSSDKBuild", raw.macOSSDKBuild),
        ] where !safeBuildToken(value) {
            throw LabF03CloseoutError.invalidReceiptField(name)
        }
        guard !raw.bundleBuild.isEmpty, raw.bundleBuild.utf8.count <= 64,
              raw.bundleBuild.utf8.allSatisfy({ (48...57).contains($0) }) else {
            throw LabF03CloseoutError.invalidReceiptField("bundleBuild")
        }
        guard raw.outcomeLedgerGeneration > 0 else {
            throw LabF03CloseoutError.invalidReceiptField("outcomeLedgerGeneration")
        }
        guard raw.appReady, raw.inputMethodBundleInstalled, raw.helperReady else {
            throw LabF03CloseoutError.invalidReceiptField("readiness")
        }
        guard raw.signingTeamIdentifier.range(
            of: "^[A-Z0-9]{10}$", options: .regularExpression
        ) == raw.signingTeamIdentifier.startIndex..<raw.signingTeamIdentifier.endIndex else {
            throw LabF03CloseoutError.invalidReceiptField("signingTeamIdentifier")
        }
        guard raw.approvedHelperTeamIdentifier == raw.signingTeamIdentifier else {
            throw LabF03CloseoutError.invalidReceiptField("approvedHelperTeamIdentifier")
        }
        guard raw.approvedHelperInputSHA256 == registeredHelperInputSHA256 else {
            throw LabF03CloseoutError.invalidReceiptField("approvedHelperInputSHA256")
        }
        guard raw.installedHelperSHA256 == raw.approvedHelperInputSHA256 else {
            throw LabF03CloseoutError.invalidReceiptField("installedHelperSHA256")
        }
        guard raw.approvedHelperTeamIdentifier == registeredHelperTeamIdentifier else {
            throw LabF03CloseoutError.invalidReceiptField("approvedHelperTeamIdentifier")
        }
        guard raw.modelSHA256 == registeredModelSHA256 else {
            throw LabF03CloseoutError.invalidReceiptField("modelSHA256")
        }
        guard raw.modelBytes == registeredModelBytes else {
            throw LabF03CloseoutError.invalidReceiptField("modelBytes")
        }
        for (name, value) in [
            ("operatingSystemVersion", raw.operatingSystemVersion),
            ("operatingSystemBuild", raw.operatingSystemBuild),
            ("architecture", raw.architecture),
            ("hardwareModel", raw.hardwareModel),
        ] where !safeEnvironmentToken(value) {
            throw LabF03CloseoutError.invalidReceiptField(name)
        }
        guard ["ac", "battery", "unknown"].contains(raw.powerSource) else {
            throw LabF03CloseoutError.invalidReceiptField("powerSource")
        }
        guard raw.previousLedgerBytes >= 0 else {
            throw LabF03CloseoutError.invalidReceiptField("previousLedgerBytes")
        }
        switch raw.previousLedgerDisposition {
        case "absent":
            guard raw.previousLedgerBytes == 0, raw.previousLedgerSHA256 == nil else {
                throw LabF03CloseoutError.invalidReceiptField("previousLedgerDisposition")
            }
        case "archive", "delete":
            guard raw.previousLedgerSHA256.map({ isLowerHex($0, count: 64) }) == true else {
                throw LabF03CloseoutError.invalidReceiptField("previousLedgerSHA256")
            }
        default:
            throw LabF03CloseoutError.invalidReceiptField("previousLedgerDisposition")
        }
        guard let rotation = parseTimestamp(raw.rotationTimestamp),
              let completed = parseTimestamp(raw.completedTimestamp), completed >= rotation else {
            throw LabF03CloseoutError.invalidReceiptField("timestamps")
        }
        return LabF03RunReceipt(
            runID: runID,
            profile: .preview9B,
            evidenceClass: raw.evidenceClass,
            sourceState: raw.sourceState,
            runnerSHA256: raw.runnerSHA256,
            invocationProfile: raw.invocationProfile,
            sourcePackageIdentity: LabF03SourcePackageIdentity(
                sourceCommit: raw.sourceCommit,
                sourceTree: raw.sourceTree,
                sourceSnapshotSHA256: raw.sourceSnapshotSHA256,
                appleToolchainSHA256: raw.appleToolchainSHA256,
                xcodeVersion: raw.xcodeVersion,
                xcodeBuild: raw.xcodeBuild,
                swiftVersionSHA256: raw.swiftVersionSHA256,
                swiftExecutableSHA256: raw.swiftExecutableSHA256,
                macOSSDKVersion: raw.macOSSDKVersion,
                macOSSDKBuild: raw.macOSSDKBuild,
                macOSSDKSettingsSHA256: raw.macOSSDKSettingsSHA256,
                approvedHelperInputSHA256: raw.approvedHelperInputSHA256,
                approvedHelperTeamIdentifier: raw.approvedHelperTeamIdentifier,
                bundleVersion: raw.bundleVersion,
                bundleBuild: raw.bundleBuild,
                installedAppBinarySHA256: raw.installedAppBinarySHA256,
                installedIMEBinarySHA256: raw.installedIMEBinarySHA256,
                installedHelperSHA256: raw.installedHelperSHA256,
                installedAppInfoPlistSHA256: raw.installedAppInfoPlistSHA256,
                installedIMEInfoPlistSHA256: raw.installedIMEInfoPlistSHA256,
                signingTeamIdentifier: raw.signingTeamIdentifier,
                modelSHA256: raw.modelSHA256,
                modelBytes: raw.modelBytes
            ),
            environmentIdentity: LabF03EnvironmentIdentity(
                operatingSystemVersion: raw.operatingSystemVersion,
                operatingSystemBuild: raw.operatingSystemBuild,
                architecture: raw.architecture,
                hardwareModel: raw.hardwareModel,
                powerSource: raw.powerSource
            ),
            rotationTimestamp: rotation,
            completedTimestamp: completed,
            outcomeLedgerGeneration: raw.outcomeLedgerGeneration,
            inputMethodRegistrationVerified: raw.inputMethodRegistrationVerified
        )
    }

    private struct Raw: Decodable {
        static let allowedKeys: Set<String> = [
            "schema", "runID", "profile", "evidenceClass", "sourceState", "sourceCommit",
            "sourceTree", "sourceSnapshotSHA256", "bundleVersion", "bundleBuild",
            "runnerSHA256", "invocationProfile",
            "appleToolchainSHA256", "xcodeVersion", "xcodeBuild",
            "swiftVersionSHA256", "swiftExecutableSHA256", "macOSSDKVersion",
            "macOSSDKBuild", "macOSSDKSettingsSHA256", "approvedHelperInputSHA256",
            "approvedHelperTeamIdentifier",
            "installedAppBinarySHA256", "installedIMEBinarySHA256", "installedHelperSHA256",
            "installedAppInfoPlistSHA256", "installedIMEInfoPlistSHA256",
            "rotationTimestamp", "completedTimestamp", "previousLedgerDisposition",
            "previousLedgerBytes", "previousLedgerSHA256", "outcomeLedgerGeneration",
            "appReady", "helperReady",
            "signingTeamIdentifier", "modelSHA256", "modelBytes",
            "operatingSystemVersion", "operatingSystemBuild", "architecture",
            "hardwareModel", "powerSource", "inputMethodBundleInstalled",
            "inputMethodRegistrationVerified",
        ]

        let schema: String
        let runID: String
        let profile: String
        let evidenceClass: String
        let sourceState: String
        let sourceCommit: String
        let sourceTree: String
        let sourceSnapshotSHA256: String
        let runnerSHA256: String
        let invocationProfile: String
        let appleToolchainSHA256: String
        let xcodeVersion: String
        let xcodeBuild: String
        let swiftVersionSHA256: String
        let swiftExecutableSHA256: String
        let macOSSDKVersion: String
        let macOSSDKBuild: String
        let macOSSDKSettingsSHA256: String
        let approvedHelperInputSHA256: String
        let approvedHelperTeamIdentifier: String
        let bundleVersion: String
        let bundleBuild: String
        let installedAppBinarySHA256: String
        let installedIMEBinarySHA256: String
        let installedHelperSHA256: String
        let installedAppInfoPlistSHA256: String
        let installedIMEInfoPlistSHA256: String
        let rotationTimestamp: String
        let completedTimestamp: String
        let previousLedgerDisposition: String
        let previousLedgerBytes: Int64
        let previousLedgerSHA256: String?
        let outcomeLedgerGeneration: Int
        let signingTeamIdentifier: String
        let modelSHA256: String
        let modelBytes: Int64
        let operatingSystemVersion: String
        let operatingSystemBuild: String
        let architecture: String
        let hardwareModel: String
        let powerSource: String
        let appReady: Bool
        let inputMethodBundleInstalled: Bool
        let inputMethodRegistrationVerified: Bool
        let helperReady: Bool
    }

    private static func isLowerHex(_ value: String, count: Int) -> Bool {
        value.utf8.count == count && value.utf8.allSatisfy {
            (48...57).contains($0) || (97...102).contains($0)
        }
    }

    private static func safeVersion(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 128 && value.utf8.allSatisfy {
            (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0)
                || [43, 45, 46, 95].contains($0)
        }
    }

    private static func safeDottedVersion(_ value: String) -> Bool {
        value.range(
            of: "^[0-9]+([.][0-9]+){1,3}$", options: .regularExpression
        ) == value.startIndex..<value.endIndex
    }

    private static func safeBuildToken(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 32 && value.utf8.allSatisfy {
            (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0)
        }
    }

    private static func safeEnvironmentToken(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 128 && value.utf8.allSatisfy {
            (32...126).contains($0) && $0 != 47 && $0 != 92
        }
    }

    private static func parseTimestamp(_ value: String) -> Date? {
        guard value.range(
            of: "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\\.[0-9]{1,9})?Z$",
            options: .regularExpression
        ) == value.startIndex..<value.endIndex else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}

public enum LabF03Closeout {
    public typealias PreferencesProvider = (String) -> UserDefaults?
    public typealias StoppedProcessProvider = ([URL]) -> Bool
    public typealias InstalledIdentityProvider = (LabF03RunReceipt, URL) -> Bool
    typealias TerminalReportWriter = (
        LabF03CloseoutReport, URL, _ beforeCommit: () throws -> Void
    ) throws -> NewOwnerFile.PublicationOutcome
    typealias GenerationPersister = (Int, UserDefaults) throws -> Void

    public static func capture(
        receiptURL: URL,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        generatedAt: Date = Date(),
        preferencesProvider: PreferencesProvider = { UserDefaults(suiteName: $0) },
        stoppedProcessProvider: @escaping StoppedProcessProvider = exactPreviewProcessesAreStopped,
        installedIdentityProvider: @escaping InstalledIdentityProvider = installedIdentityMatches,
        outputURL: URL? = nil
    ) throws -> LabF03CloseoutReport {
        try capture(
            receiptURL: receiptURL,
            homeDirectory: homeDirectory,
            generatedAt: generatedAt,
            preferencesProvider: preferencesProvider,
            stoppedProcessProvider: stoppedProcessProvider,
            installedIdentityProvider: installedIdentityProvider,
            outputURL: outputURL,
            terminalReportWriter: { report, output, beforeCommit in
                try writeNew(report, to: output, beforeCommit: beforeCommit)
            },
            generationPersister: persistGeneration
        )
    }

    static func capture(
        receiptURL: URL,
        homeDirectory: URL,
        generatedAt: Date,
        preferencesProvider: PreferencesProvider,
        stoppedProcessProvider: @escaping StoppedProcessProvider,
        installedIdentityProvider: @escaping InstalledIdentityProvider,
        outputURL: URL?,
        terminalReportWriter: TerminalReportWriter,
        generationPersister: GenerationPersister
    ) throws -> LabF03CloseoutReport {
        let receiptData = try LockedOwnerFile.read(
            receiptURL,
            maximumBytes: 64 * 1_024,
            unsafeError: .unsafeReceiptFile,
            tooLargeError: .receiptTooLarge
        )
        let receipt = try LabF03RunReceipt.decode(receiptData)
        let processURLs = previewProcessURLs(
            profile: receipt.profile, homeDirectory: homeDirectory
        )
        let eventURL = TextFreeOnlineEventFile.url(
            homeDirectory: homeDirectory,
            supportDirectoryName: receipt.profile.supportDirectoryName
        )
        if let outputURL,
           outputURL.deletingLastPathComponent().standardizedFileURL
            == eventURL.deletingLastPathComponent().standardizedFileURL {
            // NewOwnerFile takes an exclusive parent-directory flock. Reusing
            // the already locked Outcome Ledger directory through a second open
            // file description would self-deadlock instead of publishing.
            throw LabF03CloseoutError.outputWriteFailed
        }
        let maintenanceLock = try F03MaintenanceLock.acquireShared(
            supportDirectory: eventURL.deletingLastPathComponent().deletingLastPathComponent()
        )
        defer { withExtendedLifetime(maintenanceLock) {} }
        try maintenanceLock.requireNoUnfinishedTransaction()
        guard stoppedProcessProvider(processURLs) else {
            throw LabF03CloseoutError.previewProcessesStillRunning
        }
        let installedIdentityVerified = installedIdentityProvider(receipt, homeDirectory)
        return try maintenanceLock.withRead(
            directoryName: eventURL.deletingLastPathComponent().lastPathComponent,
            fileName: eventURL.lastPathComponent,
            maximumBytes: 64 * 1_024 * 1_024,
            unsafeError: .unsafeEventFile,
            tooLargeError: .eventFileTooLarge,
            directoryLock: LOCK_EX,
            fileLock: LOCK_EX
        ) { eventSnapshot in
            let suiteName = receipt.profile.inputMethodBundleIdentifier
            guard let defaults = preferencesProvider(suiteName) else {
                throw LabF03CloseoutError.preferencesUnavailable
            }
            guard let currentGeneration = defaults.object(
                forKey: PersonalHistorySettingsContract.outcomeLedgerGenerationKey
            ) as? Int else {
                throw LabF03CloseoutError.invalidWriteAccounting
            }
            let initialWriteState = try writeState(
                generation: receipt.outcomeLedgerGeneration, defaults: defaults
            )
            var report = try analyzeReport(
                receiptData: receiptData,
                eventData: eventSnapshot.data,
                currentGeneration: currentGeneration,
                writeAccounting: initialWriteState.accounting,
                flushAcknowledgement: initialWriteState.acknowledgement,
                previewProcessesStopped: true,
                installedIdentityVerified: installedIdentityVerified,
                generatedAt: generatedAt,
                terminalSnapshotSealed: false
            )

            guard report.blockers == [.terminalSnapshotUnsealed], let outputURL else {
                guard stoppedProcessProvider(processURLs) else {
                    throw LabF03CloseoutError.previewProcessesStillRunning
                }
                let finalInstalledIdentityVerified = installedIdentityProvider(
                    receipt, homeDirectory
                ) && installedIdentityVerified
                try maintenanceLock.requireNoUnfinishedTransaction()
                if finalInstalledIdentityVerified != installedIdentityVerified {
                    report = try analyzeReport(
                        receiptData: receiptData,
                        eventData: eventSnapshot.data,
                        currentGeneration: currentGeneration,
                        writeAccounting: initialWriteState.accounting,
                        flushAcknowledgement: initialWriteState.acknowledgement,
                        previewProcessesStopped: true,
                        installedIdentityVerified: false,
                        generatedAt: generatedAt,
                        terminalSnapshotSealed: false
                    )
                }
                if report.blockers == [.terminalSnapshotUnsealed] {
                    throw LabF03CloseoutError.terminalSealFailed
                }
                if let outputURL { try writeNew(report, to: outputURL) }
                return report
            }

            guard currentGeneration == receipt.outcomeLedgerGeneration,
                  let nextGeneration = nextUnusedGeneration(after: currentGeneration, in: defaults)
            else { throw LabF03CloseoutError.terminalSealFailed }
            let closedName = "events.closed-\(receipt.runID.uuidString.lowercased()).jsonl"
            var generationAdvanced = false
            do {
                // The writer takes this same directory lock and rechecks its
                // captured generation before append. Advancing first, then
                // proving the old IME is stopped and renaming before unlock,
                // makes the published report the terminal old-generation file;
                // a respawn can only create the next generation's events.jsonl.
                try generationPersister(nextGeneration, defaults)
                generationAdvanced = true
                guard stoppedProcessProvider(processURLs) else {
                    throw LabF03CloseoutError.previewProcessesStillRunning
                }
                guard installedIdentityProvider(receipt, homeDirectory) else {
                    throw LabF03CloseoutError.installedIdentityChanged
                }
                try maintenanceLock.requireNoUnfinishedTransaction()
                // `recordWrite(attempted:)` runs before the event-directory lock.
                // An old IME can therefore update its generation's counters while
                // its append waits behind this closeout. Once the generation is
                // advanced and the exact processes are proven stopped, re-read
                // those counters so only the terminal accounting can be published.
                let terminalWriteState = try writeState(
                    generation: receipt.outcomeLedgerGeneration, defaults: defaults
                )
                try eventSnapshot.rename(to: closedName)
                let terminalReport = try analyzeReport(
                    receiptData: receiptData,
                    eventData: eventSnapshot.data,
                    currentGeneration: currentGeneration,
                    writeAccounting: terminalWriteState.accounting,
                    flushAcknowledgement: terminalWriteState.acknowledgement,
                    previewProcessesStopped: true,
                    installedIdentityVerified: true,
                    generatedAt: generatedAt,
                    terminalSnapshotSealed: true
                )
                guard terminalReport.decisionGradeEligible else {
                    throw LabF03CloseoutError.terminalSealFailed
                }
                let publication = try terminalReportWriter(terminalReport, outputURL) {
                    // Keep every fallible terminal gate on the uncommitted side
                    // of the report's no-replace rename. The real identity
                    // verifier reads each artifact through a descriptor and
                    // revalidates its visible path immediately before this
                    // commit gate; this closes accidental replacement between
                    // the earlier pre-seal check and publication. Coordinated
                    // malicious same-UID replacement is outside the runner's
                    // stated threat model.
                    guard stoppedProcessProvider(processURLs) else {
                        throw LabF03CloseoutError.previewProcessesStillRunning
                    }
                    guard installedIdentityProvider(receipt, homeDirectory) else {
                        throw LabF03CloseoutError.installedIdentityChanged
                    }
                    try maintenanceLock.requireNoUnfinishedTransaction()
                    try eventSnapshot.validate()
                    let commitWriteState = try writeState(
                        generation: receipt.outcomeLedgerGeneration, defaults: defaults
                    )
                    guard commitWriteState.accounting == terminalWriteState.accounting,
                          commitWriteState.acknowledgement
                            == terminalWriteState.acknowledgement else {
                        throw LabF03CloseoutError.terminalSealFailed
                    }
                }
                guard publication.committed else {
                    throw LabF03CloseoutError.terminalSealFailed
                }
                guard publication.postCommitChecksPassed else {
                    // The terminal generation and renamed event file are already
                    // committed and must not be rolled back.  A failed durability
                    // or final-path probe nevertheless makes this publication
                    // ineligible: the caller must not treat an indeterminate
                    // visible artifact as decision-grade evidence.
                    return publicationIndeterminate(terminalReport)
                }
                return terminalReport
            } catch {
                var recoveryFailed = false
                let observedGeneration = defaults.object(
                    forKey: PersonalHistorySettingsContract.outcomeLedgerGenerationKey
                ) as? Int
                let generationNeedsRestore = generationAdvanced
                    || observedGeneration == nextGeneration
                var generationRestored = false
                if generationNeedsRestore {
                    do {
                        try generationPersister(currentGeneration, defaults)
                        generationRestored = defaults.object(
                            forKey: PersonalHistorySettingsContract.outcomeLedgerGenerationKey
                        ) as? Int == currentGeneration
                        if !generationRestored { recoveryFailed = true }
                    } catch {
                        // Keep the old file under its closed name while the next
                        // generation remains active or indeterminate.
                        recoveryFailed = true
                    }
                }
                if !recoveryFailed, eventSnapshot.fileName == closedName {
                    do {
                        try eventSnapshot.rename(to: TextFreeOnlineEventFile.fileName)
                    } catch {
                        recoveryFailed = true
                    }
                }
                if recoveryFailed, eventSnapshot.fileName == closedName {
                    // A failed restore may have changed the visible defaults
                    // before reporting failure. Reassert the next generation
                    // whenever the old file remains sealed so no writer can
                    // create a second old-generation events.jsonl.
                    do { try generationPersister(nextGeneration, defaults) }
                    catch { recoveryFailed = true }
                }
                if recoveryFailed { throw LabF03CloseoutError.terminalSealFailed }
                throw error
            }
        }
    }

    public static func analyze(
        receiptData: Data,
        eventData: Data,
        currentGeneration: Int,
        writeAccounting: LabF03WriteAccounting,
        flushAcknowledgement: LabF03FlushAcknowledgement?,
        previewProcessesStopped: Bool,
        installedIdentityVerified: Bool,
        generatedAt: Date = Date()
    ) throws -> LabF03CloseoutReport {
        try analyzeReport(
            receiptData: receiptData,
            eventData: eventData,
            currentGeneration: currentGeneration,
            writeAccounting: writeAccounting,
            flushAcknowledgement: flushAcknowledgement,
            previewProcessesStopped: previewProcessesStopped,
            installedIdentityVerified: installedIdentityVerified,
            generatedAt: generatedAt,
            terminalSnapshotSealed: false
        )
    }

    private static func analyzeReport(
        receiptData: Data,
        eventData: Data,
        currentGeneration: Int,
        writeAccounting: LabF03WriteAccounting,
        flushAcknowledgement: LabF03FlushAcknowledgement?,
        previewProcessesStopped: Bool,
        installedIdentityVerified: Bool,
        generatedAt: Date,
        terminalSnapshotSealed: Bool
    ) throws -> LabF03CloseoutReport {
        let receipt = try LabF03RunReceipt.decode(receiptData)
        let events = try decodeEvents(eventData)
        guard let campaignID = events.first?.campaignID,
              events.allSatisfy({ $0.campaignID == campaignID }) else {
            throw LabF03CloseoutError.mixedCampaigns
        }
        let plan = try closeoutPlan(campaignID: campaignID, events: events)
        do {
            for event in events { _ = try event.validated(for: plan) }
        } catch {
            throw LabF03CloseoutError.malformedEventFile
        }
        let aggregate: LabOnlineExperimentReport
        do {
            aggregate = try LabOnlineExperimentAnalyzer.analyze(events)
        } catch {
            throw LabF03CloseoutError.malformedEventFile
        }
        let schemaCounts = Dictionary(grouping: events, by: \.schema).mapValues(\.count)
        let groupedIDs = Dictionary(grouping: events, by: \.id)
        let duplicates = groupedIDs.values.filter { $0.count > 1 }
        var blockers: [LabF03CloseoutBlocker] = []
        if currentGeneration != receipt.outcomeLedgerGeneration {
            blockers.append(.currentGenerationMismatch)
        }
        if writeAccounting.dropped != 0 { blockers.append(.droppedWrites) }
        if writeAccounting.attempted != writeAccounting.written {
            blockers.append(.attemptedWrittenMismatch)
        }
        if writeAccounting.written != events.count { blockers.append(.writtenRowMismatch) }
        if schemaCounts != [LabOnlineExperimentEvent.currentSchema: events.count] {
            blockers.append(.nonCurrentEventSchema)
        }
        if !duplicates.isEmpty { blockers.append(.duplicateEventIDs) }
        if duplicates.contains(where: { group in
            guard let first = group.first else { return false }
            return group.dropFirst().contains { $0 != first }
        }) {
            blockers.append(.conflictingEventIDs)
        }
        if campaignID != LabInstrumentCampaign.id { blockers.append(.nonInstrumentCampaign) }
        if events.contains(where: { $0.occurredAt < receipt.rotationTimestamp }) {
            blockers.append(.eventBeforeRotation)
        }
        if aggregate.acceptedAll + aggregate.acceptedWord == 0 {
            blockers.append(.missingAcceptedEvents)
        }
        if aggregate.retentionAt5Seconds.observedEvents == 0 {
            blockers.append(.missingFiveSecondCoverage)
        }
        if aggregate.retentionAt30Seconds.observedEvents == 0 {
            blockers.append(.missingThirtySecondCoverage)
        }
        if aggregate.retentionAtSegmentClose.observedEvents == 0 {
            blockers.append(.missingSegmentCoverage)
        }
        if !receipt.inputMethodRegistrationVerified {
            blockers.append(.inputMethodRegistrationUnverified)
        }
        if !previewProcessesStopped {
            blockers.append(.previewProcessesNotStopped)
        }
        if !installedIdentityVerified {
            blockers.append(.installedIdentityMismatch)
        }
        let latestEventTimestamp = events.map(\.occurredAt).max()!
        if flushAcknowledgement?.writeAccounting != writeAccounting
            || flushAcknowledgement.map({
                $0.acknowledgedAt < receipt.rotationTimestamp
                    || $0.acknowledgedAt < latestEventTimestamp
                    || $0.acknowledgedAt > generatedAt
        }) != false {
            blockers.append(.missingOrStaleFlushAcknowledgement)
        }
        if !terminalSnapshotSealed {
            blockers.append(.terminalSnapshotUnsealed)
        }
        return LabF03CloseoutReport(
            schema: LabF03CloseoutReport.currentSchema,
            generatedAt: generatedAt,
            runID: receipt.runID,
            profile: receipt.profile.rawValue,
            evidenceClass: receipt.evidenceClass,
            sourceState: receipt.sourceState,
            runnerSHA256: receipt.runnerSHA256,
            invocationProfile: receipt.invocationProfile,
            receiptSHA256: digest(receiptData),
            rotationTimestamp: receipt.rotationTimestamp,
            receiptCompletedTimestamp: receipt.completedTimestamp,
            receiptOutcomeLedgerGeneration: receipt.outcomeLedgerGeneration,
            currentOutcomeLedgerGeneration: currentGeneration,
            sourcePackageIdentity: receipt.sourcePackageIdentity,
            environmentIdentity: receipt.environmentIdentity,
            inputMethodRegistrationVerified: receipt.inputMethodRegistrationVerified,
            installedIdentityVerified: installedIdentityVerified,
            previewProcessesStopped: previewProcessesStopped,
            eventFileSHA256: digest(eventData),
            eventRows: events.count,
            writeAccounting: writeAccounting,
            flushAcknowledgement: flushAcknowledgement,
            eventSchemaCounts: schemaCounts,
            aggregateReport: aggregate,
            terminalSnapshotSealed: terminalSnapshotSealed,
            decisionGradeEligible: blockers.isEmpty,
            blockers: blockers,
            containsRawText: false,
            containsLocalPaths: false
        )
    }

    private static func publicationIndeterminate(
        _ report: LabF03CloseoutReport
    ) -> LabF03CloseoutReport {
        var blockers = report.blockers
        if !blockers.contains(.terminalPublicationIndeterminate) {
            blockers.append(.terminalPublicationIndeterminate)
        }
        return LabF03CloseoutReport(
            schema: report.schema,
            generatedAt: report.generatedAt,
            runID: report.runID,
            profile: report.profile,
            evidenceClass: report.evidenceClass,
            sourceState: report.sourceState,
            runnerSHA256: report.runnerSHA256,
            invocationProfile: report.invocationProfile,
            receiptSHA256: report.receiptSHA256,
            rotationTimestamp: report.rotationTimestamp,
            receiptCompletedTimestamp: report.receiptCompletedTimestamp,
            receiptOutcomeLedgerGeneration: report.receiptOutcomeLedgerGeneration,
            currentOutcomeLedgerGeneration: report.currentOutcomeLedgerGeneration,
            sourcePackageIdentity: report.sourcePackageIdentity,
            environmentIdentity: report.environmentIdentity,
            inputMethodRegistrationVerified: report.inputMethodRegistrationVerified,
            installedIdentityVerified: report.installedIdentityVerified,
            previewProcessesStopped: report.previewProcessesStopped,
            eventFileSHA256: report.eventFileSHA256,
            eventRows: report.eventRows,
            writeAccounting: report.writeAccounting,
            flushAcknowledgement: report.flushAcknowledgement,
            eventSchemaCounts: report.eventSchemaCounts,
            aggregateReport: report.aggregateReport,
            terminalSnapshotSealed: report.terminalSnapshotSealed,
            decisionGradeEligible: false,
            blockers: blockers,
            containsRawText: report.containsRawText,
            containsLocalPaths: report.containsLocalPaths
        )
    }

    @discardableResult
    static func writeNew(
        _ report: LabF03CloseoutReport,
        to output: URL
    ) throws -> NewOwnerFile.PublicationOutcome {
        try writeNew(report, to: output, beforeCommit: {})
    }

    @discardableResult
    static func writeNew(
        _ report: LabF03CloseoutReport,
        to output: URL,
        beforeCommit: () throws -> Void
    ) throws -> NewOwnerFile.PublicationOutcome {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try NewOwnerFile.write(
            try encoder.encode(report), to: output, beforeCommit: beforeCommit
        )
    }

    private static func count(_ value: Any?, default fallback: Int? = nil) -> Int? {
        guard let value else { return fallback }
        guard let count = value as? Int, count >= 0 else { return nil }
        return count
    }

    private static func writeState(
        generation: Int,
        defaults: UserDefaults
    ) throws -> (
        accounting: LabF03WriteAccounting,
        acknowledgement: LabF03FlushAcknowledgement?
    ) {
        let key = PersonalHistorySettingsContract.outcomeLedgerWriteCountsKey(generation)
        let dictionary = defaults.dictionary(forKey: key) ?? [:]
        let allowedKeys: Set<String> = [
            "attempted", "written", "dropped", "flushedAttempted", "flushedWritten",
            "flushedDropped", "flushedAtMilliseconds",
        ]
        guard Set(dictionary.keys).isSubset(of: allowedKeys),
              let attempted = count(dictionary["attempted"], default: 0),
              let written = count(dictionary["written"], default: 0),
              let dropped = count(dictionary["dropped"], default: 0) else {
            throw LabF03CloseoutError.invalidWriteAccounting
        }
        return (
            try LabF03WriteAccounting(
                attempted: attempted, written: written, dropped: dropped
            ),
            flushAcknowledgement(dictionary)
        )
    }

    private static func flushAcknowledgement(
        _ dictionary: [String: Any]?
    ) -> LabF03FlushAcknowledgement? {
        guard let dictionary,
              let attempted = count(dictionary["flushedAttempted"]),
              let written = count(dictionary["flushedWritten"]),
              let dropped = count(dictionary["flushedDropped"]),
              let timestamp = integer64(dictionary["flushedAtMilliseconds"]),
              timestamp >= 0,
              let accounting = try? LabF03WriteAccounting(
                attempted: attempted, written: written, dropped: dropped
              ) else { return nil }
        return LabF03FlushAcknowledgement(
            writeAccounting: accounting,
            acknowledgedAt: Date(timeIntervalSince1970: Double(timestamp) / 1_000)
        )
    }

    private static func integer64(_ value: Any?) -> Int64? {
        if let value = value as? Int64 { return value }
        if let value = value as? Int { return Int64(value) }
        return nil
    }

    private static func nextUnusedGeneration(
        after current: Int,
        in defaults: UserDefaults,
        maximumAttempts: Int = 4_096
    ) -> Int? {
        guard current >= 0, current < Int(Int32.max), maximumAttempts > 0 else { return nil }
        var candidate = current + 1
        for _ in 0..<maximumAttempts where candidate <= Int(Int32.max) {
            let key = PersonalHistorySettingsContract.outcomeLedgerWriteCountsKey(candidate)
            if defaults.object(forKey: key) == nil { return candidate }
            candidate += 1
        }
        return nil
    }

    private static func persistGeneration(_ generation: Int, in defaults: UserDefaults) throws {
        let key = PersonalHistorySettingsContract.outcomeLedgerGenerationKey
        defaults.set(generation, forKey: key)
        guard defaults.synchronize(), defaults.object(forKey: key) as? Int == generation else {
            throw LabF03CloseoutError.terminalSealFailed
        }
    }

    public static func previewProcessURLs(
        profile: TildeProductProfile,
        homeDirectory: URL
    ) -> [URL] {
        let app = URL(fileURLWithPath: "/Applications", isDirectory: true)
            .appendingPathComponent("\(profile.displayName).app", isDirectory: true)
        return [
            app.appendingPathComponent("Contents/MacOS/Tilde"),
            app.appendingPathComponent("Contents/Helpers/llama-server"),
            homeDirectory.appendingPathComponent("Library/Input Methods", isDirectory: true)
                .appendingPathComponent(profile.inputMethodInstalledBundleName, isDirectory: true)
                .appendingPathComponent("Contents/MacOS/InlineGhostIME"),
        ]
    }

    enum PreviewProcessKind: Equatable {
        case app
        case inputMethod
        case helper
    }

    struct PreviewProcessSigningIdentity: Equatable {
        let identifier: String
        let teamIdentifier: String?
        let cdHash: Data?
    }

    struct PreviewProcessObservation: Equatable {
        let executablePath: String
        let signingIdentity: PreviewProcessSigningIdentity?
    }

    /// Pure classification kept separate from the live process walk so tests
    /// never need to inspect or stop the owner's running Preview processes.
    static func previewProcessKind(
        _ observation: PreviewProcessObservation,
        expectedExecutables: [URL],
        expectedHelperIdentity: PreviewProcessSigningIdentity?
    ) -> PreviewProcessKind? {
        guard expectedExecutables.count == 3,
              observation.executablePath.hasPrefix("/") else { return nil }
        let path = URL(fileURLWithPath: observation.executablePath)
            .standardizedFileURL.path
        let expected = expectedExecutables.map { $0.standardizedFileURL.path }
        if path == expected[0] { return .app }
        if path == expected[1] { return .helper }
        if path == expected[2] { return .inputMethod }

        let profile = TildeProductProfile.preview9B
        if observation.signingIdentity?.identifier == profile.appBundleIdentifier {
            return .app
        }
        if observation.signingIdentity?.identifier == profile.inputMethodBundleIdentifier {
            return .inputMethod
        }

        let components = NSString(string: path).pathComponents
        guard let executableName = components.last else { return nil }
        let executableMarker = normalizedProcessMarker(executableName)
        let knownOtherHelperBundleNames = Set([
            TildeProductProfile.production,
            .preview26B,
            .modelPreview,
        ].map { "\($0.displayName).app" })
        let isKnownOtherProfileHelper = executableName == "llama-server"
            && !knownOtherHelperBundleNames.isDisjoint(with: components)
        if let expectedHelperIdentity,
           observation.signingIdentity == expectedHelperIdentity,
           !isKnownOtherProfileHelper {
            // `llama-server` has no profile-specific signing identifier. An
            // exact CDHash/team match catches a moved registered helper, while
            // explicit sibling-profile bundle paths stay independent even if
            // a future package reuses the same signed helper bytes.
            return .helper
        }
        let hasProfileMarker = components.contains { component in
            let marker = normalizedProcessMarker(component)
            return marker.contains("tilde9bpreview")
                || marker.contains("inlineghostime9bpreview")
                || marker.contains("preview9b")
                || marker.contains("9bpreview")
        }
        guard hasProfileMarker else { return nil }
        if executableName == "Tilde" { return .app }
        if executableName == "InlineGhostIME" { return .inputMethod }
        if executableName == "llama-server"
            || (executableMarker.contains("llamaserver")
                && (executableMarker.contains("preview9b")
                    || executableMarker.contains("9bpreview"))) {
            return .helper
        }
        return nil
    }

    /// `lsof` uses exit 1 with no output for a clean no-match result. Every
    /// malformed or diagnostic-bearing response is indeterminate so callers
    /// can fail closed rather than mistaking a probe failure for silence.
    static func lsofReportsProcesses(
        terminationStatus: Int32,
        standardOutput: Data,
        standardError: Data
    ) -> Bool? {
        guard standardOutput.count <= 1_024 * 1_024,
              standardError.isEmpty else { return nil }
        if terminationStatus == 1, standardOutput.isEmpty { return false }
        guard terminationStatus == 0, !standardOutput.isEmpty,
              let text = String(data: standardOutput, encoding: .utf8) else { return nil }
        let lines = text.split(whereSeparator: \Character.isNewline)
        guard !lines.isEmpty,
              lines.allSatisfy({ line in
                  !line.isEmpty && line.allSatisfy(\.isNumber)
                      && Int32(line).map({ $0 > 0 }) == true
              }) else { return nil }
        return true
    }

    static func isPotentialPreviewExecutableName(_ value: String) -> Bool {
        let marker = normalizedProcessMarker(value)
        return marker == "tilde" || marker.hasPrefix("inlineghostime")
            || marker.hasPrefix("llamaserver")
    }

    public static func exactPreviewProcessesAreStopped(_ executables: [URL]) -> Bool {
        guard executables.count == 3 else { return false }
        for executable in executables {
            guard lsofHasNoMatches([
                "-nP", "-a", "-d", "txt", "-t", "--", executable.path,
            ]) else { return false }
        }
        guard lsofHasNoMatches([
            "-nP", "-iTCP:\(TildeProductProfile.preview9B.llamaServerPort)",
            "-sTCP:LISTEN", "-t",
        ]),
              let helperIdentity = staticSigningIdentity(at: executables[1]),
              helperIdentity.teamIdentifier?.isEmpty == false,
              let helperCDHash = helperIdentity.cdHash,
              (20...64).contains(helperCDHash.count) else { return false }

        for _ in 0..<3 {
            switch ownedPreviewProcessState(
                expectedExecutables: executables,
                expectedHelperIdentity: helperIdentity
            ) {
            case .stopped: return true
            case .running: return false
            case .indeterminate: continue
            }
        }
        return false
    }

    private enum PreviewProcessState {
        case stopped
        case running
        case indeterminate
    }

    private enum DynamicSigningProbe {
        case valid(PreviewProcessSigningIdentity)
        case unsigned
        case invalid(PreviewProcessSigningIdentity?)
        case unavailable
    }

    private static func ownedPreviewProcessState(
        expectedExecutables: [URL],
        expectedHelperIdentity: PreviewProcessSigningIdentity
    ) -> PreviewProcessState {
        guard let processIDs = allProcessIDs() else { return .indeterminate }
        for pid in processIDs where pid > 0 {
            var before = proc_bsdinfo()
            let bsdSize = Int32(MemoryLayout<proc_bsdinfo>.stride)
            let beforeBytes = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &before, bsdSize)
            // A PID can disappear between the kernel's list and this lookup.
            // Only identities established as owner processes enter the strict
            // path/signature checks below.
            guard beforeBytes == bsdSize,
                  before.pbi_uid == UInt32(getuid()),
                  before.pbi_status != UInt32(SZOMB) else { continue }
            guard let path = processExecutablePath(pid) else {
                guard let name = processName(pid) else {
                    if processStability(pid: pid, before: before, path: nil) == .same {
                        return .indeterminate
                    }
                    continue
                }
                if isPotentialPreviewExecutableName(name),
                   processStability(pid: pid, before: before, path: nil) == .same {
                    return .indeterminate
                }
                continue
            }
            let pathOnly = PreviewProcessObservation(
                executablePath: path, signingIdentity: nil
            )
            if previewProcessKind(
                pathOnly,
                expectedExecutables: expectedExecutables,
                expectedHelperIdentity: expectedHelperIdentity
            ) != nil { return .running }
            guard isPotentialPreviewExecutableName(
                URL(fileURLWithPath: path).lastPathComponent
            ) else {
                if processStability(pid: pid, before: before, path: path) == .changed {
                    return .indeterminate
                }
                continue
            }

            let signingProbe = dynamicSigningIdentity(pid: pid)
            let signingIdentity: PreviewProcessSigningIdentity?
            switch signingProbe {
            case .valid(let identity):
                signingIdentity = identity
            case .unsigned:
                signingIdentity = nil
            case .invalid(let identity):
                if let identity,
                   previewProcessKind(
                       PreviewProcessObservation(
                           executablePath: path, signingIdentity: identity
                       ),
                       expectedExecutables: expectedExecutables,
                       expectedHelperIdentity: expectedHelperIdentity
                   ) != nil { return .running }
                if processStability(pid: pid, before: before, path: path) == .same {
                    return .indeterminate
                }
                continue
            case .unavailable:
                if processStability(pid: pid, before: before, path: path) == .same {
                    return .indeterminate
                }
                continue
            }
            if previewProcessKind(
                PreviewProcessObservation(
                    executablePath: path, signingIdentity: signingIdentity
                ),
                expectedExecutables: expectedExecutables,
                expectedHelperIdentity: expectedHelperIdentity
            ) != nil { return .running }

            switch processStability(pid: pid, before: before, path: path) {
            case .same: continue
            case .exitedOrReused: continue
            case .changed: return .indeterminate
            }
        }
        return .stopped
    }

    private enum ProcessStability: Equatable {
        case same
        case exitedOrReused
        case changed
    }

    private static func processStability(
        pid: pid_t,
        before: proc_bsdinfo,
        path: String?
    ) -> ProcessStability {
        var after = proc_bsdinfo()
        let bsdSize = Int32(MemoryLayout<proc_bsdinfo>.stride)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &after, bsdSize) == bsdSize,
              after.pbi_uid == before.pbi_uid,
              after.pbi_start_tvsec == before.pbi_start_tvsec,
              after.pbi_start_tvusec == before.pbi_start_tvusec,
              after.pbi_status != UInt32(SZOMB) else { return .exitedOrReused }
        guard let path else { return .same }
        guard let afterPath = processExecutablePath(pid) else { return .changed }
        return afterPath == path ? .same : .changed
    }

    private static func allProcessIDs() -> [pid_t]? {
        let observedCount = proc_listallpids(nil, 0)
        guard observedCount > 0 else { return nil }
        var capacity = max(Int(observedCount) + 256, 1_024)
        for _ in 0..<3 {
            var processIDs = [pid_t](repeating: 0, count: capacity)
            let written = proc_listallpids(
                &processIDs, Int32(processIDs.count * MemoryLayout<pid_t>.stride)
            )
            guard written > 0 else { return nil }
            if Int(written) < processIDs.count {
                return Array(processIDs.prefix(Int(written)))
            }
            guard capacity <= 1_000_000 else { return nil }
            capacity *= 2
        }
        return nil
    }

    private static func processExecutablePath(_ pid: pid_t) -> String? {
        let maximumPathBytes = 4_096
        var buffer = [CChar](repeating: 0, count: maximumPathBytes)
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        let bytes = buffer.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) }
        let path = String(decoding: bytes, as: UTF8.self)
        guard path.hasPrefix("/"), path.utf8.count <= maximumPathBytes else {
            return nil
        }
        return URL(fileURLWithPath: path).standardizedFileURL.path
    }

    private static func processName(_ pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: 1_024)
        guard proc_name(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        let bytes = buffer.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) }
        guard !bytes.isEmpty else { return nil }
        return String(decoding: bytes, as: UTF8.self)
    }

    private static func staticSigningIdentity(
        at url: URL
    ) -> PreviewProcessSigningIdentity? {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess,
              let code,
              SecStaticCodeCheckValidity(
                  code, SecCSFlags(rawValue: kSecCSStrictValidate), nil
              ) == errSecSuccess else { return nil }
        return signingIdentity(code)
    }

    private static func dynamicSigningIdentity(pid: pid_t) -> DynamicSigningProbe {
        var dynamicCode: SecCode?
        let status = SecCodeCopyGuestWithAttributes(
            nil, [kSecGuestAttributePid: pid] as CFDictionary, [], &dynamicCode
        )
        if status == errSecCSUnsigned { return .unsigned }
        guard status == errSecSuccess, let dynamicCode else { return .unavailable }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(dynamicCode, [], &staticCode) == errSecSuccess,
              let staticCode else { return .unavailable }
        let identity = signingIdentity(staticCode)
        let validity = SecCodeCheckValidity(dynamicCode, [], nil)
        if validity == errSecCSUnsigned { return .unsigned }
        guard validity == errSecSuccess else { return .invalid(identity) }
        guard let identity else { return .unavailable }
        return .valid(identity)
    }

    private static func signingIdentity(
        _ code: SecStaticCode
    ) -> PreviewProcessSigningIdentity? {
        var information: CFDictionary?
        guard SecCodeCopySigningInformation(
            code, SecCSFlags(rawValue: kSecCSSigningInformation), &information
        ) == errSecSuccess,
              let values = information as? [CFString: Any],
              let identifier = values[kSecCodeInfoIdentifier] as? String,
              !identifier.isEmpty else { return nil }
        return PreviewProcessSigningIdentity(
            identifier: identifier,
            teamIdentifier: values[kSecCodeInfoTeamIdentifier] as? String,
            cdHash: values[kSecCodeInfoUnique] as? Data
        )
    }

    private static func normalizedProcessMarker(_ value: String) -> String {
        value.lowercased().unicodeScalars.filter {
            CharacterSet.alphanumerics.contains($0)
        }.map(String.init).joined()
    }

    private static func lsofHasNoMatches(_ arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = arguments
        let output = Pipe()
        let errors = Pipe()
        process.standardOutput = output
        process.standardError = errors
        do {
            try process.run()
            process.waitUntilExit()
            return lsofReportsProcesses(
                terminationStatus: process.terminationStatus,
                standardOutput: output.fileHandleForReading.readDataToEndOfFile(),
                standardError: errors.fileHandleForReading.readDataToEndOfFile()
            ) == false
        } catch {
            return false
        }
    }

    public static func installedIdentityMatches(
        _ receipt: LabF03RunReceipt,
        homeDirectory: URL
    ) -> Bool {
        let app = URL(fileURLWithPath: "/Applications", isDirectory: true)
            .appendingPathComponent("\(receipt.profile.displayName).app", isDirectory: true)
        let inputMethod = homeDirectory
            .appendingPathComponent("Library/Input Methods", isDirectory: true)
            .appendingPathComponent(
                receipt.profile.inputMethodInstalledBundleName, isDirectory: true
            )
        let appBinary = app.appendingPathComponent("Contents/MacOS/Tilde")
        let helper = app.appendingPathComponent("Contents/Helpers/llama-server")
        let inputMethodBinary = inputMethod
            .appendingPathComponent("Contents/MacOS/InlineGhostIME")
        let appPlist = app.appendingPathComponent("Contents/Info.plist")
        let inputMethodPlist = inputMethod.appendingPathComponent("Contents/Info.plist")
        let model = homeDirectory
            .appendingPathComponent("Library/Application Support", isDirectory: true)
            .appendingPathComponent(receipt.profile.supportDirectoryName, isDirectory: true)
            .appendingPathComponent("Models/qwen3.5-9b-base-q4km-preview", isDirectory: true)
            .appendingPathComponent("model.gguf")
        let identity = receipt.sourcePackageIdentity
        guard strictSignatureTeamIdentifier(at: app) == identity.signingTeamIdentifier,
              strictSignatureTeamIdentifier(at: inputMethod) == identity.signingTeamIdentifier,
              strictSignatureTeamIdentifier(at: helper) == identity.signingTeamIdentifier,
              verifiedFileDigest(appBinary, maximumBytes: 2 * 1_024 * 1_024 * 1_024)
                == identity.installedAppBinarySHA256,
              verifiedFileDigest(inputMethodBinary, maximumBytes: 1_024 * 1_024 * 1_024)
                == identity.installedIMEBinarySHA256,
              verifiedFileDigest(helper, maximumBytes: 2 * 1_024 * 1_024 * 1_024)
                == identity.installedHelperSHA256,
              let appPlistContents = verifiedFileContents(
                appPlist, maximumBytes: 16 * 1_024 * 1_024
              ),
              appPlistContents.sha256 == identity.installedAppInfoPlistSHA256,
              let inputMethodPlistContents = verifiedFileContents(
                inputMethodPlist, maximumBytes: 16 * 1_024 * 1_024
              ),
              inputMethodPlistContents.sha256 == identity.installedIMEInfoPlistSHA256,
              installedPlistProvenanceMatches(
                receipt,
                appPlistData: appPlistContents.data,
                inputMethodPlistData: inputMethodPlistContents.data
              ),
              verifiedFileDigest(
                model,
                expectedBytes: identity.modelBytes,
                maximumBytes: identity.modelBytes,
                requiredMode: 0o600
              ) == identity.modelSHA256 else { return false }
        return true
    }

    static func installedPlistProvenanceMatches(
        _ receipt: LabF03RunReceipt,
        appPlistData: Data,
        inputMethodPlistData: Data
    ) -> Bool {
        let maximumPlistBytes = 16 * 1_024 * 1_024
        guard appPlistData.count <= maximumPlistBytes,
              inputMethodPlistData.count <= maximumPlistBytes,
              let app = propertyListDictionary(appPlistData),
              let inputMethod = propertyListDictionary(inputMethodPlistData) else { return false }

        let identity = receipt.sourcePackageIdentity
        let sharedExpected = [
            "TildeSourceCommit": identity.sourceCommit,
            "TildeSourceTree": identity.sourceTree,
            "TildeSourceSnapshotSHA256": identity.sourceSnapshotSHA256,
            "TildeSourceState": "clean",
            "TildeEvidenceClass": "decision-grade",
            "TildeAppleToolchainSHA256": identity.appleToolchainSHA256,
            "TildeXcodeVersion": identity.xcodeVersion,
            "TildeXcodeBuild": identity.xcodeBuild,
            "TildeSwiftVersionSHA256": identity.swiftVersionSHA256,
            "TildeSwiftExecutableSHA256": identity.swiftExecutableSHA256,
            "TildeMacOSSDKVersion": identity.macOSSDKVersion,
            "TildeMacOSSDKBuild": identity.macOSSDKBuild,
            "TildeMacOSSDKSettingsSHA256": identity.macOSSDKSettingsSHA256,
            "TildeApprovedHelperInputSHA256": identity.approvedHelperInputSHA256,
            "TildeApprovedHelperTeamIdentifier": identity.approvedHelperTeamIdentifier,
            "TildeF03RunnerSHA256": receipt.runnerSHA256,
            "CFBundleShortVersionString": identity.bundleVersion,
            "CFBundleVersion": identity.bundleBuild,
            "TildeProductProfile": receipt.profile.rawValue,
        ]
        let toolchainKeys = [
            "TildeXcodeVersion", "TildeXcodeBuild", "TildeXcodeCDHash",
            "TildeMacOSSDKVersion", "TildeMacOSSDKBuild",
            "TildeMacOSSDKSettingsSHA256", "TildeSwiftExecutableSHA256",
            "TildeSwiftVersionSHA256", "TildeSwiftBuildExecutableSHA256",
            "TildeSwiftDriverExecutableSHA256", "TildeClangExecutableSHA256",
            "TildeLinkerExecutableSHA256", "TildeLibtoolExecutableSHA256",
            "TildeArchiverExecutableSHA256",
        ]
        let digestKeys = [
            "TildeMacOSSDKSettingsSHA256", "TildeSwiftExecutableSHA256",
            "TildeSwiftVersionSHA256", "TildeSwiftBuildExecutableSHA256",
            "TildeSwiftDriverExecutableSHA256", "TildeClangExecutableSHA256",
            "TildeLinkerExecutableSHA256", "TildeLibtoolExecutableSHA256",
            "TildeArchiverExecutableSHA256",
        ]
        guard app["TildeAppleToolchainIdentitySchema"] as? String
                == "tilde-apple-toolchain-v2",
              inputMethod["TildeAppleToolchainIdentitySchema"] as? String
                == "tilde-apple-toolchain-v2",
              let toolchainValues = toolchainValues(
                keys: toolchainKeys, app: app, inputMethod: inputMethod
              ),
              isLowerHex(toolchainValues[2], counts: [40, 64]),
              digestKeys.allSatisfy({ key in
                  (app[key] as? String).map { isLowerHex($0, counts: [64]) } == true
              }),
              portableToolchainIdentitySHA256(toolchainValues)
                == identity.appleToolchainSHA256 else { return false }
        guard sharedExpected.allSatisfy({ key, expected in
            app[key] as? String == expected && inputMethod[key] as? String == expected
        }),
              app["CFBundleIdentifier"] as? String == receipt.profile.appBundleIdentifier,
              inputMethod["CFBundleIdentifier"] as? String
                == receipt.profile.inputMethodBundleIdentifier else { return false }
        return true
    }

    private static func toolchainValues(
        keys: [String],
        app: [String: Any],
        inputMethod: [String: Any]
    ) -> [String]? {
        var values: [String] = []
        values.reserveCapacity(keys.count)
        for key in keys {
            guard let appValue = app[key] as? String,
                  let inputMethodValue = inputMethod[key] as? String,
                  appValue == inputMethodValue else { return nil }
            values.append(appValue)
        }
        return values
    }

    private static func portableToolchainIdentitySHA256(_ values: [String]) -> String {
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

    private static func isLowerHex(_ value: String, counts: Set<Int>) -> Bool {
        counts.contains(value.utf8.count) && value.utf8.allSatisfy {
            (48...57).contains($0) || (97...102).contains($0)
        }
    }

    private static func propertyListDictionary(_ data: Data) -> [String: Any]? {
        guard let value = try? PropertyListSerialization.propertyList(
            from: data, options: [], format: nil
        ) else { return nil }
        return value as? [String: Any]
    }

    private static func strictSignatureTeamIdentifier(at url: URL) -> String? {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess,
              let code else { return nil }
        let flags = SecCSFlags(
            rawValue: kSecCSCheckAllArchitectures | kSecCSCheckNestedCode | kSecCSStrictValidate
        )
        guard SecStaticCodeCheckValidity(code, flags, nil) == errSecSuccess else { return nil }
        var information: CFDictionary?
        guard SecCodeCopySigningInformation(
            code, SecCSFlags(rawValue: kSecCSSigningInformation), &information
        ) == errSecSuccess,
              let values = information as? [CFString: Any],
              let team = values[kSecCodeInfoTeamIdentifier] as? String,
              !team.isEmpty else { return nil }
        return team
    }

    struct VerifiedFileContents {
        let data: Data
        let sha256: String
    }

    static func verifiedFileDigest(
        _ url: URL,
        expectedBytes: Int64? = nil,
        maximumBytes: Int64,
        requiredMode: mode_t? = nil
    ) -> String? {
        verifiedFile(
            url,
            expectedBytes: expectedBytes,
            maximumBytes: maximumBytes,
            requiredMode: requiredMode,
            captureContents: false
        )?.sha256
    }

    static func verifiedFileContents(
        _ url: URL,
        expectedBytes: Int64? = nil,
        maximumBytes: Int64,
        requiredMode: mode_t? = nil
    ) -> VerifiedFileContents? {
        guard let verified = verifiedFile(
            url,
            expectedBytes: expectedBytes,
            maximumBytes: maximumBytes,
            requiredMode: requiredMode,
            captureContents: true
        ), let data = verified.data else { return nil }
        return VerifiedFileContents(data: data, sha256: verified.sha256)
    }

    private static func verifiedFile(
        _ url: URL,
        expectedBytes: Int64?,
        maximumBytes: Int64,
        requiredMode: mode_t?,
        captureContents: Bool
    ) -> (sha256: String, data: Data?)? {
        guard url.isFileURL, maximumBytes >= 0 else { return nil }
        let descriptor = open(
            url.path, O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC
        )
        guard descriptor >= 0 else { return nil }
        defer { close(descriptor) }
        var before = stat()
        guard fstat(descriptor, &before) == 0,
              before.st_mode & S_IFMT == S_IFREG,
              before.st_uid == getuid(),
              before.st_nlink == 1,
              requiredMode.map({ before.st_mode & 0o7777 == $0 })
                ?? (before.st_mode & 0o022 == 0),
              before.st_size >= 0, before.st_size <= maximumBytes,
              expectedBytes == nil || before.st_size == expectedBytes,
              clearNonblocking(descriptor) else { return nil }

        var hasher = SHA256()
        var capturedData: Data?
        if captureContents {
            guard before.st_size <= Int.max else { return nil }
            capturedData = Data()
            capturedData?.reserveCapacity(Int(before.st_size))
        }
        var buffer = [UInt8](repeating: 0, count: 1_024 * 1_024)
        var bytesRead: Int64 = 0
        while true {
            let count = Darwin.read(descriptor, &buffer, buffer.count)
            if count == 0 { break }
            if count < 0 {
                if errno == EINTR { continue }
                return nil
            }
            bytesRead += Int64(count)
            guard bytesRead <= maximumBytes else { return nil }
            let chunk = Data(buffer.prefix(count))
            hasher.update(data: chunk)
            capturedData?.append(chunk)
        }
        var after = stat()
        var pathInfo = stat()
        guard fstat(descriptor, &after) == 0,
              lstat(url.path, &pathInfo) == 0,
              before.st_dev == after.st_dev, before.st_ino == after.st_ino,
              before.st_size == after.st_size,
              before.st_mtimespec.tv_sec == after.st_mtimespec.tv_sec,
              before.st_mtimespec.tv_nsec == after.st_mtimespec.tv_nsec,
              after.st_mode & S_IFMT == S_IFREG, after.st_uid == getuid(),
              after.st_nlink == 1,
              requiredMode.map({ after.st_mode & 0o7777 == $0 })
                ?? (after.st_mode & 0o022 == 0),
              after.st_dev == pathInfo.st_dev, after.st_ino == pathInfo.st_ino,
              bytesRead == after.st_size else { return nil }
        return (
            hasher.finalize().map { String(format: "%02x", $0) }.joined(),
            capturedData
        )
    }

    private static func clearNonblocking(_ descriptor: Int32) -> Bool {
        let flags = fcntl(descriptor, F_GETFL)
        return flags >= 0 && fcntl(descriptor, F_SETFL, flags & ~O_NONBLOCK) == 0
    }

    private static func decodeEvents(_ data: Data) throws -> [LabOnlineExperimentEvent] {
        guard !data.isEmpty, data.count <= 64 * 1_024 * 1_024, data.last == 0x0A else {
            throw LabF03CloseoutError.malformedEventFile
        }
        var lines = data.split(separator: 0x0A, omittingEmptySubsequences: false)
        guard lines.last?.isEmpty == true else { throw LabF03CloseoutError.malformedEventFile }
        lines.removeLast()
        guard !lines.isEmpty, lines.count <= 1_000_000,
              lines.allSatisfy({ !$0.isEmpty && $0.count <= 64 * 1_024 }) else {
            throw LabF03CloseoutError.malformedEventFile
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try lines.map { line in
            let bytes = Data(line)
            do {
                try LabOnlineEventPrivacy.validateJSON(bytes)
            } catch LabOnlineExperimentError.forbiddenKey(let key) {
                throw LabF03CloseoutError.forbiddenEventKey(key)
            } catch {
                throw LabF03CloseoutError.malformedEventFile
            }
            do {
                return try decoder.decode(LabOnlineExperimentEvent.self, from: bytes)
            } catch {
                throw LabF03CloseoutError.malformedEventFile
            }
        }
    }

    private static func closeoutPlan(
        campaignID: UUID,
        events: [LabOnlineExperimentEvent]
    ) throws -> LabOnlineExperimentPlan {
        guard let earliest = events.map(\.occurredAt).min(),
              let latest = events.map(\.occurredAt).max(),
              latest.timeIntervalSince(earliest) < 31 * 86_400 else {
            throw LabF03CloseoutError.malformedEventFile
        }
        let hasDisplayedChallenger = events.contains { $0.variant == .challenger && $0.displayed }
        return try LabOnlineExperimentPlan(
            campaignID: campaignID,
            phase: hasDisplayedChallenger ? .dogfood : .shadow,
            championArmID: "champion",
            championArmDigestSHA256: String(repeating: "c", count: 64),
            challengerArmID: "challenger",
            challengerArmDigestSHA256: String(repeating: "d", count: 64),
            challengerAllocation: hasDisplayedChallenger ? 0.5 : 0,
            startsAt: earliest.addingTimeInterval(-1),
            endsAt: max(latest.addingTimeInterval(1), earliest.addingTimeInterval(1)),
            safetyEvidenceDigestSHA256: hasDisplayedChallenger
                ? LabInstrumentCampaign.armedSafetyEvidenceDigestSHA256 : nil
        ).validated()
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

private final class F03MaintenanceLock {
    private let directoryParentDescriptor: Int32
    private let directoryDescriptor: Int32
    private let directoryName: String
    private let directoryPath: String
    private let descriptor: Int32

    private init(
        directoryParentDescriptor: Int32,
        directoryDescriptor: Int32,
        directoryName: String,
        directoryPath: String,
        descriptor: Int32
    ) {
        self.directoryParentDescriptor = directoryParentDescriptor
        self.directoryDescriptor = directoryDescriptor
        self.directoryName = directoryName
        self.directoryPath = directoryPath
        self.descriptor = descriptor
    }

    deinit {
        close(descriptor)
        close(directoryDescriptor)
        close(directoryParentDescriptor)
    }

    func requireNoUnfinishedTransaction() throws {
        try requireVisibleDirectoryIdentity()
        var directoryInfo = stat()
        var lockInfo = stat()
        var visibleLockInfo = stat()
        guard fstat(directoryDescriptor, &directoryInfo) == 0,
              directoryInfo.st_mode & S_IFMT == S_IFDIR,
              directoryInfo.st_uid == getuid(),
              directoryInfo.st_mode & 0o7777 == 0o700,
              directoryInfo.st_nlink > 0,
              fstat(descriptor, &lockInfo) == 0,
              fstatat(
                directoryDescriptor,
                ".f03-maintenance.lock",
                &visibleLockInfo,
                AT_SYMLINK_NOFOLLOW
              ) == 0,
              lockInfo.st_mode & S_IFMT == S_IFREG,
              lockInfo.st_uid == getuid(),
              lockInfo.st_mode & 0o7777 == 0o600,
              lockInfo.st_nlink == 1,
              lockInfo.st_dev == visibleLockInfo.st_dev,
              lockInfo.st_ino == visibleLockInfo.st_ino else {
            throw LabF03CloseoutError.unsafeMaintenanceLock
        }

        for name in [".f03-transaction.json", ".f03-transaction.tmp"] {
            var journalInfo = stat()
            errno = 0
            if fstatat(
                directoryDescriptor, name, &journalInfo, AT_SYMLINK_NOFOLLOW
            ) == 0 {
                throw LabF03CloseoutError.unfinishedMaintenanceTransaction
            }
            guard errno == ENOENT else {
                throw LabF03CloseoutError.unsafeMaintenanceLock
            }
        }
    }

    func withRead<Result>(
        directoryName: String,
        fileName: String,
        maximumBytes: Int,
        unsafeError: LabF03CloseoutError,
        tooLargeError: LabF03CloseoutError,
        directoryLock: Int32,
        fileLock: Int32,
        body: (LockedOwnerFile.Snapshot) throws -> Result
    ) throws -> Result {
        try requireVisibleDirectoryIdentity()
        return try LockedOwnerFile.withRead(
            relativeToParentDirectory: directoryDescriptor,
            directoryName: directoryName,
            fileName: fileName,
            maximumBytes: maximumBytes,
            unsafeError: unsafeError,
            tooLargeError: tooLargeError,
            directoryLock: directoryLock,
            fileLock: fileLock,
            body: body
        )
    }

    private func requireVisibleDirectoryIdentity() throws {
        var held = stat()
        var relativeVisible = stat()
        var absoluteVisible = stat()
        guard fstat(directoryDescriptor, &held) == 0,
              fstatat(
                directoryParentDescriptor,
                directoryName,
                &relativeVisible,
                AT_SYMLINK_NOFOLLOW
              ) == 0,
              lstat(directoryPath, &absoluteVisible) == 0,
              held.st_mode & S_IFMT == S_IFDIR,
              relativeVisible.st_mode & S_IFMT == S_IFDIR,
              absoluteVisible.st_mode & S_IFMT == S_IFDIR,
              held.st_uid == getuid(),
              relativeVisible.st_uid == getuid(),
              absoluteVisible.st_uid == getuid(),
              held.st_mode & 0o7777 == 0o700,
              relativeVisible.st_mode & 0o7777 == 0o700,
              absoluteVisible.st_mode & 0o7777 == 0o700,
              held.st_nlink > 0,
              relativeVisible.st_nlink > 0,
              absoluteVisible.st_nlink > 0,
              held.st_dev == relativeVisible.st_dev,
              held.st_ino == relativeVisible.st_ino,
              held.st_dev == absoluteVisible.st_dev,
              held.st_ino == absoluteVisible.st_ino else {
            throw LabF03CloseoutError.unsafeMaintenanceLock
        }
    }

    static func acquireShared(supportDirectory: URL) throws -> F03MaintenanceLock {
        let components = supportDirectory.path.split(separator: "/").map(String.init)
        guard supportDirectory.isFileURL, supportDirectory.path.hasPrefix("/"),
              !components.isEmpty,
              !components.contains(where: { $0 == "." || $0 == ".." }) else {
            throw LabF03CloseoutError.unsafeMaintenanceLock
        }

        var parent = open("/", O_RDONLY | O_DIRECTORY | O_CLOEXEC)
        guard parent >= 0 else { throw LabF03CloseoutError.unsafeMaintenanceLock }
        for component in components.dropLast() {
            let child = openat(
                parent, component, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
            )
            close(parent)
            guard child >= 0 else { throw LabF03CloseoutError.unsafeMaintenanceLock }
            parent = child
        }
        let directory = openat(
            parent, components.last!, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
        )
        guard directory >= 0 else {
            close(parent)
            throw LabF03CloseoutError.unsafeMaintenanceLock
        }
        var directoryInfo = stat()
        var pathDirectoryInfo = stat()
        var absoluteDirectoryInfo = stat()
        let safeDirectory = fstat(directory, &directoryInfo) == 0
            && fstatat(
                parent, components.last!, &pathDirectoryInfo, AT_SYMLINK_NOFOLLOW
            ) == 0
            && lstat(supportDirectory.path, &absoluteDirectoryInfo) == 0
            && directoryInfo.st_mode & S_IFMT == S_IFDIR
            && pathDirectoryInfo.st_mode & S_IFMT == S_IFDIR
            && absoluteDirectoryInfo.st_mode & S_IFMT == S_IFDIR
            && directoryInfo.st_uid == getuid()
            && pathDirectoryInfo.st_uid == getuid()
            && absoluteDirectoryInfo.st_uid == getuid()
            && directoryInfo.st_mode & 0o7777 == 0o700
            && pathDirectoryInfo.st_mode & 0o7777 == 0o700
            && absoluteDirectoryInfo.st_mode & 0o7777 == 0o700
            && directoryInfo.st_dev == pathDirectoryInfo.st_dev
            && directoryInfo.st_ino == pathDirectoryInfo.st_ino
            && directoryInfo.st_dev == absoluteDirectoryInfo.st_dev
            && directoryInfo.st_ino == absoluteDirectoryInfo.st_ino
        guard safeDirectory else {
            close(directory)
            close(parent)
            throw LabF03CloseoutError.unsafeMaintenanceLock
        }

        let descriptor = openat(
            directory, ".f03-maintenance.lock",
            O_RDWR | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC
        )
        guard descriptor >= 0 else {
            close(directory)
            close(parent)
            throw LabF03CloseoutError.unsafeMaintenanceLock
        }
        var info = stat()
        var pathInfo = stat()
        let safeFile = fstat(descriptor, &info) == 0
            && fstatat(
                directory, ".f03-maintenance.lock", &pathInfo, AT_SYMLINK_NOFOLLOW
            ) == 0
            && info.st_mode & S_IFMT == S_IFREG
            && info.st_uid == getuid()
            && info.st_mode & 0o7777 == 0o600
            && info.st_nlink == 1
            && info.st_dev == pathInfo.st_dev
            && info.st_ino == pathInfo.st_ino
        guard safeFile else {
            close(descriptor)
            close(directory)
            close(parent)
            throw LabF03CloseoutError.unsafeMaintenanceLock
        }
        guard flock(descriptor, LOCK_SH | LOCK_NB) == 0 else {
            let lockError = errno
            close(descriptor)
            close(directory)
            close(parent)
            if lockError == EWOULDBLOCK || lockError == EAGAIN {
                throw LabF03CloseoutError.maintenanceLockUnavailable
            }
            throw LabF03CloseoutError.unsafeMaintenanceLock
        }
        guard fstat(descriptor, &info) == 0,
              fstatat(
                directory, ".f03-maintenance.lock", &pathInfo, AT_SYMLINK_NOFOLLOW
              ) == 0,
              info.st_mode & S_IFMT == S_IFREG,
              info.st_uid == getuid(), info.st_mode & 0o7777 == 0o600,
              info.st_nlink == 1,
              info.st_dev == pathInfo.st_dev, info.st_ino == pathInfo.st_ino else {
            close(descriptor)
            close(directory)
            close(parent)
            throw LabF03CloseoutError.unsafeMaintenanceLock
        }
        return F03MaintenanceLock(
            directoryParentDescriptor: parent,
            directoryDescriptor: directory,
            directoryName: components.last!,
            directoryPath: supportDirectory.path,
            descriptor: descriptor
        )
    }
}

enum LockedOwnerFile {
    final class Snapshot {
        let data: Data
        private let directoryParentDescriptor: Int32
        private let directoryDescriptor: Int32
        private let directoryName: String
        private let descriptor: Int32
        private var baseline: stat
        private let maximumBytes: Int
        private let unsafeError: LabF03CloseoutError
        private(set) var fileName: String

        fileprivate init(
            data: Data,
            directoryParentDescriptor: Int32,
            directoryDescriptor: Int32,
            directoryName: String,
            descriptor: Int32,
            fileName: String,
            baseline: stat,
            maximumBytes: Int,
            unsafeError: LabF03CloseoutError
        ) {
            self.data = data
            self.directoryParentDescriptor = directoryParentDescriptor
            self.directoryDescriptor = directoryDescriptor
            self.directoryName = directoryName
            self.descriptor = descriptor
            self.fileName = fileName
            self.baseline = baseline
            self.maximumBytes = maximumBytes
            self.unsafeError = unsafeError
        }

        func validate() throws {
            try LockedOwnerFile.validateDirectory(
                parent: directoryParentDescriptor,
                descriptor: directoryDescriptor,
                name: directoryName,
                error: unsafeError
            )
            var held = stat()
            var visible = stat()
            guard fstat(descriptor, &held) == 0,
                  fstatat(directoryDescriptor, fileName, &visible, AT_SYMLINK_NOFOLLOW) == 0,
                  LockedOwnerFile.isSafeFile(held, maximumBytes: maximumBytes),
                  LockedOwnerFile.isSafeFile(visible, maximumBytes: maximumBytes),
                  held.st_dev == visible.st_dev, held.st_ino == visible.st_ino,
                  held.st_dev == baseline.st_dev, held.st_ino == baseline.st_ino,
                  held.st_size == baseline.st_size,
                  held.st_mtimespec.tv_sec == baseline.st_mtimespec.tv_sec,
                  held.st_mtimespec.tv_nsec == baseline.st_mtimespec.tv_nsec,
                  held.st_ctimespec.tv_sec == baseline.st_ctimespec.tv_sec,
                  held.st_ctimespec.tv_nsec == baseline.st_ctimespec.tv_nsec,
                  data.count == Int(held.st_size) else { throw unsafeError }
        }

        func rename(to newName: String) throws {
            guard !newName.isEmpty, newName != ".", newName != "..", !newName.contains("/")
            else { throw LabF03CloseoutError.terminalSealFailed }
            try validate()
            var existing = stat()
            guard fstatat(directoryDescriptor, newName, &existing, AT_SYMLINK_NOFOLLOW) != 0,
                  errno == ENOENT else { throw LabF03CloseoutError.terminalSealFailed }
            guard renameatx_np(
                directoryDescriptor,
                fileName,
                directoryDescriptor,
                newName,
                UInt32(RENAME_EXCL | RENAME_NOFOLLOW_ANY)
            ) == 0 else { throw LabF03CloseoutError.terminalSealFailed }
            fileName = newName
            guard fsync(directoryDescriptor) == 0 else {
                throw LabF03CloseoutError.terminalSealFailed
            }
            var renamed = stat()
            guard fstat(descriptor, &renamed) == 0,
                  LockedOwnerFile.isSafeFile(renamed, maximumBytes: maximumBytes),
                  renamed.st_dev == baseline.st_dev, renamed.st_ino == baseline.st_ino,
                  renamed.st_size == baseline.st_size,
                  renamed.st_mtimespec.tv_sec == baseline.st_mtimespec.tv_sec,
                  renamed.st_mtimespec.tv_nsec == baseline.st_mtimespec.tv_nsec else {
                throw LabF03CloseoutError.terminalSealFailed
            }
            baseline = renamed
            try validate()
        }
    }

    static func read(
        _ url: URL,
        maximumBytes: Int,
        unsafeError: LabF03CloseoutError,
        tooLargeError: LabF03CloseoutError
    ) throws -> Data {
        try withRead(
            url,
            maximumBytes: maximumBytes,
            unsafeError: unsafeError,
            tooLargeError: tooLargeError
        ) { $0.data }
    }

    static func withRead<Result>(
        _ url: URL,
        maximumBytes: Int,
        unsafeError: LabF03CloseoutError,
        tooLargeError: LabF03CloseoutError,
        directoryLock: Int32 = LOCK_SH,
        fileLock: Int32 = LOCK_SH,
        body: (Snapshot) throws -> Result
    ) throws -> Result {
        guard maximumBytes >= 0,
              url.isFileURL,
              url.path.hasPrefix("/"),
              !url.lastPathComponent.isEmpty,
              url.lastPathComponent != ".",
              url.lastPathComponent != ".." else { throw unsafeError }
        let opened = try openParentDirectory(of: url, error: unsafeError)
        return try withRead(
            opened: opened,
            fileName: url.lastPathComponent,
            maximumBytes: maximumBytes,
            unsafeError: unsafeError,
            tooLargeError: tooLargeError,
            directoryLock: directoryLock,
            fileLock: fileLock,
            body: body
        )
    }

    static func withRead<Result>(
        relativeToParentDirectory parentDescriptor: Int32,
        directoryName: String,
        fileName: String,
        maximumBytes: Int,
        unsafeError: LabF03CloseoutError,
        tooLargeError: LabF03CloseoutError,
        directoryLock: Int32 = LOCK_SH,
        fileLock: Int32 = LOCK_SH,
        body: (Snapshot) throws -> Result
    ) throws -> Result {
        guard maximumBytes >= 0,
              !directoryName.isEmpty, directoryName != ".", directoryName != "..",
              !directoryName.contains("/"),
              !fileName.isEmpty, fileName != ".", fileName != "..",
              !fileName.contains("/") else { throw unsafeError }
        let parent = fcntl(parentDescriptor, F_DUPFD_CLOEXEC, 0)
        guard parent >= 0 else { throw unsafeError }
        let directory = openat(
            parent,
            directoryName,
            O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
        )
        guard directory >= 0 else {
            close(parent)
            throw unsafeError
        }
        return try withRead(
            opened: (parent: parent, directory: directory, name: directoryName),
            fileName: fileName,
            maximumBytes: maximumBytes,
            unsafeError: unsafeError,
            tooLargeError: tooLargeError,
            directoryLock: directoryLock,
            fileLock: fileLock,
            body: body
        )
    }

    private static func withRead<Result>(
        opened: (parent: Int32, directory: Int32, name: String),
        fileName: String,
        maximumBytes: Int,
        unsafeError: LabF03CloseoutError,
        tooLargeError: LabF03CloseoutError,
        directoryLock: Int32,
        fileLock: Int32,
        body: (Snapshot) throws -> Result
    ) throws -> Result {
        let directoryParent = opened.parent
        let directory = opened.directory
        defer {
            close(directory)
            close(directoryParent)
        }
        try validateDirectory(
            parent: directoryParent,
            descriptor: directory,
            name: opened.name,
            error: unsafeError
        )
        guard flock(directory, directoryLock) == 0 else { throw unsafeError }
        try validateDirectory(
            parent: directoryParent,
            descriptor: directory,
            name: opened.name,
            error: unsafeError
        )

        let descriptor = openat(
            directory, fileName,
            O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC
        )
        guard descriptor >= 0 else { throw unsafeError }
        defer { close(descriptor) }
        var baseline = stat()
        var visible = stat()
        guard fstat(descriptor, &baseline) == 0,
              fstatat(directory, fileName, &visible, AT_SYMLINK_NOFOLLOW) == 0,
              isSafeFile(baseline, maximumBytes: maximumBytes),
              isSafeFile(visible, maximumBytes: maximumBytes),
              baseline.st_dev == visible.st_dev, baseline.st_ino == visible.st_ino,
              flock(descriptor, fileLock) == 0 else {
            if baseline.st_size > maximumBytes { throw tooLargeError }
            throw unsafeError
        }
        let flags = fcntl(descriptor, F_GETFL)
        guard flags >= 0, fcntl(descriptor, F_SETFL, flags & ~O_NONBLOCK) == 0 else {
            throw unsafeError
        }
        var data = Data()
        data.reserveCapacity(Int(baseline.st_size))
        var buffer = [UInt8](repeating: 0, count: 64 * 1_024)
        while true {
            let count = Darwin.read(descriptor, &buffer, buffer.count)
            if count == 0 { break }
            if count < 0 {
                if errno == EINTR { continue }
                throw unsafeError
            }
            guard data.count + count <= maximumBytes else { throw tooLargeError }
            data.append(contentsOf: buffer.prefix(count))
        }
        let snapshot = Snapshot(
            data: data,
            directoryParentDescriptor: directoryParent,
            directoryDescriptor: directory,
            directoryName: opened.name,
            descriptor: descriptor,
            fileName: fileName,
            baseline: baseline,
            maximumBytes: maximumBytes,
            unsafeError: unsafeError
        )
        try snapshot.validate()
        let result = try body(snapshot)
        try snapshot.validate()
        return result
    }

    private static func openParentDirectory(
        of url: URL,
        error: LabF03CloseoutError
    ) throws -> (parent: Int32, directory: Int32, name: String) {
        let components = url.deletingLastPathComponent().path.split(separator: "/").map(String.init)
        guard !components.isEmpty,
              !components.contains(where: { $0 == "." || $0 == ".." }) else { throw error }
        var parent = open("/", O_RDONLY | O_DIRECTORY | O_CLOEXEC)
        guard parent >= 0 else { throw error }
        for (index, component) in components.enumerated() {
            let child = openat(
                parent, component, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
            )
            guard child >= 0 else {
                close(parent)
                throw error
            }
            if index == components.count - 1 {
                return (parent, child, component)
            }
            close(parent)
            parent = child
        }
        close(parent)
        throw error
    }

    private static func validateDirectory(
        parent: Int32,
        descriptor: Int32,
        name: String,
        error: LabF03CloseoutError
    ) throws {
        var held = stat()
        var visible = stat()
        guard fstat(descriptor, &held) == 0,
              fstatat(parent, name, &visible, AT_SYMLINK_NOFOLLOW) == 0,
              held.st_mode & S_IFMT == S_IFDIR,
              visible.st_mode & S_IFMT == S_IFDIR,
              held.st_uid == getuid(), visible.st_uid == getuid(),
              held.st_mode & 0o7777 == 0o700,
              visible.st_mode & 0o7777 == 0o700,
              held.st_nlink > 0, visible.st_nlink > 0,
              held.st_dev == visible.st_dev, held.st_ino == visible.st_ino else { throw error }
    }

    private static func isSafeFile(_ info: stat, maximumBytes: Int) -> Bool {
        info.st_mode & S_IFMT == S_IFREG
            && info.st_uid == getuid()
            && info.st_mode & 0o7777 == 0o600
            && info.st_nlink == 1
            && info.st_size >= 0
            && info.st_size <= maximumBytes
    }
}

enum NewOwnerFile {
    struct PublicationOutcome: Equatable {
        let committed: Bool
        let postCommitChecksPassed: Bool

        static func committed(postCommitChecksPassed: Bool) -> Self {
            Self(committed: true, postCommitChecksPassed: postCommitChecksPassed)
        }
    }

    @discardableResult
    static func write(
        _ data: Data,
        to url: URL,
        beforeCommit: () throws -> Void = {},
        postCommitProbe: () throws -> Void = {}
    ) throws -> PublicationOutcome {
        guard url.isFileURL,
              url.path.hasPrefix("/"),
              !url.lastPathComponent.isEmpty,
              url.lastPathComponent != ".",
              url.lastPathComponent != ".." else {
            throw LabF03CloseoutError.outputWriteFailed
        }
        let opened = try openParentDirectory(of: url)
        let directoryParent = opened.parent
        let directory = opened.directory
        defer {
            close(directory)
            close(directoryParent)
        }
        try validateDirectory(parent: directoryParent, descriptor: directory, name: opened.name)
        guard flock(directory, LOCK_EX) == 0 else {
            throw LabF03CloseoutError.outputWriteFailed
        }
        try validateDirectory(parent: directoryParent, descriptor: directory, name: opened.name)

        let finalName = url.lastPathComponent
        var existing = stat()
        if fstatat(directory, finalName, &existing, AT_SYMLINK_NOFOLLOW) == 0 {
            throw LabF03CloseoutError.outputExists
        }
        guard errno == ENOENT else { throw LabF03CloseoutError.outputWriteFailed }
        let temporaryName = ".f03-closeout.\(UUID().uuidString.lowercased()).tmp"
        let descriptor = openat(
            directory, temporaryName,
            O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600
        )
        guard descriptor >= 0 else { throw LabF03CloseoutError.outputWriteFailed }
        var createdIdentity: (device: dev_t, inode: ino_t)?
        var published = false
        defer {
            if !published, let createdIdentity {
                var pathInfo = stat()
                if fstatat(
                    directory, temporaryName, &pathInfo, AT_SYMLINK_NOFOLLOW
                ) == 0,
                   pathInfo.st_dev == createdIdentity.device,
                   pathInfo.st_ino == createdIdentity.inode {
                    _ = unlinkat(directory, temporaryName, 0)
                    _ = fsync(directory)
                }
            }
            close(descriptor)
        }
        var created = stat()
        var visible = stat()
        guard fstat(descriptor, &created) == 0,
              fstatat(directory, temporaryName, &visible, AT_SYMLINK_NOFOLLOW) == 0,
              created.st_mode & S_IFMT == S_IFREG,
              visible.st_mode & S_IFMT == S_IFREG,
              created.st_uid == getuid(), visible.st_uid == getuid(),
              created.st_nlink == 1, visible.st_nlink == 1,
              created.st_dev == visible.st_dev, created.st_ino == visible.st_ino else {
            throw LabF03CloseoutError.outputWriteFailed
        }
        createdIdentity = (created.st_dev, created.st_ino)
        let wroteAll = data.withUnsafeBytes { bytes -> Bool in
            guard let base = bytes.baseAddress else { return data.isEmpty }
            var offset = 0
            while offset < bytes.count {
                let count = Darwin.write(descriptor, base.advanced(by: offset), bytes.count - offset)
                if count < 0 {
                    if errno == EINTR { continue }
                    return false
                }
                if count == 0 { return false }
                offset += count
            }
            return true
        }
        var staged = stat()
        var stagedPath = stat()
        guard wroteAll, fchmod(descriptor, 0o600) == 0,
              fsync(descriptor) == 0,
              fstat(descriptor, &staged) == 0,
              fstatat(
                directory, temporaryName, &stagedPath, AT_SYMLINK_NOFOLLOW
              ) == 0,
              staged.st_mode & S_IFMT == S_IFREG, stagedPath.st_mode & S_IFMT == S_IFREG,
              staged.st_uid == getuid(), stagedPath.st_uid == getuid(),
              staged.st_mode & 0o7777 == 0o600, stagedPath.st_mode & 0o7777 == 0o600,
              staged.st_nlink == 1, stagedPath.st_nlink == 1,
              staged.st_dev == created.st_dev, staged.st_ino == created.st_ino,
              staged.st_dev == stagedPath.st_dev, staged.st_ino == stagedPath.st_ino else {
            throw LabF03CloseoutError.outputWriteFailed
        }
        try validateDirectory(parent: directoryParent, descriptor: directory, name: opened.name)
        try beforeCommit()
        try validateDirectory(parent: directoryParent, descriptor: directory, name: opened.name)
        guard renameatx_np(
            directory,
            temporaryName,
            directory,
            finalName,
            UInt32(RENAME_EXCL | RENAME_NOFOLLOW_ANY)
        ) == 0 else {
            if errno == EEXIST { throw LabF03CloseoutError.outputExists }
            throw LabF03CloseoutError.outputWriteFailed
        }
        published = true
        // The exclusive rename is the definitive publication boundary. Every
        // operation below is diagnostic or best-effort durability work: once
        // an eligible final JSON is visible, this method must return a committed
        // outcome rather than throwing and leaving the caller unsure whether to
        // roll the terminal generation back.
        var postCommitChecksPassed = true
        do { try postCommitProbe() }
        catch { postCommitChecksPassed = false }
        if fsync(directory) != 0 { postCommitChecksPassed = false }
        var final = stat()
        var finalPath = stat()
        if !(fstat(descriptor, &final) == 0
            && fstatat(directory, finalName, &finalPath, AT_SYMLINK_NOFOLLOW) == 0
            && final.st_mode & S_IFMT == S_IFREG
            && finalPath.st_mode & S_IFMT == S_IFREG
            && final.st_uid == getuid() && finalPath.st_uid == getuid()
            && final.st_mode & 0o7777 == 0o600 && finalPath.st_mode & 0o7777 == 0o600
            && final.st_nlink == 1 && finalPath.st_nlink == 1
            && final.st_dev == created.st_dev && final.st_ino == created.st_ino
            && final.st_dev == finalPath.st_dev && final.st_ino == finalPath.st_ino) {
            postCommitChecksPassed = false
        }
        do {
            try validateDirectory(
                parent: directoryParent, descriptor: directory, name: opened.name
            )
        } catch {
            postCommitChecksPassed = false
        }
        return .committed(postCommitChecksPassed: postCommitChecksPassed)
    }

    private static func openParentDirectory(
        of url: URL
    ) throws -> (parent: Int32, directory: Int32, name: String) {
        let components = url.deletingLastPathComponent().path.split(separator: "/").map(String.init)
        guard !components.isEmpty,
              !components.contains(where: { $0 == "." || $0 == ".." }) else {
            throw LabF03CloseoutError.outputWriteFailed
        }
        var parent = open("/", O_RDONLY | O_DIRECTORY | O_CLOEXEC)
        guard parent >= 0 else { throw LabF03CloseoutError.outputWriteFailed }
        for (index, component) in components.enumerated() {
            let child = openat(
                parent, component, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
            )
            guard child >= 0 else {
                close(parent)
                throw LabF03CloseoutError.outputWriteFailed
            }
            if index == components.count - 1 { return (parent, child, component) }
            close(parent)
            parent = child
        }
        close(parent)
        throw LabF03CloseoutError.outputWriteFailed
    }

    private static func validateDirectory(
        parent: Int32,
        descriptor: Int32,
        name: String
    ) throws {
        var held = stat()
        var visible = stat()
        guard fstat(descriptor, &held) == 0,
              fstatat(parent, name, &visible, AT_SYMLINK_NOFOLLOW) == 0,
              held.st_mode & S_IFMT == S_IFDIR,
              visible.st_mode & S_IFMT == S_IFDIR,
              held.st_uid == getuid(), visible.st_uid == getuid(),
              held.st_mode & 0o7777 == 0o700,
              visible.st_mode & 0o7777 == 0o700,
              held.st_nlink > 0, visible.st_nlink > 0,
              held.st_dev == visible.st_dev, held.st_ino == visible.st_ino else {
            throw LabF03CloseoutError.outputWriteFailed
        }
    }
}
