import Foundation

// MARK: - Voice -> text loop spike
//
// Everything in this file is the throwaway-friendly scaffolding for the
// dictation + inline prediction spike described in
// docs/product/spikes/voice-text-loop.md. It fuses the existing doc-local
// n-gram predictor with an *opt-in*, on-device "recent spoken transcript"
// corpus so a phrase the user only said out loud can still surface as a typed
// suggestion.
//
// It is deliberately isolated: the only change outside this file is the
// additive `spokenContextTexts:` parameter on `DocLocalNGramPhrasePredictor`.
// To discard the spike, delete this file and that one parameter. To graduate
// it, replace `InMemorySpokenTranscriptProvider` with a real, local Transcripted
// reader behind the same `RecentSpokenTranscriptProviding` seam.

// MARK: - Transcripted integration boundary (the protocol seam)

/// Supplies recent *spoken* transcript text for local, on-device prediction.
///
/// This is the single seam SteadyType needs against Transcripted. A graduated
/// implementation would read Transcripted's already-on-device, already-redacted
/// recent transcript buffer and return short, recent snippets. The spike ships
/// only in-memory / fixture stubs, so the prediction path can be exercised with
/// no audio capture, no Transcripted dependency, and nothing to upload.
///
/// Ordering convention: entries are oldest-first, most-recent-last. The
/// doc-local scorer treats text that appears later in a corpus as more recent,
/// so keeping the freshest utterance last lets recency weighting fall out for
/// free.
public protocol RecentSpokenTranscriptProviding: Sendable {
    /// Recent spoken transcript snippets, oldest first. Each entry is one
    /// utterance / segment of locally transcribed speech.
    func recentSpokenContextEntries() -> [String]
}

/// In-memory stub provider. Holds spoken snippets directly — no audio, no
/// Transcripted dependency, no I/O. Used by dev, tests, and the fixture path.
public struct InMemorySpokenTranscriptProvider: RecentSpokenTranscriptProviding {
    public let entries: [String]

    public init(entries: [String]) {
        self.entries = entries
    }

    public init(_ entries: String...) {
        self.entries = entries
    }

    public func recentSpokenContextEntries() -> [String] {
        entries
    }
}

/// Parses a local fixture file's text into spoken transcript entries.
///
/// The app (or a test) reads the fixture file from disk and hands the *contents*
/// here, which keeps file I/O out of pure core. Format is intentionally trivial:
/// one utterance per line; blank lines and lines beginning with `#` are ignored
/// so a fixture can carry comments. See
/// docs/product/spikes/voice-text-loop-sample-transcript.txt.
public enum SpokenTranscriptFixture {
    public static func entries(fromFixtureText text: String) -> [String] {
        text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
    }

    public static func provider(fromFixtureText text: String) -> InMemorySpokenTranscriptProvider {
        InMemorySpokenTranscriptProvider(entries: entries(fromFixtureText: text))
    }
}

// MARK: - Opt-in policy + bounds (the flag)

/// Opt-in policy and bounds for using recent spoken transcripts as a prediction
/// signal.
///
/// Default is OFF. Spoken text is at least as sensitive as typed text, so the
/// spoken corpus must never be consulted unless the user explicitly enabled it.
/// When disabled the prediction path is byte-for-byte identical to today's
/// typed-only behavior.
public struct RecentSpokenContextPolicy: Equatable, Sendable {
    /// Master opt-in. `false` means the spoken corpus is never read.
    public let isEnabled: Bool
    /// Keep only the most recent N entries before matching, to bound how far
    /// back speech can influence a suggestion.
    public let maxEntries: Int
    /// Hard per-entry character cap so a long dictation session cannot grow the
    /// matching corpus without bound.
    public let maxCharactersPerEntry: Int

    public init(
        isEnabled: Bool = false,
        maxEntries: Int = 6,
        maxCharactersPerEntry: Int = 2_000
    ) {
        self.isEnabled = isEnabled
        self.maxEntries = max(0, maxEntries)
        self.maxCharactersPerEntry = max(1, maxCharactersPerEntry)
    }

    /// The default, privacy-preserving state: spoken context is never read.
    public static let disabled = RecentSpokenContextPolicy(isEnabled: false)

    /// Bounded, recency-trimmed spoken context texts, or `[]` when disabled or
    /// when there is no provider. Trimming keeps the most recent entries (the
    /// tail), then caps each entry's length from its tail so the freshest words
    /// survive.
    public func contextTexts(from provider: RecentSpokenTranscriptProviding?) -> [String] {
        guard isEnabled, maxEntries > 0, let provider else {
            return []
        }

        let entries = provider.recentSpokenContextEntries()
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return entries
            .suffix(maxEntries)
            .map { String($0.suffix(maxCharactersPerEntry)) }
    }
}

// MARK: - Fusion predictor (the graduation unit)

/// Spike wrapper that fuses the existing `DocLocalNGramPhrasePredictor` with an
/// opt-in recent spoken corpus.
///
/// This is the whole spike's graduation seam in one type: it owns the flag
/// (`policy`), the Transcripted boundary (`provider`), and the bounding, and it
/// delegates *all* matching to the unchanged doc-local predictor. When the
/// policy is disabled it produces exactly the same selection the bare predictor
/// would.
public struct VoiceContextPhrasePredictor: Sendable {
    public let predictor: DocLocalNGramPhrasePredictor
    public let policy: RecentSpokenContextPolicy
    public let provider: RecentSpokenTranscriptProviding?

    public init(
        predictor: DocLocalNGramPhrasePredictor = DocLocalNGramPhrasePredictor(),
        policy: RecentSpokenContextPolicy = .disabled,
        provider: RecentSpokenTranscriptProviding? = nil
    ) {
        self.predictor = predictor
        self.policy = policy
        self.provider = provider
    }

    public func selection(
        for request: CompletionRequest,
        localContextTexts: [String] = [],
        allowsPromptAppPrediction: Bool = false
    ) -> CommonPhraseContinuationSelection {
        selection(
            for: request.textBeforeCursor,
            localContextTexts: localContextTexts,
            behaviorProfileID: request.behaviorProfileID,
            maxVisibleWords: request.maxVisibleWords,
            allowsPromptAppPrediction: allowsPromptAppPrediction
        )
    }

    public func selection(
        for textBeforeCursor: String,
        localContextTexts: [String] = [],
        behaviorProfileID: AutocompleteBehaviorProfileID?,
        maxVisibleWords: Int = 4,
        allowsPromptAppPrediction: Bool = false
    ) -> CommonPhraseContinuationSelection {
        predictor.selection(
            for: textBeforeCursor,
            localContextTexts: localContextTexts,
            spokenContextTexts: policy.contextTexts(from: provider),
            behaviorProfileID: behaviorProfileID,
            maxVisibleWords: maxVisibleWords,
            allowsPromptAppPrediction: allowsPromptAppPrediction
        )
    }
}
