import AutocompleteLabCore
import Foundation
import Testing
@testable import AutocompleteLabApp

@Suite("Local OCR evaluation store")
struct LocalOCREvaluationStoreTests {
    @Test("Raw corpus is available only to explicitly labeled development builds")
    func availabilityRequiresDevVersion() {
        #expect(LocalOCREvaluationStore.isAvailable(bundleVersion: "0.1.0-dev"))
        #expect(!LocalOCREvaluationStore.isAvailable(bundleVersion: "0.1.0"))
        #expect(!LocalOCREvaluationStore.isAvailable(bundleVersion: nil))
    }

    private func temporaryLocation() -> URL {
        URL(fileURLWithPath: "/private/tmp", isDirectory: true)
            .appendingPathComponent("tilde-ocr-evaluation-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("samples.jsonl")
    }

    private func sample(
        index: Int,
        text: String? = nil,
        owner: String = "com.example.Editor"
    ) -> LocalOCREvaluationSample {
        let candidate = ScreenSnapshot.TextBlock(
            text: text ?? "incremental-\(index)",
            boundingBox: NormalizedDisplayRect(x: 0.1, y: 0.2, width: 0.3, height: 0.04),
            windowOwnerBundleIdentifier: owner,
            windowTitle: "Draft"
        )
        let reference = ScreenSnapshot.TextBlock(
            text: "reference-\(index)",
            boundingBox: NormalizedDisplayRect(x: 0.1, y: 0.2, width: 0.3, height: 0.04),
            windowOwnerBundleIdentifier: owner,
            windowTitle: "Draft"
        )
        return LocalOCREvaluationSample(
            capturedAt: Date(timeIntervalSince1970: Double(index)),
            captureKind: "window",
            incrementalScope: "region",
            incrementalMilliseconds: 20,
            fullReferenceMilliseconds: 200,
            incrementalBlocks: [candidate],
            fullReferenceBlocks: [reference]
        )
    }

    private func posixMode(of url: URL) throws -> Int16 {
        var info = stat()
        try #require(lstat(url.path, &info) == 0)
        return Int16(info.st_mode & 0o7777)
    }

    @Test("Raw paired samples are owner-only, bounded, and newest-first retained")
    func recordsBoundedCorpus() throws {
        let location = temporaryLocation()
        let root = location.deletingLastPathComponent()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalOCREvaluationStore(location: location, mayPersist: { true }, excludedApps: { [] })

        for index in 0..<(LocalOCREvaluationStore.maximumSamples + 5) {
            store.record(sample(index: index))
        }
        store.flush()

        let summary = store.summary()
        #expect(summary.approximateBytes < 1_000_000)
        #expect(summary.sampleCount == LocalOCREvaluationStore.maximumSamples)
        #expect(try posixMode(of: location) == 0o600)
        #expect(try posixMode(of: location.deletingLastPathComponent()) == 0o700)

        let lines = [UInt8](try Data(contentsOf: location))
            .split(separator: UInt8(0x0A), omittingEmptySubsequences: true)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let first = try decoder.decode(LocalOCREvaluationSample.self, from: Data(lines[0]))
        let last = try decoder.decode(LocalOCREvaluationSample.self, from: Data(lines.last!))
        #expect(first.incrementalBlocks.first?.text == "incremental-5")
        #expect(last.incrementalBlocks.first?.text == "incremental-104")
    }

    @Test("Oversized raw records fail closed without creating a corpus")
    func rejectsOversizedRecord() {
        let location = temporaryLocation()
        let root = location.deletingLastPathComponent()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalOCREvaluationStore(location: location, mayPersist: { true }, excludedApps: { [] })
        let oversized = String(repeating: "x", count: LocalOCREvaluationStore.maximumRecordBytes + 1)

        store.record(sample(index: 0, text: oversized))
        store.flush()

        #expect(store.summary() == LocalOCREvaluationSummary(sampleCount: 0, approximateBytes: 0))
        #expect(!FileManager.default.fileExists(atPath: location.path))
    }

    @Test("Persistence boundary rejects blocks from a currently excluded app")
    func rejectsCurrentlyExcludedOwner() {
        let location = temporaryLocation()
        let root = location.deletingLastPathComponent()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalOCREvaluationStore(
            location: location,
            mayPersist: { true },
            excludedApps: { ["com.example.Editor"] }
        )

        store.record(sample(index: 1))
        store.flush()

        #expect(store.summary() == LocalOCREvaluationSummary(sampleCount: 0, approximateBytes: 0))
        #expect(!FileManager.default.fileExists(atPath: location.path))
    }

    @Test("Persistence boundary always rejects password-manager blocks")
    func rejectsAlwaysExcludedOwner() {
        let location = temporaryLocation()
        let root = location.deletingLastPathComponent()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalOCREvaluationStore(
            location: location,
            mayPersist: { true },
            excludedApps: { [] }
        )

        store.record(sample(index: 1, owner: "com.1password.1password"))
        store.flush()

        #expect(store.summary() == LocalOCREvaluationSummary(sampleCount: 0, approximateBytes: 0))
        #expect(!FileManager.default.fileExists(atPath: location.path))
    }

    @Test("Disabled persistence gate creates no raw corpus")
    func rejectsWhenPersistenceGateIsClosed() {
        let location = temporaryLocation()
        let root = location.deletingLastPathComponent()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalOCREvaluationStore(
            location: location,
            mayPersist: { false },
            excludedApps: { [] }
        )

        store.record(sample(index: 1))
        store.flush()

        #expect(!FileManager.default.fileExists(atPath: location.path))
    }

    @Test("Persistence gate is checked again immediately before raw mutation")
    func rechecksPersistenceGateBeforeWrite() {
        let location = temporaryLocation()
        let root = location.deletingLastPathComponent()
        defer { try? FileManager.default.removeItem(at: root) }
        let gate = FirstCallOnlyGate()
        let store = LocalOCREvaluationStore(
            location: location,
            mayPersist: { gate.consume() },
            excludedApps: { [] }
        )

        store.record(sample(index: 1))
        store.flush()

        #expect(store.summary() == LocalOCREvaluationSummary(sampleCount: 0, approximateBytes: 0))
    }

    @Test("Oversized existing corpus is reported, not extended, and remains deletable")
    func oversizedExistingCorpusFailsClosed() throws {
        let location = temporaryLocation()
        let root = location.deletingLastPathComponent()
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(
            at: location.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: location.deletingLastPathComponent().path
        )
        let oversized = Data(repeating: 0x78, count: LocalOCREvaluationStore.maximumBytes + 1)
        try oversized.write(to: location)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: location.path)

        let store = LocalOCREvaluationStore(location: location, mayPersist: { true }, excludedApps: { [] })
        let before = store.summary()
        store.record(sample(index: 1))
        store.flush()

        #expect(before.sampleCount == 0)
        #expect(before.approximateBytes == Int64(oversized.count))
        #expect(store.summary() == before)
        #expect(store.deleteAll())
        #expect(!FileManager.default.fileExists(atPath: location.path))
    }

