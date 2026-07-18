import AutocompleteLabCore
import Foundation

@MainActor
struct SuggestionRequestExecutionHostDependencies {
    let scheduler: SuggestionRequestScheduler
    let suggestionOrchestrator: SuggestionOrchestrator
    let handlePartial: @MainActor @Sendable (CompletionSuggestion, SuggestionModelResultInput) -> Void
    let handleFinal: @MainActor @Sendable (CompletionSuggestion?, SuggestionModelResultInput) -> Void
    let handleFailure: @MainActor @Sendable (SuggestionModelResultInput) -> Void
}

/// Owns delayed model execution and forwards each lifecycle result to its policy/presentation
/// host. It does not decide whether a result is useful or how native UI is rendered.
@MainActor
final class SuggestionRequestExecutionHost {
    private let dependencies: SuggestionRequestExecutionHostDependencies

    init(dependencies: SuggestionRequestExecutionHostDependencies) {
        self.dependencies = dependencies
    }

    func schedule(input: SuggestionModelResultInput) {
        let suggestionOrchestrator = dependencies.suggestionOrchestrator
        let handlePartial = dependencies.handlePartial
        let handleFinal = dependencies.handleFinal
        let handleFailure = dependencies.handleFailure
        dependencies.scheduler.schedule(
            suggestionID: input.suggestionID,
            delayMilliseconds: input.requestSchedule.scheduledDelayMilliseconds
        ) {
            do {
                let suggestion = try await suggestionOrchestrator.suggestion(
                    for: input.request,
                    onPartialSuggestion: { partialSuggestion in
                        Task { @MainActor in
                            handlePartial(partialSuggestion, input)
                        }
                    }
                )
                await MainActor.run {
                    handleFinal(suggestion, input)
                }
            } catch {
                await MainActor.run {
                    handleFailure(input)
                }
            }
        }
    }
}
