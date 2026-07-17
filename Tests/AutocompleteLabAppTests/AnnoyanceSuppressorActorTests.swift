import Foundation
import Testing
@testable import AutocompleteLabApp
@testable import AutocompleteLabCore

@Suite("Annoyance suppressor actor")
struct AnnoyanceSuppressorActorTests {
    @Test("Records signals and returns the current quiet mode")
    func recordsSignalsAndReturnsQuietMode() async {
        let actor = AnnoyanceSuppressorActor(
            suppressor: AnnoyanceSuppressor(automaticQuietModesEnabled: true)
        )
        let context = AnnoyanceContext(
            appBundleIdentifier: "com.apple.TextEdit",
            fieldIdentifier: "field-1"
        )
        let now = Date(timeIntervalSince1970: 1_000)

        let update = await actor.record(.rapidEscDismissal, context: context, now: now)
        let quietMode = await actor.quietMode(for: context, now: now)

        #expect(update.update.signal == .rapidEscDismissal)
        #expect(update.quietMode == quietMode)
    }

    @Test("Clearing a field removes field scoped quiet mode")
    func clearingFieldRemovesFieldScopedQuietMode() async {
        let actor = AnnoyanceSuppressorActor(
            suppressor: AnnoyanceSuppressor(automaticQuietModesEnabled: true)
        )
        let context = AnnoyanceContext(
            appBundleIdentifier: "com.apple.TextEdit",
            fieldIdentifier: "field-1"
        )
        let now = Date(timeIntervalSince1970: 1_000)

        _ = await actor.record(.rapidEscDismissal, context: context, now: now)
        await actor.clearField("field-1")

        #expect(await actor.quietMode(for: context, now: now) == .normal)
    }
}
