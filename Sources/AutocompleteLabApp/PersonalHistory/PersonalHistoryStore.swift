import AutocompleteLabCore
import CryptoKit
import Foundation
import Security

struct PersonalHistorySummary: Equatable, Sendable {
    let location: URL
    let approximateBytes: Int64
}

protocol PersonalHistoryStore: Sendable {
    var location: URL { get }
    func append(
        _ events: [PersonalHistoryEvent],
        checkpoint: PersonalNextWordStoredCheckpoint?
    ) async throws
    func loadReplay(maximumBytes: Int64) async throws -> PersonalHistoryReplay
    func deleteAll() async throws
    func summary() async throws -> PersonalHistorySummary
}

struct PersonalHistoryReplay: Equatable, Sendable {
    let events: [PersonalHistoryEvent]
    let checkpoint: PersonalNextWordStoredCheckpoint?
}

extension PersonalHistoryStore {
    func append(_ events: [PersonalHistoryEvent]) async throws {
        try await append(events, checkpoint: nil)
    }

    func loadEvents() async throws -> [PersonalHistoryEvent] {
        try await loadReplay(maximumBytes: .max).events
    }
}

struct PersonalNextWordStoredCheckpoint: Codable, Equatable, Sendable {
    private static let version = 1

    let v: Int
    let historyIdentifier: String
    let experimentIdentifier: String
    let excludedApps: [String]
    let checkpoint: PersonalNextWordShadowCheckpoint

    init(
        historyIdentifier: String,
        experimentIdentifier: String,
        excludedApps: Set<String>,
        checkpoint: PersonalNextWordShadowCheckpoint
    ) {
        v = Self.version
        self.historyIdentifier = historyIdentifier
        self.experimentIdentifier = experimentIdentifier
        self.excludedApps = PersonalHistoryCapturePolicy.normalizedExcludedApps(excludedApps)
        self.checkpoint = checkpoint
    }

    func matches(
        historyIdentifier: String,
        experimentIdentifier: String,
        excludedApps: Set<String>
    ) -> Bool {
        v == Self.version
            && self.historyIdentifier == historyIdentifier
            && self.experimentIdentifier == experimentIdentifier
            && self.excludedApps == PersonalHistoryCapturePolicy.normalizedExcludedApps(excludedApps)
    }

    fileprivate var hasValidEnvelope: Bool {
        v > 0
            && PersonalHistoryEvent.validIdentifier(historyIdentifier)
            && PersonalHistoryEvent.validIdentifier(experimentIdentifier)
            && excludedApps == PersonalHistoryCapturePolicy.normalizedExcludedApps(excludedApps)
    }

    var isCompatibleWithCurrentExperiment: Bool {
        v == Self.version && checkpoint.isCompatibleWithCurrentExperiment
    }
}

protocol PersonalHistoryKeyProviding: Sendable {
    func loadExistingKey() throws -> Data
    func loadOrCreateKey() throws -> Data
    func deleteKey() throws
}

enum PersonalHistoryStorageError: Error, Equatable {
    case corruptStore
    case invalidEvent
    case invalidKey
    case missingKey
    case keychain(OSStatus)
}

final class KeychainPersonalHistoryKeyProvider: PersonalHistoryKeyProviding, @unchecked Sendable {
    static let service = "bar.r3d.tilde.personal-history"
    static let account = "aes-gcm-key-v1"
    private let serviceName: String

    init(serviceName: String = TildeProductProfile.current.personalHistoryKeychainService) {
        self.serviceName = serviceName
    }

    func loadExistingKey() throws -> Data {
        guard let key = try lookupKey() else {
            throw PersonalHistoryStorageError.missingKey
        }
        return key
    }

    func loadOrCreateKey() throws -> Data {
        if let key = try lookupKey() { return key }

        var key = Data(count: 32)
        let randomStatus = key.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, $0.count, $0.baseAddress!)
        }
        guard randomStatus == errSecSuccess else {
            throw PersonalHistoryStorageError.keychain(randomStatus)
        }

        let add = baseQuery().merging([
            kSecValueData: key,
        ]) { _, new in new }
        let addStatus = SecItemAdd(add as CFDictionary, nil)
        if addStatus == errSecDuplicateItem { return try loadExistingKey() }
        guard addStatus == errSecSuccess else {
            throw PersonalHistoryStorageError.keychain(addStatus)
        }
        return key
    }

    private func lookupKey() throws -> Data? {
        let query = baseQuery().merging([
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]) { _, new in new }
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess {
            guard let data = result as? Data, data.count == 32 else {
                throw PersonalHistoryStorageError.invalidKey
            }
            return data
        }
        if status == errSecItemNotFound { return nil }
        throw PersonalHistoryStorageError.keychain(status)
    }

    func deleteKey() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw PersonalHistoryStorageError.keychain(status)
        }
    }

    static func baseQuery(service: String = service) -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrSynchronizable: false,
        ]
    }

    private func baseQuery() -> [CFString: Any] { Self.baseQuery(service: serviceName) }
}

