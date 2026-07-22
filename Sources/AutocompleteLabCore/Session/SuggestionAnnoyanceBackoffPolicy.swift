import Foundation

/// The single session-level annoyance/backoff behavior used by suggestion requests.
///
/// Repetition misses and prefix-family cooldowns have different evidence, but they
/// answer the same product question: should this request stay quiet for a short,
/// decaying interval? Keeping both state machines behind one policy prevents callers
/// from growing a second, uncoordinated cooldown system while preserving their
/// existing thresholds, decay, and privacy-safe metadata.
public struct SuggestionAnnoyanceBackoffPolicy: Equatable, Sendable {
    private var repetitionSuppressor: SuggestionRepetitionSuppressor
    private var prefixFamilyCooldownPolicy: PrefixFamilyCooldownPolicy

    public init(
        repetitionSuppressor: SuggestionRepetitionSuppressor = SuggestionRepetitionSuppressor(),
        prefixFamilyCooldownPolicy: PrefixFamilyCooldownPolicy = PrefixFamilyCooldownPolicy()
    ) {
        self.repetitionSuppressor = repetitionSuppressor
        self.prefixFamilyCooldownPolicy = prefixFamilyCooldownPolicy
    }

    public func shouldSuppressRepetition(
        _ text: String,
        mode: CompletionRequestMode,
        scope: String = "",
        now: Date = Date()
    ) -> Bool {
        repetitionSuppressor.shouldSuppress(text, mode: mode, scope: scope, now: now)
    }

    @discardableResult
    public mutating func recordRepetitionMiss(
        _ text: String,
        mode: CompletionRequestMode?,
        scope: String = "",
        now: Date = Date()
    ) -> SuggestionRepetitionMissRecord? {
        repetitionSuppressor.recordMiss(text, mode: mode, scope: scope, now: now)
    }

    @discardableResult
    public mutating func recordIgnoredRepetition(
        _ text: String,
        mode: CompletionRequestMode?,
        scope: String = "",
        lifetimeMilliseconds: Int? = nil,
        now: Date = Date()
    ) -> SuggestionRepetitionMissRecord? {
        repetitionSuppressor.recordIgnored(
            text,
            mode: mode,
            scope: scope,
            lifetimeMilliseconds: lifetimeMilliseconds,
            now: now
        )
    }

    public mutating func recordRepetitionAcceptance(
        _ text: String,
        mode: CompletionRequestMode?,
        scope: String = ""
    ) {
        repetitionSuppressor.recordAcceptance(text, mode: mode, scope: scope)
    }

    public mutating func prefixCooldownDecision(
        for input: PrefixFamilyCooldownInput,
        now: Date = Date()
    ) -> PrefixFamilyCooldownDecision {
        prefixFamilyCooldownPolicy.decision(for: input, now: now)
    }

    @discardableResult
    public mutating func recordPrefixCooldown(
        _ reason: PrefixFamilyCooldownReason,
        input: PrefixFamilyCooldownInput,
        now: Date = Date()
    ) -> PrefixFamilyCooldown? {
        prefixFamilyCooldownPolicy.record(reason, input: input, now: now)
    }

    public mutating func prefixEagernessAdjustment(
        for input: PrefixFamilyCooldownInput,
        now: Date = Date()
    ) -> PrefixFamilyEagernessAdjustment {
        prefixFamilyCooldownPolicy.eagernessAdjustment(for: input, now: now)
    }

    public mutating func reset() {
        repetitionSuppressor.reset()
        prefixFamilyCooldownPolicy.reset()
    }
}

/// The single decision a request-time quiet check can resolve to. Prefix-family
/// cooldown and annoyance quiet-mode are two independently scored decaying-score
/// gates (different evidence, different state), but callers only ever need to
/// know: proceed, or stay quiet for this one reason. Collapsing them into one
/// decision type keeps the call site from growing a second suppression branch.
public enum RequestQuietDecision: Equatable, Sendable {
    case allowed
    case prefixCooldown(PrefixFamilyCooldown)
    case annoyanceQuiet(QuietMode)

    public var isAllowed: Bool {
        self == .allowed
    }
}
