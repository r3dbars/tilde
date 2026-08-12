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
    func append(_ events: [PersonalHistoryEvent]) async throws
    func loadReplay(maximumBytes: Int64) async throws -> PersonalHistoryReplay
    func deleteAll() async throws
    func summary() async throws -> PersonalHistorySummary
}

struct PersonalHistoryReplay: Equatable, Sendable {
    let events: [PersonalHistoryEvent]
}

extension PersonalHistoryStore {
    func loadEvents() async throws -> [PersonalHistoryEvent] {
        try await loadReplay(maximumBytes: .max).events
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
    private let service = "bar.r3d.tilde.personal-history"
    private let account = "aes-gcm-key-v1"

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
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
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

    private func baseQuery() -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecUseDataProtectionKeychain: true,
            kSecAttrSynchronizable: false,
        ]
    }
}

/// A versioned append-only log. Each event is independently authenticated and
/// encrypted with AES-GCM; only the format header and approximate file size are
/// visible without the device-only Keychain key.
final class EncryptedPersonalHistoryStore: PersonalHistoryStore, @unchecked Sendable {
    private static let header = Data("TILDE-PERSONAL-HISTORY\t1\n".utf8)
    private static let authenticatedData = Data("bar.r3d.tilde.personal-history.v1".utf8)

    let location: URL
    private let keyProvider: any PersonalHistoryKeyProviding
    private let queue = DispatchQueue(label: "bar.r3d.tilde.personal-history-store", qos: .utility)

    init(
        location: URL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Tilde/Personal History/history.v1.enc"),
        keyProvider: any PersonalHistoryKeyProviding = KeychainPersonalHistoryKeyProvider()
    ) {
        self.location = location
        self.keyProvider = keyProvider
    }

    func append(_ events: [PersonalHistoryEvent]) async throws {
        guard PersonalHistoryEvent.validBatch(events) else {
            throw PersonalHistoryStorageError.invalidEvent
        }
        try await perform { try self.appendSynchronously(events) }
    }

    func loadReplay(maximumBytes: Int64) async throws -> PersonalHistoryReplay {
        try await perform { try self.loadSynchronously(maximumBytes: maximumBytes) }
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
            try self.validateHeaderAndTail(handle: handle, size: size)
            return PersonalHistorySummary(
                location: self.location,
                approximateBytes: Int64(size)
            )
        }
    }

    private func appendSynchronously(_ events: [PersonalHistoryEvent]) throws {
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
        let size = try handle.seekToEnd()
        if size > 0 { try validateHeaderAndTail(handle: handle, size: size) }
        let keyData: Data
        if let newStoreKey {
            keyData = newStoreKey
        } else if size > UInt64(Self.header.count) {
            keyData = try keyProvider.loadExistingKey()
        } else {
            keyData = try keyProvider.loadOrCreateKey()
        }
        guard keyData.count == 32 else { throw PersonalHistoryStorageError.invalidKey }
        if size > UInt64(Self.header.count) {
            try authenticateLastRecord(handle: handle, size: size, keyData: keyData)
        }
        let key = SymmetricKey(data: keyData)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        var encryptedLines = Data()
        for event in events {
            let plaintext = try encoder.encode(event)
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
        }
        if size == 0 { try handle.write(contentsOf: Self.header) }
        _ = try handle.seekToEnd()
        try handle.write(contentsOf: encryptedLines)
    }

    private func authenticateLastRecord(
        handle: FileHandle,
        size: UInt64,
        keyData: Data
    ) throws {
        let bodyStart = UInt64(Self.header.count)
        let window = min(size - bodyStart, 16 * 1_024)
        try handle.seek(toOffset: size - window)
        let tail = try handle.read(upToCount: Int(window)) ?? Data()
        let lines = tail.split(separator: 0x0A)
        guard let last = lines.last else { throw PersonalHistoryStorageError.corruptStore }
        _ = try Self.decode(Data(last) + Data([0x0A]), keyData: keyData)
    }

    /// Reads only a bounded recent tail. The encrypted corpus remains complete
    /// while replay work stays flat as Personal History grows.
    private func loadSynchronously(maximumBytes: Int64) throws -> PersonalHistoryReplay {
        var info = stat()
        if lstat(location.path, &info) != 0 {
            guard errno == ENOENT else { throw CocoaError(.fileReadUnknown) }
            return PersonalHistoryReplay(events: [])
        }
        guard let handle = SecureLocalStorage.openExistingFileForReading(at: location) else {
            throw PersonalHistoryStorageError.corruptStore
        }
        defer { try? handle.close() }
        let size = try handle.seekToEnd()
        try validateHeaderAndTail(handle: handle, size: size)
        let bodyStart = UInt64(Self.header.count)
        guard size > bodyStart else {
            return PersonalHistoryReplay(events: [])
        }

        let keyData = try keyProvider.loadExistingKey()
        guard keyData.count == 32 else { throw PersonalHistoryStorageError.invalidKey }
        let bodySize = size - bodyStart
        let budget = maximumBytes == .max
            ? bodySize
            : UInt64(max(0, maximumBytes))
        guard budget > 0 else {
            return PersonalHistoryReplay(events: [])
        }
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
                return PersonalHistoryReplay(events: [])
            }
            body.removeSubrange(...newline)
        }
        return PersonalHistoryReplay(events: try Self.decode(body, keyData: keyData))
    }

    private static func decode(_ data: Data, keyData: Data) throws -> [PersonalHistoryEvent] {
        guard keyData.count == 32 else { throw PersonalHistoryStorageError.invalidKey }
        let key = SymmetricKey(data: keyData)
        let decoder = JSONDecoder()
        return try data.split(separator: 0x0A).map { line in
            guard let combined = Data(base64Encoded: Data(line)),
                  let box = try? AES.GCM.SealedBox(combined: combined),
                  let plaintext = try? AES.GCM.open(
                    box,
                    using: key,
                    authenticating: authenticatedData
                  ),
                  let event = try? decoder.decode(PersonalHistoryEvent.self, from: plaintext) else {
                throw PersonalHistoryStorageError.corruptStore
            }
            return event
        }
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
