import AutocompleteLabCore
import Foundation

/// Justin's explicitly opted-in research store. Raw events are intentionally
/// readable JSONL so local Codex research can inspect the complete corpus.
/// Owner-only permissions still prevent accidental access by other macOS users.
final class OpenResearchHistoryStore: PersonalHistoryStore, @unchecked Sendable {
    let location: URL
    private let operations: OpenResearchHistoryOperations

    init(
        plaintext: PlaintextPersonalHistoryStore = PlaintextPersonalHistoryStore(),
        encryptedLegacy: EncryptedPersonalHistoryStore = EncryptedPersonalHistoryStore()
    ) {
        location = plaintext.location
        operations = OpenResearchHistoryOperations(
            plaintext: plaintext,
            encryptedLegacy: encryptedLegacy
        )
    }

    func append(
        _ events: [PersonalHistoryEvent],
        checkpoint: PersonalNextWordStoredCheckpoint?
    ) async throws {
        try await operations.append(events, checkpoint: checkpoint)
    }

    func loadReplay(maximumBytes: Int64) async throws -> PersonalHistoryReplay {
        try await operations.loadReplay(maximumBytes: maximumBytes)
    }

    func deleteAll() async throws { try await operations.deleteAll() }

    func summary() async throws -> PersonalHistorySummary {
        try await operations.summary()
    }
}

private actor OpenResearchHistoryOperations {
    private struct EventIdentity: Hashable {
        let history: String
        let event: String
    }

    private let plaintext: PlaintextPersonalHistoryStore
    private let encryptedLegacy: EncryptedPersonalHistoryStore
    private var migration: Task<Void, Error>?

    init(
        plaintext: PlaintextPersonalHistoryStore,
        encryptedLegacy: EncryptedPersonalHistoryStore
    ) {
        self.plaintext = plaintext
        self.encryptedLegacy = encryptedLegacy
    }

    func append(
        _ events: [PersonalHistoryEvent],
        checkpoint: PersonalNextWordStoredCheckpoint?
    ) async throws {
        try await prepare()
        try await plaintext.append(events, checkpoint: checkpoint)
    }

    func loadReplay(maximumBytes: Int64) async throws -> PersonalHistoryReplay {
        try await prepare()
        return try await plaintext.loadReplay(maximumBytes: maximumBytes)
    }

    func summary() async throws -> PersonalHistorySummary {
        try await prepare()
        return try await plaintext.summary()
    }

    func deleteAll() async throws {
        try await prepare()
        try await plaintext.deleteAll()
        try await encryptedLegacy.deleteAll()
    }

    private func prepare() async throws {
        if let migration {
            return try await migration.value
        }
        let plaintext = plaintext
        let encryptedLegacy = encryptedLegacy
        let task = Task {
            let current = try await plaintext.loadReplay(maximumBytes: .max)
            let legacy = try await encryptedLegacy.loadReplay(maximumBytes: .max)
            var known = Set(current.events.map {
                EventIdentity(history: $0.historyIdentifier, event: $0.id)
            })
            let missing = legacy.events.filter {
                known.insert(EventIdentity(history: $0.historyIdentifier, event: $0.id)).inserted
            }
            var index = 0
            while index < missing.count {
                let remaining = Array(missing[index...])
                let batch = PersonalHistoryEvent.boundedBatchPrefix(remaining)
                guard !batch.isEmpty else { throw PersonalHistoryStorageError.invalidEvent }
                index += batch.count
                try await plaintext.append(
                    batch,
                    checkpoint: index == missing.count ? legacy.checkpoint : nil
                )
            }
            if missing.isEmpty, current.checkpoint == nil, let checkpoint = legacy.checkpoint {
                try await plaintext.appendCheckpointForMigration(checkpoint)
            }
            let migrated = try await plaintext.loadReplay(maximumBytes: .max)
            let migratedIDs = Set(migrated.events.map {
                EventIdentity(history: $0.historyIdentifier, event: $0.id)
            })
            guard legacy.events.allSatisfy({
                migratedIDs.contains(EventIdentity(history: $0.historyIdentifier, event: $0.id))
            }) else { throw PersonalHistoryStorageError.corruptStore }
            try await encryptedLegacy.deleteAll()
        }
        migration = task
        do {
            try await task.value
        } catch {
            migration = nil
            throw error
        }
    }
}

/// Plaintext JSONL is the canonical store for this research build. The first
/// line is a format header; every later line is one complete batch containing
/// raw events and, when present, the paired aggregate checkpoint.
final class PlaintextPersonalHistoryStore: PersonalHistoryStore, @unchecked Sendable {
    private static let header = Data("TILDE-OPEN-RESEARCH-HISTORY\t1\n".utf8)
    private static let maximumRecordBytes = 64 * 1_024

    let location: URL
    private let queue = DispatchQueue(
        label: "bar.r3d.tilde.open-research-history-store",
        qos: .utility
    )

