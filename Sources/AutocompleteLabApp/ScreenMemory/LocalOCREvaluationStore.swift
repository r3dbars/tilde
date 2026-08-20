import AutocompleteLabCore
import Carbon.HIToolbox.Events
import Foundation

/// Explicit development-only corpus for comparing incremental OCR with a
/// full-frame reference pass over the exact same image.
///
/// This is deliberately separate from DiagnosticsLog: samples contain raw
/// visible text and must never enter unified logs, exported diagnostics, or
/// release builds. The user enables collection in Settings, the file is
/// owner-only, and retention is bounded to the newest 100 samples / 10 MiB.
struct LocalOCREvaluationSample: Codable, Sendable {
    struct Block: Codable, Sendable {
        let text: String
        let x: Double
        let y: Double
        let width: Double
        let height: Double
        let ownerBundleIdentifier: String?
        let windowTitle: String?

        init(_ block: ScreenSnapshot.TextBlock) {
            text = block.text
            x = block.boundingBox.x
            y = block.boundingBox.y
            width = block.boundingBox.width
            height = block.boundingBox.height
            ownerBundleIdentifier = block.windowOwnerBundleIdentifier
            windowTitle = block.windowTitle
        }
    }

    let schemaVersion: Int
    let capturedAt: Date
    let captureKind: String
    let incrementalScope: String
    let incrementalMilliseconds: Int
    let fullReferenceMilliseconds: Int
    let incrementalBlocks: [Block]
    let fullReferenceBlocks: [Block]

    init(
        capturedAt: Date,
        captureKind: String,
        incrementalScope: String,
        incrementalMilliseconds: Int,
        fullReferenceMilliseconds: Int,
        incrementalBlocks: [ScreenSnapshot.TextBlock],
        fullReferenceBlocks: [ScreenSnapshot.TextBlock]
    ) {
        schemaVersion = 2
        self.capturedAt = capturedAt
        self.captureKind = captureKind
        self.incrementalScope = incrementalScope
        self.incrementalMilliseconds = incrementalMilliseconds
        self.fullReferenceMilliseconds = fullReferenceMilliseconds
        self.incrementalBlocks = incrementalBlocks.map(Block.init)
        self.fullReferenceBlocks = fullReferenceBlocks.map(Block.init)
    }
}

struct LocalOCREvaluationSummary: Equatable, Sendable {
    let sampleCount: Int
    let approximateBytes: Int64
}

final class LocalOCREvaluationStore: @unchecked Sendable {
    static let shared = LocalOCREvaluationStore()
    static let maximumSamples = 100
    static let maximumBytes = 10 * 1_024 * 1_024
    static let maximumRecordBytes = 1 * 1_024 * 1_024

    static var isAvailableInCurrentBuild: Bool {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return isAvailable(bundleVersion: version)
    }

    static func isAvailable(bundleVersion: String?) -> Bool {
        bundleVersion?.hasSuffix("-dev") == true
    }

    let location: URL
    private let queue = DispatchQueue(label: "bar.r3d.tilde.local-ocr-evaluation")
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let mayPersist: @Sendable () -> Bool
    private let excludedApps: @Sendable () -> Set<String>
    private let generationLock = NSLock()
    private var generationStorage: UInt64 = 0

