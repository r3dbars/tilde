import AutocompleteLabCore
import Foundation
import Testing
@testable import AutocompleteLabApp

@Suite("Local OCR evaluation store")
struct LocalOCREvaluationStoreTests {
    private func temporaryLocation() -> URL {
        URL(fileURLWithPath: "/private/tmp", isDirectory: true)
            .appendingPathComponent("tilde-ocr-evaluation-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("samples.jsonl")
    }

    private func sample(index: Int, text: String? = nil) -> LocalOCREvaluationSample {
        let candidate = ScreenSnapshot.TextBlock(
            text: text ?? "incremental-\(index)",
            boundingBox: NormalizedDisplayRect(x: 0.1, y: 0.2, width: 0.3, height: 0.04),
            windowOwnerBundleIdentifier: "com.example.Editor",
            windowTitle: "Draft"
        )
        let reference = ScreenSnapshot.TextBlock(
            text: "reference-\(index)",
            boundingBox: NormalizedDisplayRect(x: 0.1, y: 0.2, width: 0.3, height: 0.04),
            windowOwnerBundleIdentifier: "com.example.Editor",
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
        let store = LocalOCREvaluationStore(location: location)

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
        let store = LocalOCREvaluationStore(location: location)
        let oversized = String(repeating: "x", count: LocalOCREvaluationStore.maximumRecordBytes + 1)

        store.record(sample(index: 0, text: oversized))
        store.flush()

        #expect(store.summary() == LocalOCREvaluationSummary(sampleCount: 0, approximateBytes: 0))
        #expect(!FileManager.default.fileExists(atPath: location.path))
    }

    @Test("Delete removes the corpus and future summaries are empty")
    func deletesCorpus() {
        let location = temporaryLocation()
        let root = location.deletingLastPathComponent()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalOCREvaluationStore(location: location)
        store.record(sample(index: 1))
        store.flush()
        #expect(store.summary().sampleCount == 1)

        #expect(store.deleteAll())
        #expect(store.summary() == LocalOCREvaluationSummary(sampleCount: 0, approximateBytes: 0))
    }
}
