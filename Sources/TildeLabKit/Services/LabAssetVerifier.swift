import AutocompleteLabCore
import CryptoKit
import Foundation

public enum LabAssetError: Error, LocalizedError, Sendable {
    case invalidModelSize
    case invalidModelHash
    case invalidModelFormat
    case unreadableModel
    case unreadableServer

    public var errorDescription: String? {
        switch self {
        case .invalidModelSize:
            "The selected model does not have the pinned Gemma 4 E2B byte count."
        case .invalidModelHash:
            "The selected model does not match the pinned Gemma 4 E2B SHA-256."
        case .invalidModelFormat:
            "The selected experimental model is not a readable GGUF file."
        case .unreadableModel:
            "Tilde Lab could not read the selected model."
        case .unreadableServer:
            "Tilde Lab could not read the selected llama-server executable."
        }
    }
}

public actor LabAssetVerifier {
    public static let shared = LabAssetVerifier()

    private struct Fingerprint: Hashable {
        let path: String
        let bytes: UInt64
        let modified: Date
    }

    private var digestCache: [Fingerprint: String] = [:]

    public init() {}

    public func verify(_ configuration: LabExecutionConfiguration) async throws -> LabAssetSnapshot {
        try configuration.modelProfile.validated()
        let modelAttributes = try attributes(
            at: configuration.modelFile,
            error: .unreadableModel
        )
        switch configuration.modelProfile.verificationMode {
        case .productionPinned:
            guard modelAttributes.bytes == UInt64(ProductionModelAsset.expectedBytes) else {
                throw LabAssetError.invalidModelSize
            }
        case .experimentalLocal:
            try validateGGUF(at: configuration.modelFile)
        }
        let modelDigest = try await digest(
            of: configuration.modelFile,
            fingerprint: modelAttributes,
            error: .unreadableModel
        )
        if configuration.modelProfile.verificationMode == .productionPinned,
           modelDigest != ProductionModelAsset.sha256 {
            throw LabAssetError.invalidModelHash
        }

        let helperAttributes = try attributes(
            at: configuration.serverExecutable,
            error: .unreadableServer
        )
        let helperDigest = try await digest(
            of: configuration.serverExecutable,
            fingerprint: helperAttributes,
            error: .unreadableServer
        )
        return LabAssetSnapshot(
            verificationMode: configuration.modelProfile.verificationMode,
            modelIdentifier: configuration.modelProfile.identifier,
            modelRevision: configuration.modelProfile.revision,
            modelSHA256: modelDigest,
            helperSHA256: helperDigest
        )
    }

    private func validateGGUF(at url: URL) throws {
        do {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            guard try handle.read(upToCount: 4) == Data("GGUF".utf8) else {
                throw LabAssetError.invalidModelFormat
            }
        } catch let error as LabAssetError {
            throw error
        } catch {
            throw LabAssetError.unreadableModel
        }
    }

    private func attributes(at url: URL, error: LabAssetError) throws -> Fingerprint {
        guard let values = try? url.resourceValues(forKeys: [
            .isRegularFileKey, .fileSizeKey, .contentModificationDateKey,
        ]),
        values.isRegularFile == true,
        let size = values.fileSize,
        let modified = values.contentModificationDate else { throw error }
        return Fingerprint(
            path: url.standardizedFileURL.path,
            bytes: UInt64(size),
            modified: modified
        )
    }

    private func digest(
        of url: URL,
        fingerprint: Fingerprint,
        error: LabAssetError
    ) async throws -> String {
        if let cached = digestCache[fingerprint] { return cached }
        let result: String
        do {
            result = try await Task.detached(priority: .utility) {
                let handle = try FileHandle(forReadingFrom: url)
                defer { try? handle.close() }
                var hash = SHA256()
                while let chunk = try handle.read(upToCount: 4 * 1_024 * 1_024), !chunk.isEmpty {
                    try Task.checkCancellation()
                    hash.update(data: chunk)
                }
                return hash.finalize().map { String(format: "%02x", $0) }.joined()
            }.value
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw error
        }
        digestCache[fingerprint] = result
        return result
    }
}
