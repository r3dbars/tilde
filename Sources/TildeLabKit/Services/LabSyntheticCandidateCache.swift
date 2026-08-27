import CSQLite
import CryptoKit
import Foundation

public enum LabSyntheticCandidateCacheError: Error, LocalizedError, Equatable, Sendable {
    case privateSourceForbidden
    case unsafePath
    case database(String)
    case corruptEntry

    public var errorDescription: String? {
        switch self {
        case .privateSourceForbidden:
            "Raw candidate caching is restricted to scenarios explicitly marked synthetic."
        case .unsafePath:
            "The candidate-cache path is not a regular owner-controlled file."
        case let .database(message):
            "The candidate cache failed: \(message)"
        case .corruptEntry:
            "A synthetic candidate-cache entry is corrupt."
        }
    }
}

public struct LabCandidateCacheKey: Codable, Equatable, Hashable, Sendable {
    public let id: String
    public let modelSHA256: String
    public let helperSHA256: String
    public let promptSHA256: String
    public let generationSHA256: String
    public let scenarioID: String
    public let contextVariant: LabContextVariant
    public let seed: Int

    public init(
        modelSHA256: String,
        helperSHA256: String,
        prompt: String,
        generation: LabGenerationConfiguration,
        scenario: LabScenario
    ) throws {
        guard scenario.evaluation.source == .synthetic else {
            throw LabSyntheticCandidateCacheError.privateSourceForbidden
        }
        self.modelSHA256 = modelSHA256
        self.helperSHA256 = helperSHA256
        promptSHA256 = Self.digest(Data(prompt.utf8))
        // The confidence floor is a post-generation display decision. Exclude
        // it from the raw-candidate identity so threshold sweeps can replay the
        // same probabilities without asking the model again. `probabilityCount`
        // stays in the key because it changes the evidence returned by the
        // server.
        var inferenceGeneration = generation
        inferenceGeneration.minimumMeanTokenProbability = 0
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        generationSHA256 = Self.digest(try encoder.encode(inferenceGeneration))
        scenarioID = scenario.id
        contextVariant = scenario.evaluation.contextVariant
        seed = generation.seed
        id = Self.digest(Data([
            modelSHA256, helperSHA256, promptSHA256, generationSHA256,
            scenario.id, scenario.evaluation.contextVariant.rawValue,
            String(generation.seed),
        ].joined(separator: "\u{1f}").utf8))
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

public struct LabCachedCandidate: Codable, Equatable, Sendable {
    public let rawCandidate: String
    public let tokenIDs: [Int]
    public let tokenLogProbabilities: [Double]
    public let tokenProbabilityMargins: [Double]?
    public let tokenEntropies: [Double]?
    public let firstTokenMilliseconds: Int?
    public let totalMilliseconds: Int
    public let stopReason: String?
    public let meanTokenProbability: Double?
    public let modelIdentifier: String
    public let modelRevision: String

    public init(response: LabModelResponse, assets: LabAssetSnapshot) {
        rawCandidate = response.content
        tokenIDs = response.tokenIDs
        tokenLogProbabilities = response.tokenLogProbabilities
        tokenProbabilityMargins = response.tokenProbabilityMargins
        tokenEntropies = response.tokenEntropies
        firstTokenMilliseconds = response.firstTokenMilliseconds
        totalMilliseconds = response.latencyMilliseconds
        stopReason = response.stopReason
        meanTokenProbability = response.meanTokenProbability
        modelIdentifier = assets.modelIdentifier
        modelRevision = assets.modelRevision
    }

    public var modelResponse: LabModelResponse {
        LabModelResponse(
            content: rawCandidate,
            latencyMilliseconds: totalMilliseconds,
            firstTokenMilliseconds: firstTokenMilliseconds,
            meanTokenProbability: meanTokenProbability,
            tokenIDs: tokenIDs,
            tokenLogProbabilities: tokenLogProbabilities,
            tokenProbabilityMargins: tokenProbabilityMargins ?? [],
            tokenEntropies: tokenEntropies ?? [],
            stopReason: stopReason
        )
    }
}

public struct LabCandidateCacheContext: Sendable {
    public let cache: LabSyntheticCandidateCache
    public let assets: LabAssetSnapshot

    public init(cache: LabSyntheticCandidateCache, assets: LabAssetSnapshot) {
        self.cache = cache
        self.assets = assets
    }
}

/// Explicit, deletable raw-output cache for synthetic fixtures only. Private
/// historical and hand-curated scenarios fail closed before any SQL write.
public actor LabSyntheticCandidateCache {
    nonisolated(unsafe) private var database: OpaquePointer?
    public nonisolated let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public static var defaultURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Tilde Lab/Candidate Cache", isDirectory: true)
            .appendingPathComponent("synthetic-candidates.sqlite3")
    }

    public init(fileURL: URL = LabSyntheticCandidateCache.defaultURL) throws {
        self.fileURL = fileURL.standardizedFileURL
        try Self.preparePath(self.fileURL)
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(self.fileURL.path, &handle, flags, nil) == SQLITE_OK,
              let handle else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "open failed"
            if let handle { sqlite3_close(handle) }
            throw LabSyntheticCandidateCacheError.database(message)
        }
        database = handle
        do {
            try Self.execute("PRAGMA journal_mode=WAL", on: handle)
            try Self.execute("PRAGMA synchronous=FULL", on: handle)
            try Self.execute("PRAGMA busy_timeout=5000", on: handle)
            try Self.execute(
                """
                CREATE TABLE IF NOT EXISTS candidate_cache(
                  cache_key TEXT PRIMARY KEY,
                  model_sha TEXT NOT NULL,
                  helper_sha TEXT NOT NULL,
                  prompt_sha TEXT NOT NULL,
                  generation_sha TEXT NOT NULL,
                  scenario_id TEXT NOT NULL,
                  context_variant TEXT NOT NULL,
                  seed INTEGER NOT NULL,
                  response_json BLOB NOT NULL,
                  created_at REAL NOT NULL,
                  last_used_at REAL NOT NULL
                );
                """,
                on: handle
            )
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: self.fileURL.path
            )
        } catch {
            sqlite3_close(handle)
            database = nil
            throw error
        }
    }

    deinit {
        if let database { sqlite3_close(database) }
    }

    public func value(for key: LabCandidateCacheKey) throws -> LabCachedCandidate? {
        var statement: OpaquePointer?
        try prepare("SELECT response_json FROM candidate_cache WHERE cache_key=?", &statement)
        guard let statement else { throw LabSyntheticCandidateCacheError.database("prepare failed") }
        defer { sqlite3_finalize(statement) }
        try bind(key.id, at: 1, in: statement)
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        guard let pointer = sqlite3_column_blob(statement, 0) else {
            throw LabSyntheticCandidateCacheError.corruptEntry
        }
        let bytes = Data(bytes: pointer, count: Int(sqlite3_column_bytes(statement, 0)))
        guard let result = try? decoder.decode(LabCachedCandidate.self, from: bytes) else {
            throw LabSyntheticCandidateCacheError.corruptEntry
        }
        try updateLastUsed(key.id)
        return result
    }

    public func store(
        _ candidate: LabCachedCandidate,
        for key: LabCandidateCacheKey
    ) throws {
        let bytes = try encoder.encode(candidate)
        var statement: OpaquePointer?
        try prepare(
            """
            INSERT INTO candidate_cache(
              cache_key, model_sha, helper_sha, prompt_sha, generation_sha,
              scenario_id, context_variant, seed, response_json, created_at, last_used_at
            ) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(cache_key) DO NOTHING
            """,
            &statement
        )
        guard let statement else { throw LabSyntheticCandidateCacheError.database("prepare failed") }
        defer { sqlite3_finalize(statement) }
        try bind(key.id, at: 1, in: statement)
        try bind(key.modelSHA256, at: 2, in: statement)
        try bind(key.helperSHA256, at: 3, in: statement)
        try bind(key.promptSHA256, at: 4, in: statement)
        try bind(key.generationSHA256, at: 5, in: statement)
        try bind(key.scenarioID, at: 6, in: statement)
        try bind(key.contextVariant.rawValue, at: 7, in: statement)
        sqlite3_bind_int64(statement, 8, sqlite3_int64(key.seed))
        try bind(bytes, at: 9, in: statement)
        let now = Date().timeIntervalSince1970
        sqlite3_bind_double(statement, 10, now)
        sqlite3_bind_double(statement, 11, now)
        try step(statement)
    }

    public func count() throws -> Int {
        var statement: OpaquePointer?
        try prepare("SELECT COUNT(*) FROM candidate_cache", &statement)
        guard let statement else { throw LabSyntheticCandidateCacheError.database("prepare failed") }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw LabSyntheticCandidateCacheError.database("count failed")
        }
        return Int(sqlite3_column_int64(statement, 0))
    }

    public func deleteEverything() throws {
        try execute("DELETE FROM candidate_cache")
        try execute("PRAGMA wal_checkpoint(TRUNCATE)")
    }

    private func updateLastUsed(_ key: String) throws {
        var statement: OpaquePointer?
        try prepare(
            "UPDATE candidate_cache SET last_used_at=? WHERE cache_key=?",
            &statement
        )
        guard let statement else { throw LabSyntheticCandidateCacheError.database("prepare failed") }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_double(statement, 1, Date().timeIntervalSince1970)
        try bind(key, at: 2, in: statement)
        try step(statement)
    }

    private static func preparePath(_ url: URL) throws {
        guard url.isFileURL, !url.path.isEmpty else {
            throw LabSyntheticCandidateCacheError.unsafePath
        }
        let manager = FileManager.default
        let directory = url.deletingLastPathComponent()
        try manager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try manager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        if manager.fileExists(atPath: url.path) {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true else {
                throw LabSyntheticCandidateCacheError.unsafePath
            }
        }
    }

    private func execute(_ sql: String) throws {
        guard let database else { throw LabSyntheticCandidateCacheError.database("closed") }
        try Self.execute(sql, on: database)
    }

    private static func execute(_ sql: String, on database: OpaquePointer) throws {
        var message: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(database, sql, nil, nil, &message) == SQLITE_OK else {
            let detail = message.map { String(cString: $0) }
                ?? String(cString: sqlite3_errmsg(database))
            sqlite3_free(message)
            throw LabSyntheticCandidateCacheError.database(detail)
        }
    }

    private func prepare(_ sql: String, _ statement: inout OpaquePointer?) throws {
        guard let database else { throw LabSyntheticCandidateCacheError.database("closed") }
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw LabSyntheticCandidateCacheError.database(String(cString: sqlite3_errmsg(database)))
        }
    }

    private func step(_ statement: OpaquePointer) throws {
        guard sqlite3_step(statement) == SQLITE_DONE else {
            let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "closed"
            throw LabSyntheticCandidateCacheError.database(message)
        }
    }

    private func bind(_ value: String, at index: Int32, in statement: OpaquePointer) throws {
        let code = value.withCString {
            sqlite3_bind_text(statement, index, $0, -1, cacheSQLiteTransient)
        }
        guard code == SQLITE_OK else { throw LabSyntheticCandidateCacheError.database("bind failed") }
    }

    private func bind(_ value: Data, at index: Int32, in statement: OpaquePointer) throws {
        let code = value.withUnsafeBytes {
            sqlite3_bind_blob(statement, index, $0.baseAddress, Int32($0.count), cacheSQLiteTransient)
        }
        guard code == SQLITE_OK else { throw LabSyntheticCandidateCacheError.database("bind failed") }
    }
}

private let cacheSQLiteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
