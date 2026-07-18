import AutocompleteLabCore
import Foundation

/// Owns delayed acceptance-survival checkpoint tasks.
/// Text reads, classification, and privacy-safe result recording remain in AppDelegate.
@MainActor
final class AcceptanceSurvivalTaskHost {
    private var tasks: [String: Task<Void, Never>] = [:]

    var scheduledTaskCount: Int {
        tasks.count
    }

    func schedule(
        acceptanceID: String,
        start: @escaping @MainActor () async -> Void,
        measure: @escaping @MainActor (AcceptanceSurvivalCheckpoint) async -> Void
    ) {
        cancel(acceptanceID: acceptanceID)
        tasks[acceptanceID] = Task { @MainActor in
            await start()
            let checkpoints: [(AcceptanceSurvivalCheckpoint, Duration)] = [
                (.twoSeconds, .seconds(2)),
                (.tenSeconds, .seconds(8)),
                (.thirtySeconds, .seconds(20)),
                (.oneMinute, .seconds(30)),
                (.fiveMinutes, .seconds(240))
            ]

            for (checkpoint, delay) in checkpoints {
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled else {
                    return
                }

                await measure(checkpoint)
            }
        }
    }

    func cancel(acceptanceID: String) {
        tasks[acceptanceID]?.cancel()
        tasks[acceptanceID] = nil
    }

    func finish(acceptanceID: String) {
        tasks[acceptanceID] = nil
    }
}
