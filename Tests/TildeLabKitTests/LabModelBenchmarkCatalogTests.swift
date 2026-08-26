import Testing
@testable import TildeLabKit

@Suite("Tilde Lab checked-in model benchmarks")
struct LabModelBenchmarkCatalogTests {
    @Test("Bundled catalog is aggregate-only, complete, and ranks the current champion")
    func bundledCatalog() throws {
        let snapshot = try LabModelBenchmarkCatalog.loadBundled()

        #expect(snapshot.schema == LabModelBenchmarkCatalog.schema)
        #expect(snapshot.entries.count == 12)
        #expect(snapshot.fullComparisons.count == 11)
        #expect(snapshot.fullComparisons.first?.id == "qwen-3-5-9b-q4km")
        #expect(snapshot.entries.allSatisfy { $0.modelSHA256.count == 64 })
        #expect(snapshot.entries.allSatisfy { $0.useful + $0.wrong + $0.silent == $0.evaluations })
        let promoted = try #require(snapshot.promotedConfigurations.first)
        #expect(promoted.id == "qwen-3-5-9b-god-v1")
        #expect(promoted.useful + promoted.wrong + promoted.silent == promoted.evaluations)
        #expect(promoted.qualityScore > promoted.baselineQualityScore)
        #expect(promoted.wrong < promoted.baselineWrong)
    }
}