    @Test("Deletion refuses a symlink masquerading as the raw corpus")
    func deletionRejectsSymlink() throws {
        let location = temporaryLocation()
        let root = location.deletingLastPathComponent()
        defer { try? FileManager.default.removeItem(at: root) }
        let target = root.appendingPathComponent("target.txt")
        try FileManager.default.createDirectory(
            at: location.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: location.deletingLastPathComponent().path
        )
        try Data("keep".utf8).write(to: target)
        try FileManager.default.createSymbolicLink(at: location, withDestinationURL: target)
        let store = LocalOCREvaluationStore(location: location, mayPersist: { true }, excludedApps: { [] })

        #expect(!store.deleteAll())
        #expect(try Data(contentsOf: target) == Data("keep".utf8))
    }

    @Test("Delete removes the corpus and future summaries are empty")
    func deletesCorpus() {
        let location = temporaryLocation()
        let root = location.deletingLastPathComponent()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalOCREvaluationStore(location: location, mayPersist: { true }, excludedApps: { [] })
        store.record(sample(index: 1))
        store.flush()
        #expect(store.summary().sampleCount == 1)

        #expect(store.deleteAll())
        #expect(store.summary() == LocalOCREvaluationSummary(sampleCount: 0, approximateBytes: 0))
    }

    @Test("Delete invalidates an in-flight capture so it cannot recreate the corpus")
    func deleteInvalidatesPriorGeneration() {
        let location = temporaryLocation()
        let root = location.deletingLastPathComponent()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalOCREvaluationStore(location: location, mayPersist: { true }, excludedApps: { [] })
        let inFlightGeneration = store.generationToken()

        #expect(store.deleteAll())
        store.record(sample(index: 1), generation: inFlightGeneration)
        store.flush()

        #expect(store.summary() == LocalOCREvaluationSummary(sampleCount: 0, approximateBytes: 0))
        #expect(!FileManager.default.fileExists(atPath: location.path))
    }

