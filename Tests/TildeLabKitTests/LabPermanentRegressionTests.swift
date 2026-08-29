import Foundation
import Testing
@testable import TildeLabKit

/// F04 — the permanent regression library must keep every historically
/// discovered scoring loophole and interaction failure both guarded and
/// detectable. A failing case here means either a guard was weakened or a
/// case lost its teeth; neither may be waived by any average score.
@Suite("Permanent regression library (F04)")
struct LabPermanentRegressionTests {
    @Test("Every known failure class has exactly one stable case ID")
    func stableCaseIdentifiers() {
        let outcomes = LabPermanentRegressions.runAll()
        #expect(outcomes.map(\.caseID) == LabPermanentRegressions.caseIdentifiers)
        #expect(Set(outcomes.map(\.caseID)).count == outcomes.count)
        #expect(outcomes.count == 10)
    }

    @Test("Every guard holds and every loophole is still reproducible")
    func allCasesPass() {
        for outcome in LabPermanentRegressions.runAll() {
            #expect(
                outcome.guardHolds,
                "guard broken for \(outcome.caseID): \(outcome.detail)"
            )
            #expect(
                outcome.loopholeReproduced,
                "case lost its teeth: \(outcome.caseID): \(outcome.detail)"
            )
        }
    }

    @Test("Case content is synthetic and text-safe")
    func detailStaysTextSafe() {
        for outcome in LabPermanentRegressions.runAll() {
            #expect(!outcome.detail.contains("/Users/"))
            #expect(outcome.detail.count < 200)
        }
    }
}
