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
    func loadEvents() async throws -> [PersonalHistoryEvent]
    func deleteAll() async throws
    func summary() async throws -> PersonalHistorySummary
}

protocol PersonalHistoryKeyProviding: Sendable {
    func loadOrCreateKey() throws -> Data
    func deleteKey() throws
}

enum PersonalHistoryStorageError: Error, Equatable {
    case corruptStore
    case invalidEvent
    case invalidKey
    case keychain(OSStatus)
}

final class KeychainPersonalHistoryKeyProvider: PersonalHistoryKeyProviding, @unchecked Sendable {
    private let service = "bar.r3d.tilde.personal-history"
    private let account = "aes-gcm-key-v1"

    func loadOrCreateKey() throws -> Data {
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
        guard status == errSecItemNotFound else {
            throw PersonalHistoryStorageError.keychain(status)
        }

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
        if addStatus == errSecDuplicateItem {
            return try loadOrCreateKey()
        }
        guard addStatus == errSecSuccess else {
            throw PersonalHistoryStorageError.keychain(addStatus)
        }
        return key
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

    func loadEvents() async throws -> [PersonalHistoryEvent] {
        try await perform { try self.loadSynchronously() }
    }

    func deleteAll() async throws {
        try await perform {
            let removedFile = SecureLocalStorage.removeOwnerOnlyFile(at: self.location)
            try self.keyProvider.deleteKey()
            guard removedFile else { throw CocoaError(.fileWriteUnknown) }
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
        let key = try symmetricKey()
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

        guard let handle = SecureLocalStorage.openFileForReadingAndAppending(at: location) else {
            throw CocoaError(.fileWriteNoPermission)
        }
        defer { try? handle.close() }
        let size = try handle.seekToEnd()
        if size == 0 {
            try handle.write(contentsOf: Self.header)
        } else {
            try validateHeaderAndTail(handle: handle, size: size)
        }
        _ = try handle.seekToEnd()
        try handle.write(contentsOf: encryptedLines)
    }

    private func loadSynchronously() throws -> [PersonalHistoryEvent] {
        var info = stat()
        if lstat(location.path, &info) != 0 {
            guard errno == ENOENT else { throw CocoaError(.fileReadUnknown) }
            return []
        }
        guard let handle = SecureLocalStorage.openExistingFileForReading(at: location) else {
            throw PersonalHistoryStorageError.corruptStore
        }
        defer { try? handle.close() }
        let data = try handle.readToEnd() ?? Data()
        guard data.starts(with: Self.header), data.last == 0x0A else {
            throw PersonalHistoryStorageError.corruptStore
        }
        let body = data.dropFirst(Self.header.count)
        if body.isEmpty { return [] }

        let key = try symmetricKey()
        let decoder = JSONDecoder()
        return try body.split(separator: 0x0A).map { line in
            guard let combined = Data(base64Encoded: Data(line)),
                  let box = try? AES.GCM.SealedBox(combined: combined),
                  let plaintext = try? AES.GCM.open(
                    box,
                    using: key,
                    authenticating: Self.authenticatedData
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

    private func symmetricKey() throws -> SymmetricKey {
        let data = try keyProvider.loadOrCreateKey()
        guard data.count == 32 else { throw PersonalHistoryStorageError.invalidKey }
        return SymmetricKey(data: data)
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