    init(
        location: URL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Tilde/OCR Evaluation/samples.jsonl"),
        mayPersist: @escaping @Sendable () -> Bool = {
            LocalOCREvaluationStore.isAvailableInCurrentBuild
                && TildeSettings().localOCREvaluationEnabled
                && TildeSettings().screenMemoryEnabled
                && ScreenRecordingPermission.isGranted()
                && !ScreenLockObserver.isLocked()
                && !IsSecureEventInputEnabled()
        },
        excludedApps: @escaping @Sendable () -> Set<String> = {
            TildeSettings().personalHistoryExcludedApps
        }
    ) {
        self.location = location
        self.mayPersist = mayPersist
        self.excludedApps = excludedApps
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func record(_ sample: LocalOCREvaluationSample) {
        record(sample, generation: generationToken())
    }

    /// A capture holds this token while its full-reference OCR is running.
    /// Deletion advances the generation, so a late result from before the
    /// delete can never recreate the raw corpus afterward.
    func generationToken() -> UInt64 {
        generationLock.lock()
        defer { generationLock.unlock() }
        return generationStorage
    }

    func record(_ sample: LocalOCREvaluationSample, generation token: UInt64) {
        queue.async { [self] in
            guard token == generationToken() else { return }
            persist(sample)
        }
    }

    func flush() { queue.sync {} }

    func summary() -> LocalOCREvaluationSummary {
        queue.sync { readSummary() }
    }

    @discardableResult
    func deleteAll() -> Bool {
        queue.sync {
            generationLock.lock()
            generationStorage &+= 1
            generationLock.unlock()
            // Persist the disabled state before unlinking the corpus. Other
            // Tilde processes check this marker immediately before writing,
            // so a queued capture cannot recreate data after deletion.
            guard createCollectionDisabledMarker() else { return false }
            return SecureLocalStorage.removeOwnerOnlyFile(at: location)
        }
    }

    @discardableResult
    func beginCollection() -> Bool {
        queue.sync {
            generationLock.lock()
            generationStorage &+= 1
            generationLock.unlock()
            return SecureLocalStorage.removeOwnerOnlyFile(at: collectionDisabledMarker)
        }
    }

    private func persist(_ sample: LocalOCREvaluationSample) {
        do {
            guard mayPersist(sample), !isCollectionDisabled() else { return }
            let encoded = try encoder.encode(sample)
            guard encoded.count <= Self.maximumRecordBytes,
                  let handle = SecureLocalStorage.openFileForReadingAndAppending(at: location) else {
                return
            }
            defer { try? handle.close() }

            let existingSize = try handle.seekToEnd()
            guard existingSize <= UInt64(Self.maximumBytes) else { return }
            try handle.seek(toOffset: 0)
            let existing = try handle.readToEnd() ?? Data()
            let newline: UInt8 = 0x0A
            var records = [UInt8](existing)
                .split(separator: newline, omittingEmptySubsequences: true)
                .compactMap { bytes -> Data? in
                    let data = Data(bytes)
                    guard let retained = try? decoder.decode(LocalOCREvaluationSample.self, from: data),
                          retained.schemaVersion == 2,
                          mayPersist(retained) else { return nil }
                    return data
                }
            records.append(encoded)

            func encodedSize(_ values: [Data]) -> Int {
                values.reduce(0) { $0 + $1.count + 1 }
            }
            while records.count > Self.maximumSamples || encodedSize(records) > Self.maximumBytes {
                guard !records.isEmpty else { break }
                records.removeFirst()
            }

            var output = Data()
            for record in records {
                output.append(record)
                output.append(0x0A)
            }
            // Re-check immediately before the only raw disk mutation. This
            // closes the async queue gap when consent, Screen Memory, TCC,
            // lock state, or Secure Event Input changes after record().
            guard mayPersist(sample), !isCollectionDisabled() else { return }
            try handle.truncate(atOffset: 0)
            // FileHandle truncation does not promise to reset the current
            // offset. Seek after truncating or repeated rewrites can create
            // a sparse file whose leading hole consumes the retention cap.
            try handle.seek(toOffset: 0)
            try handle.write(contentsOf: output)
            try handle.synchronize()
        } catch {
            // Evaluation must never affect capture or typing.
        }
    }

    private func mayPersist(_ sample: LocalOCREvaluationSample) -> Bool {
        guard mayPersist() else { return false }
        let exclusions = excludedApps()
        return (sample.incrementalBlocks + sample.fullReferenceBlocks).allSatisfy { block in
            guard let owner = block.ownerBundleIdentifier else { return false }
            return !DefaultExcludedApps.isExcluded(
                owner,
                configuredExcludedApps: exclusions
            )
        }
    }

    private var collectionDisabledMarker: URL {
        location.deletingLastPathComponent().appendingPathComponent("collection-disabled")
    }

    private func isCollectionDisabled() -> Bool {
        switch SecureLocalStorage.openExistingOwnerOnlyFileForReadOnlyStatus(
            at: collectionDisabledMarker
        ) {
        case let .opened(handle):
            try? handle.close()
            return true
        case .missing:
            return false
        case .rejected:
            return true
        }
    }

    private func createCollectionDisabledMarker() -> Bool {
        guard let handle = SecureLocalStorage.openFileForAppending(at: collectionDisabledMarker) else {
            return false
        }
        defer { try? handle.close() }
        do {
            try handle.synchronize()
            return true
        } catch {
            return false
        }
    }

    private func readSummary() -> LocalOCREvaluationSummary {
        guard case let .opened(handle) = SecureLocalStorage
            .openExistingOwnerOnlyFileForReadOnlyStatus(at: location) else {
            return LocalOCREvaluationSummary(sampleCount: 0, approximateBytes: 0)
        }
        defer { try? handle.close() }
        guard let size = try? handle.seekToEnd() else {
            return LocalOCREvaluationSummary(sampleCount: 0, approximateBytes: 0)
        }
        guard size <= UInt64(Self.maximumBytes) else {
            return LocalOCREvaluationSummary(sampleCount: 0, approximateBytes: Int64(size))
        }
        try? handle.seek(toOffset: 0)
        guard let data = try? handle.readToEnd() else {
            return LocalOCREvaluationSummary(sampleCount: 0, approximateBytes: Int64(size))
        }
        return LocalOCREvaluationSummary(
            sampleCount: [UInt8](data).split(
                separator: UInt8(0x0A),
                omittingEmptySubsequences: true
            ).count,
            approximateBytes: Int64(data.count)
        )
    }
}
