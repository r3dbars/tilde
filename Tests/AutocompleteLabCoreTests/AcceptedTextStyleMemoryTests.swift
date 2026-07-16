import Foundation
import Testing
@testable import AutocompleteLabCore
@testable import AutocompleteLabResearch

@Suite("Accepted text style memory")
struct AcceptedTextStyleMemoryTests {
    @Test("Builds an aggregate kept style sketch without raw text")
    func buildsAggregateKeptStyleSketchWithoutRawText() throws {
        var store = AcceptedTextStyleMemoryStore()
        let key = styleKey()

        store.recordKeptText(" make this simpler.", key: key)
        _ = store.recordKeptText(" keep it moving.", key: key)
        let sketch = try #require(store.sketch(for: key))

        #expect(sketch.sampleCount == 2)
        #expect(sketch.averageWordCount == 3)
        #expect(sketch.terminalPunctuationRate == 1)
        #expect(sketch.lowercaseStartRate == 1)
        #expect(sketch.questionEndingRate == 0)
        #expect(sketch.shortSuffixRate == 0)
        #expect(sketch.averageFinalTokenLength == 6.5)
        #expect(sketch.promptGuidance?.contains("avg 3.00 words") == true)
        #expect(sketch.promptGuidance?.contains("short kept suffixes") == true)
        #expect(sketch.promptGuidance?.contains("avg final token 6.50 chars") == true)
        #expect(sketch.promptGuidance?.contains("make this simpler") == false)
    }

    @Test("Kept suffix shape stays aggregate and raw-text-free")
    func keptSuffixShapeStaysAggregateAndRawTextFree() throws {
        var store = AcceptedTextStyleMemoryStore()
        let key = styleKey()

        store.recordKeptText(" precise", key: key)
        store.recordKeptText(" enough", key: key)
        let sketch = try #require(store.sketch(for: key))
        let metadata = sketch.traceMetadata
        let encoded = String(decoding: try JSONEncoder().encode(sketch), as: UTF8.self)

        #expect(sketch.shortSuffixRate == 1)
        #expect(sketch.averageFinalTokenLength == 6.5)
        #expect(metadata["styleSketchShortSuffixRate"] == "1.00")
        #expect(metadata["styleSketchAverageFinalTokenLength"] == "6.50")
        #expect(!encoded.localizedCaseInsensitiveContains("precise"))
        #expect(!encoded.localizedCaseInsensitiveContains("enough"))
    }

    @Test("Persists and restores aggregate style memory")
    func persistsAndRestoresAggregateStyleMemory() throws {
        var store = AcceptedTextStyleMemoryStore()
        let key = styleKey()

        store.recordKeptText(" Make this clear?", key: key)
        store.recordKeptText(" Make this calm?", key: key)

        let data = try #require(store.jsonData())
        let restored = try #require(AcceptedTextStyleMemoryStore(jsonData: data))
        let sketch = try #require(restored.sketch(for: key))

        #expect(sketch.sampleCount == 2)
        #expect(sketch.questionEndingRate == 1)
        #expect(sketch.lowercaseStartRate == 0)
    }

    @Test("Decays old aggregate style evidence")
    func decaysOldAggregateStyleEvidence() throws {
        var store = AcceptedTextStyleMemoryStore(halfLifeSeconds: 60)
        let key = styleKey()
        let start = Date(timeIntervalSince1970: 100)

        store.recordKeptText(" make this clear.", key: key, now: start)
        store.recordKeptText(" make this calm.", key: key, now: start)

        let decayed = store.sketch(for: key, now: start.addingTimeInterval(60))

        #expect(decayed == nil)
    }

    private func styleKey() -> AcceptedTextStyleMemoryKey {
        AcceptedTextStyleMemoryKey(
            appBundleIdentifier: "com.apple.TextEdit",
            fieldKind: .multilineCompose,
            behaviorProfileID: .docsProse
        )
    }
}
