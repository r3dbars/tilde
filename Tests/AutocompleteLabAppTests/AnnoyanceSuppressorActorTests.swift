import Foundation
import Testing
@testable import AutocompleteLabApp
@testable import AutocompleteLabCore

@Suite("Annoyance suppressor actor")
struct AnnoyanceSuppressorActorTests {
    @Test("Recording an escape dismissal quiets the current field")
    func recordingEscapeDismissalQuietsField() async {
        let actor = AnnoyanceSuppressorActor()
        let context = annoyanceContext()

        let update = await actor.record(
            .rapidEscDismissal,
            context: context,
            now: Date(timeIntervalSince1970: 1_000)
        )

        #expect(update.quietMode.traceReason == "quiet-mode-field")
        #expect(update.update.startedQuietModes.contains { mode in
            if case .field = mode {
                return true
            }
            return false
        })
    }

    @Test("Clearing a field removes active field quiet mode")
    func clearingFieldRemovesQuietMode() async {
        let actor = AnnoyanceSuppressorActor()
        let context = annoyanceContext()
        let now = Date(timeIntervalSince1970: 1_000)

        _ = await actor.record(.rapidEscDismissal, context: context, now: now)
        await actor.clearField(context.fieldIdentifier)

        let quietMode = await actor.quietMode(for: context, now: now)
        #expect(quietMode == .normal)
    }

    private func annoyanceContext() -> AnnoyanceContext {
        AnnoyanceContext(
            appBundleIdentifier: "com.apple.TextEdit",
            fieldIdentifier: "com.apple.TextEdit|pid:42|element:7",
            requestMode: .phraseContinuation,
            fieldKind: .multilineCompose
        )
    }
}