/// A versioned append-only log. Each event is independently authenticated and
/// encrypted with AES-GCM; only the format header and approximate file size are
/// visible without the non-synchronizing macOS Keychain key.
final class EncryptedPersonalHistoryStore: PersonalHistoryStore, @unchecked Sendable {
    private static let legacyHeader = Data("TILDE-PERSONAL-HISTORY\t1\n".utf8)
    private static let header = Data("TILDE-PERSONAL-HISTORY\t2\n".utf8)
    private static var authenticatedData: Data {
        TildeProductProfile.current.personalHistoryAuthenticatedData
    }
    private static let maximumEncryptedRecordBytes = 64 * 1_024

    let location: URL
    private let keyProvider: any PersonalHistoryKeyProviding
    private let diagnostics: DiagnosticsLog
    private let queue = DispatchQueue(label: "bar.r3d.tilde.personal-history-store", qos: .utility)

    init(
        location: URL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(TildeProductProfile.current.supportDirectoryName)
            .appendingPathComponent("Personal History/history.v1.enc"),
        keyProvider: any PersonalHistoryKeyProviding = KeychainPersonalHistoryKeyProvider(),
        diagnostics: DiagnosticsLog = .shared
    ) {
        self.location = location
        self.keyProvider = keyProvider
        self.diagnostics = diagnostics
    }

    func append(
        _ events: [PersonalHistoryEvent],
        checkpoint: PersonalNextWordStoredCheckpoint?
    ) async throws {
        guard PersonalHistoryEvent.validBatch(events) else {
            throw PersonalHistoryStorageError.invalidEvent
        }
        try await perform { try self.appendSynchronously(events, checkpoint: checkpoint) }
    }

    func loadReplay(maximumBytes: Int64) async throws -> PersonalHistoryReplay {
        try await perform { try self.loadSynchronously(maximumBytes: maximumBytes) }
    }

    /// Status reads authenticate only the newest record and decode only its
    /// aggregate checkpoint. They never replay or return the record's events.
    func loadLatestCheckpoint() throws -> PersonalNextWordStoredCheckpoint? {
        let handle: FileHandle
        switch SecureLocalStorage.openExistingOwnerOnlyFileForReadOnlyStatus(at: location) {
        case let .opened(opened): handle = opened
        case .missing: return nil
        case .rejected:
            throw PersonalHistoryStorageError.corruptStore
        }
        defer { try? handle.close() }
        let size = try handle.seekToEnd()
        let effectiveSize: UInt64
        let legacyFormat: Bool
        switch try validateHeaderAndTail(handle: handle, size: size) {
        case let .clean(legacy):
            effectiveSize = size
            legacyFormat = legacy
        case let .torn(validPrefixLength):
            effectiveSize = validPrefixLength
            legacyFormat = false
        }
        let bodyStart = UInt64(Self.header.count)
        guard effectiveSize > bodyStart else { return nil }
        guard !legacyFormat else { return nil }
        let keyData = try keyProvider.loadExistingKey()
        guard keyData.count == 32 else { throw PersonalHistoryStorageError.invalidKey }
        let plaintext = try decryptLastRecord(handle: handle, size: effectiveSize, keyData: keyData)
        guard let record = try? JSONDecoder().decode(
            StoredCheckpointRecord.self, from: plaintext
        ) else {
            throw PersonalHistoryStorageError.corruptStore
        }
        guard record.isValid else { throw PersonalHistoryStorageError.corruptStore }
        return record.checkpoint
    }

    func deleteAll() async throws {
        try await perform {
            let removedFile = SecureLocalStorage.removeOwnerOnlyFile(at: self.location)
            guard removedFile else { throw CocoaError(.fileWriteUnknown) }
            try self.keyProvider.deleteKey()
        }
    }

