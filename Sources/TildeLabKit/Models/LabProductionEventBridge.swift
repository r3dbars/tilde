import Foundation
import TildeCore

/// The one way a live production event enters the Lab.
///
/// `TextFreeOnlineEvent` in `TildeCore` is the definition of what production
/// emits. The Lab's richer `LabOnlineExperimentEvent` adds fields only its
/// own synthetic runners fill. Before this bridge, the Lab decoded live lines
/// straight into its own type, so the two definitions could drift apart
/// without any test noticing. Now a live line is decoded strictly as the
/// production type and mapped field by field, with no defaulting: every
/// production field lands on the Lab event unchanged, every Lab-only field
/// stays `nil`, and a production string outside the Lab's vocabulary is an
/// error rather than a silently substituted bucket.
extension LabOnlineExperimentEvent {
    public init(production event: TextFreeOnlineEvent) throws {
        guard let variant = LabOnlineVariant(rawValue: event.variant),
              let appCategory = LabOnlineAppCategory(rawValue: event.appCategory),
              let register = LabOnlineRegister(rawValue: event.register),
              let boundary = LabOnlineBoundary(rawValue: event.boundary),
              let typingSpeed = LabTypingSpeedBucket(rawValue: event.typingSpeedBucket),
              let outcome = LabOnlineInteractionOutcome(rawValue: event.outcome),
              let production = TextFreeCandidateSource(rawValue: event.candidateSourceBucket),
              let lengthBucket = LabCandidateLengthBucket(rawValue: event.candidateLengthBucket)
        else { throw LabOnlineExperimentError.invalidEvent }
        let guardReason: LabDecisionReason?
        if let raw = event.guardReason {
            guard let known = LabDecisionReason(rawValue: raw) else {
                throw LabOnlineExperimentError.invalidEvent
            }
            guardReason = known
        } else {
            guardReason = nil
        }
        self.init(
            id: event.id,
            campaignID: event.campaignID,
            occurredAt: event.occurredAt,
            sessionDigestSHA256: event.sessionDigestSHA256,
            variant: variant,
            appCategory: appCategory,
            register: register,
            boundary: boundary,
            typingSpeedBucket: typingSpeed,
            safeOpportunity: event.safeOpportunity,
            displayed: event.displayed,
            outcome: outcome,
            acceptedCharacters: event.acceptedCharacters,
            replacedCharactersWithin5Seconds: event.replacedCharactersWithin5Seconds,
            nextActionMilliseconds: event.nextActionMilliseconds,
            generatorMilliseconds: event.generatorMilliseconds,
            firstStableWordMilliseconds: event.firstStableWordMilliseconds,
            deadlineMissed: event.deadlineMissed,
            candidateCharacters: event.candidateCharacters,
            championDisagreed: event.championDisagreed,
            guardReason: guardReason,
            crashed: event.crashed,
            timedOut: event.timedOut,
            opportunityCharacters: event.opportunityCharacters,
            generated: event.generated,
            policyHidden: event.policyHidden,
            candidateSourceBucket: LabCandidateSourceBucket(production: production),
            candidateLengthBucket: lengthBucket,
            settledVisibleMilliseconds: event.settledVisibleMilliseconds,
            retentionAt5Seconds: event.retentionAt5Seconds,
            retentionAt30Seconds: event.retentionAt30Seconds,
            retentionAtSegmentClose: event.retentionAtSegmentClose,
            schema: event.schema
        )
    }

    /// One live ledger line, strictly the production schema.
    public static func decodeProductionLine(_ data: Data) throws -> LabOnlineExperimentEvent {
        try LabOnlineExperimentEvent(production: TextFreeOnlineEvent.decodeProductionLine(data))
    }
}