    init(
        location: URL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Tilde/Open Research History/history.v1.jsonl")
    ) {
        self.location = location
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

    func appendCheckpointForMigration(
        _ checkpoint: PersonalNextWordStoredCheckpoint
    ) async throws {
        try await perform { try self.appendSynchronously([], checkpoint: checkpoint) }
    }

    func loadReplay(maximumBytes: Int64) async throws -> PersonalHistoryReplay {
        try await perform { try self.loadSynchronously(maximumBytes: maximumBytes) }
    }

    func loadLatestCheckpoint() throws -> PersonalNextWordStoredCheckpoint? {
        let handle: FileHandle
        switch SecureLocalStorage.openExistingOwnerOnlyFileForReadOnlyStatus(at: location) {
        case let .opened(opened): handle = opened
        case .missing: return nil
        case .rejected: throw PersonalHistoryStorageError.corruptStore
        }
        defer { try? handle.close() }
        let size = try handle.seekToEnd()
        try validateHeaderAndTail(handle: handle, size: size)
        guard size > UInt64(Self.header.count) else { return nil }
        return try Self.decodeRecord(lastRecord(handle: handle, size: size)).checkpoint
    }

    func deleteAll() async throws {
        try await perform {
            guard SecureLocalStorage.removeOwnerOnlyFile(at: self.location) else {
                throw CocoaError(.fileWriteUnknown)
            }
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
            try self.validateHeaderAndTail(handle: handle, size: size)
            return PersonalHistorySummary(location: self.location, approximateBytes: Int64(size))
        }
    }

    private func appendSynchronously(
        _ events: [PersonalHistoryEvent],
        checkpoint: PersonalNextWordStoredCheckpoint?
    ) throws {
        guard !events.isEmpty || checkpoint != nil else {
            throw PersonalHistoryStorageError.invalidEvent
        }
        guard let handle = SecureLocalStorage.openFileForReadingAndAppending(at: location) else {
            throw CocoaError(.fileWriteNoPermission)
        }
        defer { try? handle.close() }
        let size = try handle.seekToEnd()
        if size > 0 { try validateHeaderAndTail(handle: handle, size: size) }
        let carried = size > UInt64(Self.header.count)
            ? try Self.decodeRecord(lastRecord(handle: handle, size: size)).checkpoint
            : nil
        let record = StoredBatch(events: events, checkpoint: checkpoint ?? carried)
        guard record.isValid else { throw PersonalHistoryStorageError.invalidEvent }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        var line = try encoder.encode(record)
        line.append(0x0A)
        guard line.count <= Self.maximumRecordBytes else {
            throw PersonalHistoryStorageError.invalidEvent
        }
        do {
            if size == 0 {
                try handle.seek(toOffset: 0)
                try handle.write(contentsOf: Self.header)
            }
            _ = try handle.seekToEnd()
            try handle.write(contentsOf: line)
        } catch {
            try? handle.truncate(atOffset: size)
            throw error
        }
    }

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
        let size = try handle.seekToEnd()
        try validateHeaderAndTail(handle: handle, size: size)
        let bodyStart = UInt64(Self.header.count)
        guard size > bodyStart else {
            return PersonalHistoryReplay(events: [], checkpoint: nil)
        }
        let bodySize = size - bodyStart
        let budget = maximumBytes == .max ? bodySize : UInt64(max(0, maximumBytes))
        guard budget > 0 else { return PersonalHistoryReplay(events: [], checkpoint: nil) }
        let start = bodySize > budget ? size - budget : bodyStart
        var startsMidLine = false
        if start > bodyStart {
            try handle.seek(toOffset: start - 1)
            startsMidLine = try handle.read(upToCount: 1) != Data([0x0A])
        }
        try handle.seek(toOffset: start)
        var body = try handle.readToEnd() ?? Data()
        if startsMidLine {
            guard let newline = body.firstIndex(of: 0x0A) else {
                return PersonalHistoryReplay(events: [], checkpoint: nil)
            }
            body.removeSubrange(...newline)
        }
        return try Self.decode(body)
    }

    private static func decode(_ data: Data) throws -> PersonalHistoryReplay {
        var events: [PersonalHistoryEvent] = []
        var checkpoint: PersonalNextWordStoredCheckpoint?
        for line in data.split(separator: 0x0A) {
            guard line.count + 1 <= maximumRecordBytes else {
                throw PersonalHistoryStorageError.corruptStore
            }
            let record = try decodeRecord(Data(line))
            events.append(contentsOf: record.events)
            if let stored = record.checkpoint {
                checkpoint = stored.isCompatibleWithCurrentExperiment ? stored : nil
            }
        }
        return PersonalHistoryReplay(events: events, checkpoint: checkpoint)
    }

    private static func decodeRecord(_ data: Data) throws -> StoredBatch {
        guard let record = try? JSONDecoder().decode(StoredBatch.self, from: data),
              record.isValid else { throw PersonalHistoryStorageError.corruptStore }
        return record
    }

    private func lastRecord(handle: FileHandle, size: UInt64) throws -> Data {
        let bodyStart = UInt64(Self.header.count)
        let window = min(size - bodyStart, UInt64(Self.maximumRecordBytes))
        try handle.seek(toOffset: size - window)
        let tail = try handle.read(upToCount: Int(window)) ?? Data()
        let lines = tail.split(separator: 0x0A)
        guard let last = lines.last, last.count + 1 <= Self.maximumRecordBytes else {
            throw PersonalHistoryStorageError.corruptStore
        }
        return Data(last)
    }

    private func validateHeaderAndTail(handle: FileHandle, size: UInt64) throws {
        guard size >= UInt64(Self.header.count) else {
            throw PersonalHistoryStorageError.corruptStore
        }
        try handle.seek(toOffset: 0)
        guard try handle.read(upToCount: Self.header.count) == Self.header else {
            throw PersonalHistoryStorageError.corruptStore
        }
        try handle.seek(toOffset: size - 1)
        guard try handle.read(upToCount: 1) == Data([0x0A]) else {
            throw PersonalHistoryStorageError.corruptStore
        }
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
                && (events.isEmpty ? checkpoint != nil : PersonalHistoryEvent.validBatch(events))
                && (checkpoint?.hasValidEnvelope ?? true)
        }
    }

    private func perform<T: Sendable>(
        _ operation: @escaping @Sendable () throws -> T
    ) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do { continuation.resume(returning: try operation()) }
                catch { continuation.resume(throwing: error) }
            }
        }
    }
}
