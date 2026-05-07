import Foundation
import Testing
@testable import AutocompleteLabCore

@Suite("Annoyance suppressor")
struct AnnoyanceSuppressorTests {
    private let context = AnnoyanceContext(
        appBundleIdentifier: "com.apple.TextEdit",
        fieldIdentifier: "com.apple.TextEdit|pid:1|element:2",
        requestMode: .phraseContinuation,
        fieldKind: .multilineCompose
    )

    @Test("Decays scores by half-life")
    func decaysScoresByHalfLife() {
        let start = Date(timeIntervalSince1970: 0)
        var suppressor = AnnoyanceSuppressor(halfLifeSeconds: 20 * 60)

        _ = suppressor.record(.wrongInsertion, context: context, now: start)

        #expect(abs(suppressor.score(for: context, now: start.addingTimeInterval(20 * 60)) - 0.5) < 0.0001)
    }

    @Test("Rapid Escape quiets the current field")
    func rapidEscapeQuietsField() {
        let start = Date(timeIntervalSince1970: 0)
        var suppressor = AnnoyanceSuppressor()

        let update = suppressor.record(.rapidEscDismissal, context: context, now: start)

        #expect(update.startedQuietModes.contains { mode in
            if case .field = mode {
                return true
            }
            return false
        })
        #expect(suppressor.quietMode(for: context, now: start).traceReason == "quiet-mode-field")
    }

    @Test("Repeated severe failures quiet the app")
    func repeatedSevereFailuresQuietApp() {
        let start = Date(timeIntervalSince1970: 0)
        var suppressor = AnnoyanceSuppressor()

        _ = suppressor.record(.wrongInsertion, context: context, now: start)
        _ = suppressor.record(.wrongInsertion, context: context, now: start.addingTimeInterval(10))
        _ = suppressor.record(.wrongInsertion, context: context, now: start.addingTimeInterval(20))

        #expect(suppressor.quietMode(for: context, now: start.addingTimeInterval(20)).traceReason == "quiet-mode-app")
    }

    @Test("Wrong insertion hard-stops the field")
    func wrongInsertionHardStopsField() {
        let start = Date(timeIntervalSince1970: 0)
        var suppressor = AnnoyanceSuppressor(fieldQuietThreshold: 10)

        _ = suppressor.record(.wrongInsertion, context: context, now: start)

        #expect(suppressor.quietMode(for: context, now: start).traceReason == "quiet-mode-field")
    }

    @Test("Accepted and kept reduces annoyance")
    func acceptedAndKeptReducesAnnoyance() {
        let start = Date(timeIntervalSince1970: 0)
        var suppressor = AnnoyanceSuppressor(fieldQuietThreshold: 10)

        _ = suppressor.record(.typedOver, context: context, now: start)
        _ = suppressor.record(.acceptedAndKept, context: context, now: start.addingTimeInterval(5))

        #expect(suppressor.score(for: context, now: start.addingTimeInterval(5)) == 0)
    }

    @Test("Quiet modes expire")
    func quietModesExpire() {
        let start = Date(timeIntervalSince1970: 0)
        var suppressor = AnnoyanceSuppressor(fieldQuietDurationSeconds: 15 * 60)

        _ = suppressor.record(.rapidEscDismissal, context: context, now: start)

        #expect(suppressor.quietMode(for: context, now: start.addingTimeInterval(60)).isActive)
        #expect(!suppressor.quietMode(for: context, now: start.addingTimeInterval(15 * 60 + 1)).isActive)
    }
}