    func summary() async throws -> PersonalHistorySummary {
        try await perform {
            var info = stat()
            if lstat(self.location.path, &info) != 0 {
                guard errno == ENOENT else { throw CocoaError(.fileReadUnknown) }
                return PersonalHistorySummary(location: self.location, approximateBytes: 0)
            }
            guard let handle = SecureLocalStorage.openExistingFileForReading(at: self.location) else {
                throw PersonalHistoryStorageError.corruptStore
            }
            defer { try? handle.close() }
            let size = try handle.seekToEnd()
            _ = try self.validateHeaderAndTail(handle: handle, size: size)
            // The reported size stays the raw on-disk byte count even when
            // the tail is torn (see `TailStatus.torn`) — this is a storage
            // usage number, not a claim about how many records replay.
            return PersonalHistorySummary(
                location: self.location,
                approximateBytes: Int64(size)
            )
        }
    }

    private func appendSynchronously(
        _ events: [PersonalHistoryEvent],
        checkpoint: PersonalNextWordStoredCheckpoint?
    ) throws {
        var info = stat()
        let exists = lstat(location.path, &info) == 0
        if !exists, errno != ENOENT { throw CocoaError(.fileReadUnknown) }
        let newStoreKey = exists ? nil : try keyProvider.loadOrCreateKey()
        if let newStoreKey, newStoreKey.count != 32 {
            throw PersonalHistoryStorageError.invalidKey
        }
        guard let handle = SecureLocalStorage.openFileForReadingAndAppending(at: location) else {
            throw CocoaError(.fileWriteNoPermission)
        }
        defer { try? handle.close() }
        var size = try handle.seekToEnd()
        var legacyFormat = false
        if size > 0 {
            switch try validateHeaderAndTail(handle: handle, size: size) {
            case let .clean(legacy):
                legacyFormat = legacy
            case let .torn(validPrefixLength):
                // A prior write never finished (process killed or crashed
                // mid-append) — the header and every record up through
                // `validPrefixLength` are intact and authenticate fine;
                // only the incomplete trailing partial line needs to go.
                // Recover by dropping just that tail instead of treating
                // the whole corpus as unreadable, and say so once so the
                // event is legible instead of silently masquerading as an
                // ordinary append.
                try handle.truncate(atOffset: validPrefixLength)
                size = validPrefixLength
                diagnostics.record("personal-history-store-repaired")
            }
        }
        let keyData: Data
        if let newStoreKey {
            keyData = newStoreKey
        } else if size > UInt64(Self.header.count) {
            keyData = try keyProvider.loadExistingKey()
        } else {
            keyData = try keyProvider.loadOrCreateKey()
        }
        guard keyData.count == 32 else { throw PersonalHistoryStorageError.invalidKey }
        let carriedCheckpoint = size > UInt64(Self.header.count)
            ? try authenticateLastRecord(handle: handle, size: size, keyData: keyData)
            : nil
        let checkpointToWrite = checkpoint ?? carriedCheckpoint
        let key = SymmetricKey(data: keyData)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        var encryptedLines = Data()
        let plaintext = try encoder.encode(
            StoredBatch(events: events, checkpoint: checkpointToWrite)
        )
        let sealed = try AES.GCM.seal(
            plaintext,
            using: key,
            authenticating: Self.authenticatedData
        )
        guard let combined = sealed.combined else {
            throw PersonalHistoryStorageError.corruptStore
        }
        encryptedLines.append(combined.base64EncodedData())
        encryptedLines.append(0x0A)
        guard encryptedLines.count <= Self.maximumEncryptedRecordBytes else {
            throw PersonalHistoryStorageError.invalidEvent
        }
        do {
            if size == 0 || legacyFormat {
                try handle.seek(toOffset: 0)
                try handle.write(contentsOf: Self.header)
            }
            _ = try handle.seekToEnd()
            try handle.write(contentsOf: encryptedLines)
        } catch {
            try? handle.truncate(atOffset: size)
            throw error
        }
    }

    private func authenticateLastRecord(
        handle: FileHandle,
        size: UInt64,
        keyData: Data
    ) throws -> PersonalNextWordStoredCheckpoint? {
        let line = try encryptedLine(handle: handle, size: size)
        return try Self.decode(line + Data([0x0A]), keyData: keyData).checkpoint
    }

    private func decryptLastRecord(
        handle: FileHandle,
        size: UInt64,
        keyData: Data
    ) throws -> Data {
        let line = try encryptedLine(handle: handle, size: size)
        guard let combined = Data(base64Encoded: line),
              let box = try? AES.GCM.SealedBox(combined: combined),
              let plaintext = try? AES.GCM.open(
                box,
                using: SymmetricKey(data: keyData),
                authenticating: Self.authenticatedData
              ) else {
            throw PersonalHistoryStorageError.corruptStore
        }
        return plaintext
    }