    @Test("Delete marker prevents another store instance from recreating the corpus")
    func deleteCoordinatesAcrossStoreInstances() {
        let location = temporaryLocation()
        let root = location.deletingLastPathComponent()
        defer { try? FileManager.default.removeItem(at: root) }
        let deletingStore = LocalOCREvaluationStore(
            location: location,
            mayPersist: { true },
            excludedApps: { [] }
        )
        let otherProcessStore = LocalOCREvaluationStore(
            location: location,
            mayPersist: { true },
            excludedApps: { [] }
        )

        #expect(deletingStore.deleteAll())
        otherProcessStore.record(sample(index: 1))
        otherProcessStore.flush()
        #expect(!FileManager.default.fileExists(atPath: location.path))

        #expect(otherProcessStore.beginCollection())
        otherProcessStore.record(sample(index: 2))
        otherProcessStore.flush()
        #expect(otherProcessStore.summary().sampleCount == 1)
    }

    @Test("A rewrite drops records from the older pre-filter corpus schema")
    func rewriteDropsLegacyCorpusRecords() throws {
        let location = temporaryLocation()
        let root = location.deletingLastPathComponent()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalOCREvaluationStore(location: location, mayPersist: { true }, excludedApps: { [] })
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var legacy = try encoder.encode(sample(index: 1, owner: "com.1password.1password"))
        let currentSchema = Data("\"schemaVersion\":2".utf8)
        let oldSchema = Data("\"schemaVersion\":1".utf8)
        let range = try #require(legacy.range(of: currentSchema))
        legacy.replaceSubrange(range, with: oldSchema)
        legacy.append(0x0A)
        try FileManager.default.createDirectory(
            at: location.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: location.deletingLastPathComponent().path
        )
        try legacy.write(to: location)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: location.path)

        store.record(sample(index: 2))
        store.flush()

        #expect(store.summary().sampleCount == 1)
        let contents = try Data(contentsOf: location)
        #expect(contents.range(of: Data("reference-1".utf8)) == nil)
        #expect(contents.range(of: Data("reference-2".utf8)) != nil)
    }

    @Test("Byte retention cap removes oldest records before the sample-count cap")
    func recordsRespectByteCap() throws {
        let location = temporaryLocation()
        let root = location.deletingLastPathComponent()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalOCREvaluationStore(location: location, mayPersist: { true }, excludedApps: { [] })
        let payload = String(repeating: "x", count: 900_000)

        for index in 0..<12 {
            store.record(sample(index: index, text: "\(index)-\(payload)"))
        }
        store.flush()

        let summary = store.summary()
        #expect(summary.approximateBytes <= Int64(LocalOCREvaluationStore.maximumBytes))
        #expect(summary.sampleCount < 12)
        let lines = [UInt8](try Data(contentsOf: location))
            .split(separator: UInt8(0x0A), omittingEmptySubsequences: true)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let first = try decoder.decode(LocalOCREvaluationSample.self, from: Data(lines[0]))
        let last = try decoder.decode(LocalOCREvaluationSample.self, from: Data(lines.last!))
        #expect(first.capturedAt > Date(timeIntervalSince1970: 0))
        #expect(last.capturedAt == Date(timeIntervalSince1970: 11))
    }
}

private final class FirstCallOnlyGate: @unchecked Sendable {
    private let lock = NSLock()
    private var callCount = 0

    func consume() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        callCount += 1
        return callCount == 1
    }
}
