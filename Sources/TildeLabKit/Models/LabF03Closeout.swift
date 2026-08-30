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
    case previewProcessesStillRunning
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
        case .previewProcessesStillRunning:
            "The exact Preview9B app, helper, and input-method processes must be stopped before closeout."
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
    public static let currentSchema = "tilde-lab.f03-closeout.v1"

    public let schema: String
    public let generatedAt: Date
    public let runID: UUID
    public let profile: String
    public let evidenceClass: String
    public let sourceState: String
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
    public let decisionGradeEligible: Bool
    public let blockers: [LabF03CloseoutBlocker]
    public let containsRawText: Bool
    public let containsLocalPaths: Bool
}

public struct LabF03RunReceipt: Equatable, Sendable {
    public static let currentSchema = "tilde.f03-local-run-receipt.v1"

    public let runID: UUID
    public let profile: TildeProductProfile
    public let evidenceClass: String
    public let sourceState: String
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
        for (name, value, length) in [
            ("sourceCommit", raw.sourceCommit, 40),
            ("sourceTree", raw.sourceTree, 40),
            ("sourceSnapshotSHA256", raw.sourceSnapshotSHA256, 64),
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
        guard raw.modelBytes > 0 else {
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
            sourcePackageIdentity: LabF03SourcePackageIdentity(
                sourceCommit: raw.sourceCommit,
                sourceTree: raw.sourceTree,
                sourceSnapshotSHA256: raw.sourceSnapshotSHA256,
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

    public static func capture(
        receiptURL: URL,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        generatedAt: Date = Date(),
        preferencesProvider: PreferencesProvider = { UserDefaults(suiteName: $0) },
        stoppedProcessProvider: StoppedProcessProvider = exactPreviewProcessesAreStopped,
        installedIdentityProvider: InstalledIdentityProvider = installedIdentityMatches,
        outputURL: URL? = nil
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
        let maintenanceLock = try F03MaintenanceLock.acquireShared(
            supportDirectory: eventURL.deletingLastPathComponent().deletingLastPathComponent()
        )
        defer { withExtendedLifetime(maintenanceLock) {} }
        guard stoppedProcessProvider(processURLs) else {
            throw LabF03CloseoutError.previewProcessesStillRunning
        }
        let installedIdentityVerified = installedIdentityProvider(receipt, homeDirectory)
        let eventData = try LockedOwnerFile.read(
            eventURL,
            maximumBytes: 64 * 1_024 * 1_024,
            unsafeError: .unsafeEventFile,
            tooLargeError: .eventFileTooLarge
        )
        let suiteName = receipt.profile.inputMethodBundleIdentifier
        guard let defaults = preferencesProvider(suiteName) else {
            throw LabF03CloseoutError.preferencesUnavailable
        }
        guard let currentGeneration = defaults.object(
            forKey: PersonalHistorySettingsContract.outcomeLedgerGenerationKey
        ) as? Int else {
            throw LabF03CloseoutError.invalidWriteAccounting
        }
        let countsKey = PersonalHistorySettingsContract.outcomeLedgerWriteCountsKey(
            receipt.outcomeLedgerGeneration
        )
        let dictionary = defaults.dictionary(forKey: countsKey) ?? [:]
        let allowedCountKeys: Set<String> = [
            "attempted", "written", "dropped", "flushedAttempted", "flushedWritten",
            "flushedDropped", "flushedAtMilliseconds",
        ]
        guard Set(dictionary.keys).isSubset(of: allowedCountKeys),
              let attempted = count(dictionary["attempted"], default: 0),
              let written = count(dictionary["written"], default: 0),
              let dropped = count(dictionary["dropped"], default: 0) else {
            throw LabF03CloseoutError.invalidWriteAccounting
        }
        let acknowledgement = flushAcknowledgement(dictionary)
        guard stoppedProcessProvider(processURLs) else {
            throw LabF03CloseoutError.previewProcessesStillRunning
        }
        let report = try analyze(
            receiptData: receiptData,
            eventData: eventData,
            currentGeneration: currentGeneration,
            writeAccounting: LabF03WriteAccounting(
                attempted: attempted, written: written, dropped: dropped
            ),
            flushAcknowledgement: acknowledgement,
            previewProcessesStopped: true,
            installedIdentityVerified: installedIdentityVerified,
            generatedAt: generatedAt
        )
        if let outputURL { try writeNew(report, to: outputURL) }
        return report
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
        return LabF03CloseoutReport(
            schema: LabF03CloseoutReport.currentSchema,
            generatedAt: generatedAt,
            runID: receipt.runID,
            profile: receipt.profile.rawValue,
            evidenceClass: receipt.evidenceClass,
            sourceState: receipt.sourceState,
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
            decisionGradeEligible: blockers.isEmpty,
            blockers: blockers,
            containsRawText: false,
            containsLocalPaths: false
        )
    }

    public static func writeNew(_ report: LabF03CloseoutReport, to output: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try NewOwnerFile.write(try encoder.encode(report), to: output)
    }

    private static func count(_ value: Any?, default fallback: Int? = nil) -> Int? {
        guard let value else { return fallback }
        guard let count = value as? Int, count >= 0 else { return nil }
        return count
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

    public static func exactPreviewProcessesAreStopped(_ executables: [URL]) -> Bool {
        executables.allSatisfy { executable in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
            process.arguments = ["-nP", "-a", "-d", "txt", "-t", "--", executable.path]
            let output = Pipe()
            let errors = Pipe()
            process.standardOutput = output
            process.standardError = errors
            do {
                try process.run()
                process.waitUntilExit()
                let bytes = output.fileHandleForReading.readDataToEndOfFile()
                let errorBytes = errors.fileHandleForReading.readDataToEndOfFile()
                if process.terminationStatus == 1, errorBytes.isEmpty { return true }
                return process.terminationStatus == 0 && bytes.isEmpty && errorBytes.isEmpty
            } catch {
                return false
            }
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
              verifiedFileDigest(appPlist, maximumBytes: 16 * 1_024 * 1_024)
                == identity.installedAppInfoPlistSHA256,
              verifiedFileDigest(inputMethodPlist, maximumBytes: 16 * 1_024 * 1_024)
                == identity.installedIMEInfoPlistSHA256,
              verifiedFileDigest(
                model,
                expectedBytes: identity.modelBytes,
                maximumBytes: identity.modelBytes,
                requiredMode: 0o600
              ) == identity.modelSHA256 else { return false }
        return true
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

    static func verifiedFileDigest(
        _ url: URL,
        expectedBytes: Int64? = nil,
        maximumBytes: Int64,
        requiredMode: mode_t? = nil
    ) -> String? {
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
            hasher.update(data: Data(buffer.prefix(count)))
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
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
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
    private let directoryDescriptor: Int32
    private let descriptor: Int32

    private init(directoryDescriptor: Int32, descriptor: Int32) {
        self.directoryDescriptor = directoryDescriptor
        self.descriptor = descriptor
    }

    deinit {
        close(descriptor)
        close(directoryDescriptor)
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
        let safeDirectory = fstat(directory, &directoryInfo) == 0
            && fstatat(
                parent, components.last!, &pathDirectoryInfo, AT_SYMLINK_NOFOLLOW
            ) == 0
            && directoryInfo.st_mode & S_IFMT == S_IFDIR
            && directoryInfo.st_uid == getuid()
            && directoryInfo.st_mode & 0o7777 == 0o700
            && directoryInfo.st_dev == pathDirectoryInfo.st_dev
            && directoryInfo.st_ino == pathDirectoryInfo.st_ino
        close(parent)
        guard safeDirectory else {
            close(directory)
            throw LabF03CloseoutError.unsafeMaintenanceLock
        }

        let descriptor = openat(
            directory, ".f03-maintenance.lock",
            O_RDWR | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC
        )
        guard descriptor >= 0 else {
            close(directory)
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
            throw LabF03CloseoutError.unsafeMaintenanceLock
        }
        guard flock(descriptor, LOCK_SH | LOCK_NB) == 0 else {
            let lockError = errno
            close(descriptor)
            close(directory)
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
            throw LabF03CloseoutError.unsafeMaintenanceLock
        }
        return F03MaintenanceLock(
            directoryDescriptor: directory, descriptor: descriptor
        )
    }
}

private enum LockedOwnerFile {
    static func read(
        _ url: URL,
        maximumBytes: Int,
        unsafeError: LabF03CloseoutError,
        tooLargeError: LabF03CloseoutError
    ) throws -> Data {
        guard url.isFileURL, url.path.hasPrefix("/"), !url.lastPathComponent.isEmpty else {
            throw unsafeError
        }
        let parentURL = url.deletingLastPathComponent()
        var directory = open("/", O_RDONLY | O_DIRECTORY | O_CLOEXEC)
        guard directory >= 0 else { throw unsafeError }
        for component in parentURL.path.split(separator: "/") {
            let next = openat(
                directory, String(component), O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
            )
            close(directory)
            guard next >= 0 else { throw unsafeError }
            directory = next
        }
        defer { close(directory) }
        var directoryInfo = stat()
        guard fstat(directory, &directoryInfo) == 0,
              directoryInfo.st_mode & S_IFMT == S_IFDIR,
              directoryInfo.st_uid == getuid(),
              directoryInfo.st_mode & 0o7777 == 0o700,
              flock(directory, LOCK_SH) == 0 else { throw unsafeError }
        let descriptor = openat(
            directory, url.lastPathComponent,
            O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC
        )
        guard descriptor >= 0 else { throw unsafeError }
        defer { close(descriptor) }
        var before = stat()
        guard fstat(descriptor, &before) == 0,
              before.st_mode & S_IFMT == S_IFREG,
              before.st_uid == getuid(),
              before.st_mode & 0o7777 == 0o600,
              before.st_nlink == 1,
              before.st_size >= 0,
              before.st_size <= maximumBytes,
              flock(descriptor, LOCK_SH) == 0 else {
            if before.st_size > maximumBytes { throw tooLargeError }
            throw unsafeError
        }
        let flags = fcntl(descriptor, F_GETFL)
        guard flags >= 0, fcntl(descriptor, F_SETFL, flags & ~O_NONBLOCK) == 0 else {
            throw unsafeError
        }
        var result = Data()
        result.reserveCapacity(Int(before.st_size))
        var buffer = [UInt8](repeating: 0, count: 64 * 1_024)
        while true {
            let count = Darwin.read(descriptor, &buffer, buffer.count)
            if count == 0 { break }
            if count < 0 {
                if errno == EINTR { continue }
                throw unsafeError
            }
            guard result.count + count <= maximumBytes else { throw tooLargeError }
            result.append(contentsOf: buffer.prefix(count))
        }
        var after = stat()
        var pathInfo = stat()
        guard fstat(descriptor, &after) == 0,
              fstatat(directory, url.lastPathComponent, &pathInfo, AT_SYMLINK_NOFOLLOW) == 0,
              before.st_dev == after.st_dev, before.st_ino == after.st_ino,
              before.st_size == after.st_size,
              before.st_mtimespec.tv_sec == after.st_mtimespec.tv_sec,
              before.st_mtimespec.tv_nsec == after.st_mtimespec.tv_nsec,
              after.st_dev == pathInfo.st_dev, after.st_ino == pathInfo.st_ino,
              after.st_nlink == 1, result.count == Int(after.st_size) else {
            throw unsafeError
        }
        return result
    }
}

private enum NewOwnerFile {
    static func write(_ data: Data, to url: URL) throws {
        guard url.isFileURL, url.path.hasPrefix("/"), !url.lastPathComponent.isEmpty else {
            throw LabF03CloseoutError.outputWriteFailed
        }
        let directory = open(
            url.deletingLastPathComponent().path, O_RDONLY | O_DIRECTORY | O_CLOEXEC
        )
        guard directory >= 0 else { throw LabF03CloseoutError.outputWriteFailed }
        let descriptor = openat(
            directory, url.lastPathComponent,
            O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600
        )
        if descriptor < 0 {
            let openError = errno
            close(directory)
            if openError == EEXIST { throw LabF03CloseoutError.outputExists }
            throw LabF03CloseoutError.outputWriteFailed
        }
        var createdIdentity: (device: dev_t, inode: ino_t)?
        var succeeded = false
        defer {
            if !succeeded, let createdIdentity {
                var pathInfo = stat()
                if fstatat(
                    directory, url.lastPathComponent, &pathInfo, AT_SYMLINK_NOFOLLOW
                ) == 0,
                   pathInfo.st_dev == createdIdentity.device,
                   pathInfo.st_ino == createdIdentity.inode {
                    _ = unlinkat(directory, url.lastPathComponent, 0)
                    _ = fsync(directory)
                }
            }
            close(descriptor)
            close(directory)
        }
        var created = stat()
        guard fstat(descriptor, &created) == 0,
              created.st_mode & S_IFMT == S_IFREG,
              created.st_uid == getuid(), created.st_nlink == 1 else {
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
        var final = stat()
        var pathInfo = stat()
        guard wroteAll, fchmod(descriptor, 0o600) == 0,
              fstat(descriptor, &final) == 0,
              fstatat(
                directory, url.lastPathComponent, &pathInfo, AT_SYMLINK_NOFOLLOW
              ) == 0,
              final.st_mode & S_IFMT == S_IFREG, final.st_uid == getuid(),
              final.st_mode & 0o7777 == 0o600, final.st_nlink == 1,
              final.st_dev == created.st_dev, final.st_ino == created.st_ino,
              final.st_dev == pathInfo.st_dev, final.st_ino == pathInfo.st_ino,
              fsync(descriptor) == 0, fsync(directory) == 0 else {
            throw LabF03CloseoutError.outputWriteFailed
        }
        succeeded = true
    }
}
