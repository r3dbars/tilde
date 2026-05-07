import Foundation
import AutocompleteLabCore

actor AnnoyanceSuppressorActor {
    private var suppressor: AnnoyanceSuppressor

    init(suppressor: AnnoyanceSuppressor = AnnoyanceSuppressor()) {
        self.suppressor = suppressor
    }

    func quietMode(for context: AnnoyanceContext, now: Date = Date()) -> QuietMode {
        suppressor.quietMode(for: context, now: now)
    }

    func record(
        _ signal: AnnoyanceSignal,
        context: AnnoyanceContext,
        now: Date = Date()
    ) -> AnnoyanceSuppressorActorUpdate {
        let update = suppressor.record(signal, context: context, now: now)
        return AnnoyanceSuppressorActorUpdate(
            update: update,
            quietMode: suppressor.quietMode(for: context, now: now)
        )
    }

    func clearField(_ fieldIdentifier: String) {
        suppressor.clearField(fieldIdentifier)
    }
}

struct AnnoyanceSuppressorActorUpdate: Sendable {
    let update: AnnoyanceUpdate
    let quietMode: QuietMode
}