    private func encryptedLine(handle: FileHandle, size: UInt64) throws -> Data {
        let bodyStart = UInt64(Self.header.count)
        let window = min(size - bodyStart, UInt64(Self.maximumEncryptedRecordBytes))
        try handle.seek(toOffset: size - window)
        let tail = try handle.read(upToCount: Int(window)) ?? Data()
        let lines = tail.split(separator: 0x0A)
        guard let last = lines.last,
              last.count + 1 <= Self.maximumEncryptedRecordBytes else {
            throw PersonalHistoryStorageError.corruptStore
        }
        return Data(last)
    }

    /// Reads only a bounded recent tail. The encrypted corpus remains complete
    /// while replay work stays flat as Personal History grows.
    private func loadSynchronously(maximumBytes: Int64) throws -> PersonalHistoryReplay {
        var info = stat()
        if lstat(location.path, &info) != 0 {
            guard errno == ENOENT else { throw CocoaError(.fileReadUnknown) }
            return PersonalHistoryReplay(events: [], checkpoint: nil)
        }
        guard let handle = SecureLocalStorage.openExistingFileForReading(at: location) else {
            throw PersonalHistoryStorageError.corruptStore
        }
        defer { try? handle.close() }
        let rawSize = try handle.seekToEnd()
        let size: UInt64
        switch try validateHeaderAndTail(handle: handle, size: rawSize) {
        case .clean: size = rawSize
        case let .torn(validPrefixLength): size = validPrefixLength
        }
        let bodyStart = UInt64(Self.header.count)
        guard size > bodyStart else {
            return PersonalHistoryReplay(events: [], checkpoint: nil)
        }

        let keyData = try keyProvider.loadExistingKey()
        guard keyData.count == 32 else { throw PersonalHistoryStorageError.invalidKey }
        let bodySize = size - bodyStart
        let budget = maximumBytes == .max
            ? bodySize
            : UInt64(max(0, maximumBytes))
        guard budget > 0 else {
            return PersonalHistoryReplay(events: [], checkpoint: nil)
        }
        let start = bodySize > budget ? size - budget : bodyStart
        var startsMidLine = false
        if start > bodyStart {
            try handle.seek(toOffset: start - 1)
            startsMidLine = try handle.read(upToCount: 1) != Data([0x0A])
        }
        try handle.seek(toOffset: start)
        // Bounded to `size`, not simply "the rest of the file": when the
        // tail is torn (see `TailStatus.torn`), `size` already stops short
        // of the raw end-of-file, and reading past it would hand the
        // incomplete trailing partial line to `decode` as if it were a
        // record.
        var body = try handle.read(upToCount: Int(size - start)) ?? Data()
        if startsMidLine {
            guard let newline = body.firstIndex(of: 0x0A) else {
                return PersonalHistoryReplay(events: [], checkpoint: nil)
            }
            body.removeSubrange(...newline)
        }
        return try Self.decode(body, keyData: keyData)
    }

    private static func decode(_ data: Data, keyData: Data) throws -> PersonalHistoryReplay {
        guard keyData.count == 32 else { throw PersonalHistoryStorageError.invalidKey }
        let key = SymmetricKey(data: keyData)
        let decoder = JSONDecoder()
        var events: [PersonalHistoryEvent] = []
        var checkpoint: PersonalNextWordStoredCheckpoint?
        for line in data.split(separator: 0x0A) {
            guard line.count + 1 <= maximumEncryptedRecordBytes,
                  let combined = Data(base64Encoded: Data(line)),
                  let box = try? AES.GCM.SealedBox(combined: combined),
                  let plaintext = try? AES.GCM.open(
                    box,
                    using: key,
                    authenticating: authenticatedData
                  ) else {
                throw PersonalHistoryStorageError.corruptStore
            }
            if let batch = try? decoder.decode(StoredBatch.self, from: plaintext),
               batch.isValid {
                events.append(contentsOf: batch.events)
                if let stored = batch.checkpoint {
                    checkpoint = stored.isCompatibleWithCurrentExperiment ? stored : nil
                }
            } else if let legacy = try? decoder.decode(PersonalHistoryEvent.self, from: plaintext) {
                events.append(legacy)
            } else {
                throw PersonalHistoryStorageError.corruptStore
            }
        }
        return PersonalHistoryReplay(events: events, checkpoint: checkpoint)
    }

