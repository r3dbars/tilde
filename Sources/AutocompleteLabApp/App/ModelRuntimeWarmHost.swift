import Foundation
import AutocompleteLabCore

/// Owns the asynchronous warm-up task so AppDelegate only coordinates runtime state.
@MainActor
final class ModelRuntimeWarmHost {
    private var task: Task<Void, Never>?

    func start(
        runtime: any ModelRuntime,
        candidate: CompletionRuntimeCandidate,
        canWarm: Bool,
        unavailableReason: String?,
        modelDirectoryPath: String,
        applyState: @escaping @MainActor @Sendable (LocalRuntimeState) -> Void
    ) {
        guard canWarm else {
            let reason = unavailableReason ?? "local model runtime is not ready"
            applyState(.unavailable(reason: reason))
            DiagnosticsLog.shared.record(
                "runtime-warm-skipped",
                metadata: [
                    "candidate": candidate.rawValue,
                    "reason": reason,
                    "modelDirectory": modelDirectoryPath
                ]
            )
            return
        }

        applyState(.warming(candidate: candidate))
        let startedAt = Date()
        DiagnosticsLog.shared.record(
            "runtime-warm-start",
            metadata: [
                "candidate": candidate.rawValue,
                "modelDirectory": modelDirectoryPath
            ]
        )

        task?.cancel()
        task = Task { [runtime, candidate, applyState] in
            do {
                try await runtime.warm()
            } catch is CancellationError {
                await MainActor.run {
                    DiagnosticsLog.shared.record(
                        "runtime-warm-cancelled",
                        metadata: [
                            "candidate": candidate.rawValue,
                            "warmMilliseconds": String(Self.elapsedMilliseconds(since: startedAt))
                        ]
                    )
                }
                return
            } catch {
                await MainActor.run {
                    DiagnosticsLog.shared.record(
                        "runtime-warm-failed",
                        metadata: [
                            "candidate": candidate.rawValue,
                            "reason": error.localizedDescription,
                            "warmMilliseconds": String(Self.elapsedMilliseconds(since: startedAt))
                        ]
                    )
                    applyState(.failed(candidate: candidate, reason: error.localizedDescription))
                }
                return
            }

            let state = await runtime.state
            await MainActor.run {
                DiagnosticsLog.shared.record(
                    "runtime-warm-succeeded",
                    metadata: [
                        "candidate": candidate.rawValue,
                        "state": state.statusSummary,
                        "warmMilliseconds": String(Self.elapsedMilliseconds(since: startedAt))
                    ]
                )
                applyState(state)
            }
        }
    }

    func cancel() {
        task?.cancel()
    }

    private static func elapsedMilliseconds(since startedAt: Date) -> Int {
        max(0, Int(Date().timeIntervalSince(startedAt) * 1_000))
    }
}