    private struct StoredBatch: Codable {
        let v: Int
        let events: [PersonalHistoryEvent]
        let checkpoint: PersonalNextWordStoredCheckpoint?

        init(events: [PersonalHistoryEvent], checkpoint: PersonalNextWordStoredCheckpoint?) {
            v = 1
            self.events = events
            self.checkpoint = checkpoint
        }

        var isValid: Bool {
            v == 1
                && PersonalHistoryEvent.validBatch(events)
                && (checkpoint?.hasValidEnvelope ?? true)
        }
    }

    private struct StoredCheckpointRecord: Decodable {
        let v: Int
        let checkpoint: PersonalNextWordStoredCheckpoint?

        private enum CodingKeys: String, CodingKey {
            case v, events, checkpoint
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            v = try container.decode(Int.self, forKey: .v)
            guard container.contains(.events) else {
                throw PersonalHistoryStorageError.corruptStore
            }
            _ = try container.superDecoder(forKey: .events).unkeyedContainer()
            checkpoint = try container.decodeIfPresent(
                PersonalNextWordStoredCheckpoint.self,
                forKey: .checkpoint
            )
        }

        var isValid: Bool {
            v == 1 && (checkpoint?.hasValidEnvelope ?? true)
        }
    }

    /// `.clean(legacyFormat:)` when the file is a well-formed sequence of
    /// newline-terminated records (`legacyFormat` true when the same-length
    /// v1 header should be upgraded before append). `.torn` when the header
    /// is fine and every record up to `validPrefixLength` is too, but the
    /// final line has no trailing newline — the signature of a write that
    /// never finished (the process was killed or crashed mid-append) rather
    /// than genuine corruption. Anything else still fails closed.
    private enum TailStatus {
        case clean(legacyFormat: Bool)
        case torn(validPrefixLength: UInt64)
    }

    private func validateHeaderAndTail(handle: FileHandle, size: UInt64) throws -> TailStatus {
        guard size >= UInt64(Self.header.count) else {
            throw PersonalHistoryStorageError.corruptStore
        }
        try handle.seek(toOffset: 0)
        let header = try handle.read(upToCount: Self.header.count)
        guard header == Self.header || header == Self.legacyHeader else {
            throw PersonalHistoryStorageError.corruptStore
        }
        try handle.seek(toOffset: size - 1)
        guard try handle.read(upToCount: 1) == Data([0x0A]) else {
            guard let validPrefixLength = try lastCompleteRecordBoundary(handle: handle, size: size) else {
                throw PersonalHistoryStorageError.corruptStore
            }
            return .torn(validPrefixLength: validPrefixLength)
        }
        return .clean(legacyFormat: header == Self.legacyHeader)
    }

    /// Scans backward from `size` for the newline that ends the last
    /// complete record, bounded to twice the maximum single-record size —
    /// enough to always find it when exactly one trailing record was torn
    /// (the only case a normal interrupted write can produce, since every
    /// completed record is capped at `maximumEncryptedRecordBytes`).
    /// Returns `nil` — leaving the caller to fail closed — when no boundary
    /// turns up in that window, since that means more than a single trailing
    /// record is implicated and this is no longer safely attributable to an
    /// ordinary torn write.
    private func lastCompleteRecordBoundary(handle: FileHandle, size: UInt64) throws -> UInt64? {
        let bodyStart = UInt64(Self.header.count)
        guard size > bodyStart else { return nil }
        let scanCap = UInt64(Self.maximumEncryptedRecordBytes) * 2
        let scanStart = size - bodyStart > scanCap ? size - scanCap : bodyStart
        try handle.seek(toOffset: scanStart)
        let window = try handle.read(upToCount: Int(size - scanStart)) ?? Data()
        guard let lastNewlineOffset = window.lastIndex(of: 0x0A) else {
            // No newline anywhere in the scanned window. If the window
            // reached all the way back to the first byte of the body, the
            // very first record ever written was the one interrupted —
            // recovering to an empty (header-only) body is still safe.
            // Otherwise this is more than one record's worth of unbroken
            // bytes, which a torn write cannot produce; don't guess.
            return scanStart == bodyStart ? bodyStart : nil
        }
        return scanStart + UInt64(lastNewlineOffset) + 1
    }

    private func perform<T: Sendable>(
        _ operation: @escaping @Sendable () throws -> T
    ) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    continuation.resume(returning: try operation())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
