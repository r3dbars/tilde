import TildeCore
import Foundation

/// One deterministic streaming completion request to the app-owned llama
/// server. Partials are surfaced only at complete-word boundaries; callers
/// never see a dangling token. The final cleaner still owns every safety,
/// repetition, and prefix decision.
final class LlamaCompletionEngine: @unchecked Sendable {
    /// A llama.cpp `stream:true` line can omit `content` on its terminal
    /// timing frame, so it has a looser shape than a final response.
    struct StreamTimings: Decodable {
        let promptN: Int?
        let predictedN: Int?
        let cacheN: Int?

        enum CodingKeys: String, CodingKey {
            case promptN = "prompt_n"
            case predictedN = "predicted_n"
            case cacheN = "cache_n"
        }
    }

    struct StreamTokenAlternative: Decodable {
        let prob: Double?
        let logprob: Double?

        var resolvedProbability: Double? {
            if let prob, prob.isFinite, (0.0...1.0).contains(prob) {
                return prob
            }
            if let logprob, logprob.isFinite, logprob <= 0.0 {
                return exp(logprob)
            }
            return nil
        }
    }

    struct StreamTokenProbabilityEntry: Decodable {
        let token: String?
        let tokStr: String?
        let prob: Double?
        let logprob: Double?
        let topLogprobs: [StreamTokenAlternative]?
        let topProbs: [StreamTokenAlternative]?
        let probs: [StreamTokenAlternative]?

        enum CodingKeys: String, CodingKey {
            case token, prob, logprob, probs
            case tokStr = "tok_str"
            case topLogprobs = "top_logprobs"
            case topProbs = "top_probs"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            token = try? c.decodeIfPresent(String.self, forKey: .token)
            tokStr = try? c.decodeIfPresent(String.self, forKey: .tokStr)
            prob = try? c.decodeIfPresent(Double.self, forKey: .prob)
            logprob = try? c.decodeIfPresent(Double.self, forKey: .logprob)
            // Decode alternative lists lossily so any schema shift fails open
            // without losing the emitted token's own probability.
            topLogprobs = try? c.decodeIfPresent([StreamTokenAlternative].self, forKey: .topLogprobs)
            topProbs = try? c.decodeIfPresent([StreamTokenAlternative].self, forKey: .topProbs)
            probs = try? c.decodeIfPresent([StreamTokenAlternative].self, forKey: .probs)
        }

        var pieceText: String? {
            token ?? tokStr
        }

        /// Resolves the emitted token's own probability strictly without ever
        /// falling back to `top_logprobs[0]` (which would replace a null/`-inf`
        /// probability with an unchosen token's high probability).
        var resolvedProbability: Double? {
            if let prob, prob.isFinite, (0.0...1.0).contains(prob) {
                return prob
            }
            if let logprob, logprob.isFinite, logprob <= 0.0 {
                return exp(logprob)
            }
            return nil
        }

        /// Strictly text-free top-k distribution metrics (top-1 margin, local
        /// entropy, runner-up ratio), or `nil` when fewer than 2 valid
        /// alternatives are present.
        var distributionMetrics: (top1Margin: Double, entropy: Double, runnerUpRatio: Double)? {
            let candidates = topLogprobs ?? topProbs ?? probs
            guard let candidates, candidates.count >= 2 else { return nil }
            let values = candidates.compactMap(\.resolvedProbability)
            guard values.count == candidates.count else { return nil }
            return StreamedTokenProbability.distributionMetrics(fromAlternativeProbabilities: values)
        }

        func toStreamedTokenProbability(fallbackPiece: String? = nil) -> StreamedTokenProbability? {
            guard let prob = resolvedProbability else { return nil }
            let resolvedPiece = (pieceText?.isEmpty == false ? pieceText : nil) ?? fallbackPiece
            guard let resolvedPiece, !resolvedPiece.isEmpty else { return nil }
            let metrics = distributionMetrics
            return StreamedTokenProbability(
                piece: resolvedPiece,
                probability: prob,
                top1Margin: metrics?.top1Margin,
                entropy: metrics?.entropy,
                runnerUpRatio: metrics?.runnerUpRatio
            )
        }
    }

    struct StreamFrame: Decodable {
        let content: String?
        let stop: Bool?
        let stoppedEOS: Bool?
        let stoppedLimit: Bool?
        let stoppedWord: Bool?
        let tokensPredicted: Int?
        let timings: StreamTimings?
        let completionProbabilities: [StreamTokenProbabilityEntry]?

        enum CodingKeys: String, CodingKey {
            case content, stop, timings
            case stoppedEOS = "stopped_eos"
            case stoppedLimit = "stopped_limit"
            case stoppedWord = "stopped_word"
            case tokensPredicted = "tokens_predicted"
            case completionProbabilities = "completion_probabilities"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            content = try c.decodeIfPresent(String.self, forKey: .content)
            stop = try c.decodeIfPresent(Bool.self, forKey: .stop)
            stoppedEOS = try c.decodeIfPresent(Bool.self, forKey: .stoppedEOS)
            stoppedLimit = try c.decodeIfPresent(Bool.self, forKey: .stoppedLimit)
            stoppedWord = try c.decodeIfPresent(Bool.self, forKey: .stoppedWord)
            tokensPredicted = try c.decodeIfPresent(Int.self, forKey: .tokensPredicted)
            timings = try? c.decodeIfPresent(StreamTimings.self, forKey: .timings)
            // Decode probability telemetry lossily so any schema shift fails
            // open instead of aborting/restarting llama-server.
            completionProbabilities = try? c.decodeIfPresent(
                [StreamTokenProbabilityEntry].self,
                forKey: .completionProbabilities
            )
        }

        var hasRecognizedField: Bool {
            content != nil || stop != nil || stoppedEOS != nil || stoppedLimit != nil
                || stoppedWord != nil || tokensPredicted != nil
        }
    }

    private let baseURL: URL
    private let apiKey: String?
    private let cleaner: CompletionOutputCleaner
    private let diagnostics: DiagnosticsLog
    private let productProfile: TildeProductProfile
    private let transport: any LlamaCompletionStreamingTransport
    private let tokenBiasCache: LlamaTokenBiasCache?
    private let quietGateOverride: SuggestionQuietGate.Configuration?
    /// Owner settings shared with the input method. Only the H01 harness
    /// reads them, and only in the Model Preview profile.
    private let experimentDefaults: (any H01ExperimentDefaults)?

    init(
        baseURL: URL,
        apiKey: String? = nil,
        diagnostics: DiagnosticsLog = .shared,
        transport: any LlamaCompletionStreamingTransport = URLSessionLlamaCompletionTransport(),
        tokenBiasCache: LlamaTokenBiasCache? = nil,
        productProfile: TildeProductProfile = .current,
        quietGateOverride: SuggestionQuietGate.Configuration? = nil,
        experimentDefaults: (any H01ExperimentDefaults)? = UserDefaults(
            suiteName: PersonalHistorySettingsContract.keyboardSuiteName
        )
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.diagnostics = diagnostics
        self.transport = transport
        self.tokenBiasCache = tokenBiasCache
        self.productProfile = productProfile
        self.quietGateOverride = quietGateOverride
        self.experimentDefaults = experimentDefaults
        cleaner = CompletionOutputCleaner(maxVisibleWords: productProfile.maximumVisibleWords)
    }

    private var activeQuietGate: SuggestionQuietGate.Configuration? {
        quietGateOverride ?? productProfile.quietGate
    }

    /// The profile's own cleaner unless the disabled-by-default H01 harness
    /// is on in a Model Preview build and the input method declared an arm.
    func visibleCleaner(forExperimentArm arm: String?) -> CompletionOutputCleaner {
        guard let cap = H01BlockRandomization.visibleWordCap(
            requestedArm: arm,
            profile: productProfile,
            defaults: experimentDefaults
        ), cap != productProfile.maximumVisibleWords else { return cleaner }
        return CompletionOutputCleaner(maxVisibleWords: cap)
    }

    func suggestion(
        textBeforeCursor: String,
        appBundleIdentifier: String?
    ) async throws -> CompletionSuggestion? {
        try await suggestion(
            textBeforeCursor: textBeforeCursor,
            appBundleIdentifier: appBundleIdentifier,
            scene: nil
        )
    }

    func suggestion(
        textBeforeCursor: String,
        appBundleIdentifier: String?,
        scene: ScreenScene.Scene?
    ) async throws -> CompletionSuggestion? {
        try await suggestion(
            textBeforeCursor: textBeforeCursor,
            appBundleIdentifier: appBundleIdentifier,
            scene: scene,
            experimentArm: nil,
            onPartialSuggestion: { _, _ in }
        )
    }

    /// `onPartialSuggestion` runs off the main actor, inside the stream loop,
    /// each time a longer complete-word prefix passes the cleaner. Callers
    /// hop to their own actor and re-check their ticket.
    func suggestion(
        textBeforeCursor: String,
        appBundleIdentifier: String?,
        scene: ScreenScene.Scene?,
        experimentArm: String? = nil,
        onPartialSuggestion: @escaping @Sendable (CompletionSuggestion, Int) -> Void
    ) async throws -> CompletionSuggestion? {
        try await decide(
            textBeforeCursor: textBeforeCursor,
            appBundleIdentifier: appBundleIdentifier,
            scene: scene,
            experimentArm: experimentArm,
            onPartialSuggestion: onPartialSuggestion
        ).suggestion
    }

    /// One request's answer and the reason behind it: what the writer may
    /// be shown, why not when nothing, whether the model produced text at
    /// all, and how long it took. The socket host turns this into the
    /// response receipt; `suggestion(...)` above keeps the plain shape.
    struct Decision: Sendable {
        let suggestion: CompletionSuggestion?
        let reason: SuggestionDecisionReason
        let generated: Bool
        let generatorMilliseconds: Int?
        let firstStableWordMilliseconds: Int?

        static func silent(_ reason: SuggestionDecisionReason) -> Decision {
            Decision(
                suggestion: nil,
                reason: reason,
                generated: false,
                generatorMilliseconds: nil,
                firstStableWordMilliseconds: nil
            )
        }
    }

    func decide(
        textBeforeCursor: String,
        appBundleIdentifier: String?,
        scene: ScreenScene.Scene?,
        experimentArm: String? = nil,
        personalBiasTerms: [WeightedBiasTerm] = [],
        personalVoiceScaffold: String? = nil,
        personalPhraseMatch: PersonalPhraseMatch? = nil,
        onPartialSuggestion: @escaping @Sendable (CompletionSuggestion, Int) -> Void
    ) async throws -> Decision {
        let startedAt = ProcessInfo.processInfo.systemUptime
        let cleaner = visibleCleaner(forExperimentArm: experimentArm)
        if let reason = SceneSuggestionPolicy.suppressionReason(
            scene: scene,
            textBeforeCursor: textBeforeCursor,
            options: productProfile.sceneSuggestionOptions
        ) {
            diagnostics.record(
                "suggestion-suppressed",
                metadata: ["reason": reason.rawValue]
            )
            return .silent(SuggestionDecisionReason(scene: reason))
        }
        // Everything this request's context implies for the cleaner, the
        // echo check, and the grounding check — derived once, here, and then
        // handed to every streamed partial and to the final pass. None of it
        // depends on model output, and a request can produce a dozen
        // partials.
        let prepared = PreparedCompletionContext(
            textBeforeCursor: textBeforeCursor,
            scene: scene,
            profile: productProfile
        )
        let isMidWord = RawContinuationPrompt.endsMidWord(textBeforeCursor)
        let register = ContinuationRegister.following(scene: scene, hostBundleIdentifier: appBundleIdentifier)
        let recipe = RawContinuationPrompt(
            textBeforeCursor: textBeforeCursor,
            register: register,
            scene: scene,
            includesWindowTitle: productProfile.includesWindowTitleInScene,
            customScaffold: personalVoiceScaffold
        )
        guard !recipe.prompt.isEmpty else { return .silent(.emptyPrompt) }

        let prompt = Self.promptByAddingIntentFutures(
            to: recipe.prompt,
            register: register,
            scene: scene,
            textBeforeCursor: textBeforeCursor
        )

        let sceneBiasTerms = DecodeBiasPolicy.extractSceneTerms(scene: scene, typed: prepared.typed)
        let mergedBiasTerms = DecodeBiasPolicy.merge(
            scene: sceneBiasTerms,
            personal: personalBiasTerms,
            typed: prepared.typed
        )
        let logitBiasEntries: [LlamaTokenBiasCache.TokenBiasEntry] = if let tokenBiasCache, !mergedBiasTerms.isEmpty {
            await tokenBiasCache.logitBiasEntries(for: mergedBiasTerms)
        } else {
            []
        }

        var body: [String: Any] = [
            "prompt": prompt,
            "n_predict": productProfile == .production
                ? register.generatedTokenBudget
                : productProfile.generatedTokenBudget,
            "temperature": productProfile.completionTemperature,
            "cache_prompt": true,
            "n_probs": 3,
            "stop": ["\n"],
            "stream": true,
        ]
        if !logitBiasEntries.isEmpty {
            body["logit_bias"] = logitBiasEntries.map { [$0.tokenID, $0.weight] as [Any] }
        }
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("completion"))
        urlRequest.httpMethod = "POST"
        urlRequest.cachePolicy = .reloadIgnoringLocalCacheData
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        if let apiKey {
            urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        urlRequest.timeoutInterval = 8

        let stream = try await transport.open(request: urlRequest)
        guard stream.statusCode == 200 else {
            stream.cancel()
            throw URLError(.badServerResponse)
        }

        var firstTokenMilliseconds: Int?
        var firstPartialMilliseconds: Int?
        var settledMilliseconds: Int?
        var streamTimings: StreamTimings?
        var stoppedAtCap = false
        var streamedTokens: [StreamedTokenProbability] = []
        let content = try await withTaskCancellationHandler {
            var rawOutput = ""
            var lastPartialVisibleText = ""
            var sawCompletionFrame = false
            // One decoder for the whole stream. Building a JSONDecoder per SSE
            // frame meant one allocation per token; it stays local to this
            // closure so nothing crosses an isolation boundary.
            let frameDecoder = JSONDecoder()
            for try await line in stream.lines {
                guard line.hasPrefix("data:") else { continue }
                let json = line.dropFirst("data:".count).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !json.isEmpty, json != "[DONE]" else { continue }
                let frame: StreamFrame
                do {
                    frame = try frameDecoder.decode(StreamFrame.self, from: Data(json.utf8))
                } catch {
                    throw URLError(.cannotParseResponse)
                }
                guard frame.hasRecognizedField else { throw URLError(.cannotParseResponse) }
                sawCompletionFrame = true
                if let timings = frame.timings {
                    streamTimings = timings
                }
                if let piece = frame.content, !piece.isEmpty {
                    if firstTokenMilliseconds == nil {
                        firstTokenMilliseconds = Self.milliseconds(since: startedAt)
                    }
                    if let entries = frame.completionProbabilities, !entries.isEmpty {
                        if entries.count == 1, let entry = entries.first,
                           let tokenProb = entry.toStreamedTokenProbability(fallbackPiece: piece) {
                            streamedTokens.append(tokenProb)
                        } else {
                            // Multi-token frames (e.g. --spec-type ngram-simple):
                            // record every token's own text, probability, and top-k metrics.
                            var appendedAny = false
                            for entry in entries {
                                guard let tokenProb = entry.toStreamedTokenProbability() else { continue }
                                streamedTokens.append(tokenProb)
                                appendedAny = true
                            }
                            if !appendedAny, let entry = entries.first,
                               let tokenProb = entry.toStreamedTokenProbability(fallbackPiece: piece) {
                                streamedTokens.append(tokenProb)
                            }
                        }
                    }
                    // llama.cpp emits token deltas. Always append: a repeated
                    // token can legitimately equal the text so far (" is" + " is").
                    rawOutput += piece
                    if StableStreamPrefix.mayAdvanceBoundary(piece) {
                        let stable = stablePartial(
                            rawOutput,
                            recipe: recipe,
                            context: prepared,
                            cleaner: cleaner,
                            hasLogitBias: !logitBiasEntries.isEmpty,
                            isMidWord: isMidWord,
                            textBeforeCursor: textBeforeCursor,
                            register: register,
                            scene: scene,
                            personalBiasTerms: personalBiasTerms,
                            personalPhraseMatch: personalPhraseMatch,
                            streamedTokens: streamedTokens
                        )
                        if let partial = stable.suggestion, partial.visibleText != lastPartialVisibleText {
                            if firstPartialMilliseconds == nil {
                                firstPartialMilliseconds = Self.milliseconds(since: startedAt)
                            }
                            lastPartialVisibleText = partial.visibleText
                            // The second value is the time to the FIRST stable
                            // word, repeated on every partial, so a keyboard
                            // that shows a partial and then loses the terminal
                            // line still records the timing it saw.
                            onPartialSuggestion(partial, firstPartialMilliseconds ?? Self.milliseconds(since: startedAt))
                        }
                        // Everything the display cap can show has arrived, or
                        // confidence collapsed / a repeated nudged word trimmed
                        // the tail, or the output is already rejected. Stop
                        // paying for wasted tail tokens.
                        if stable.settled {
                            settledMilliseconds = Self.milliseconds(since: startedAt)
                            stoppedAtCap = true
                            stream.cancel()
                            break
                        }
                    }
                }
                if frame.stop == true { break }
            }
            guard sawCompletionFrame else { throw URLError(.cannotParseResponse) }
            return rawOutput
        } onCancel: {
            stream.cancel()
        }

        let normalized = recipe.normalizedContinuation(content)
        let clean = cleaner.cleanWithReason(normalized, in: prepared.typed)
        var suggestion = clean.suggestion.map { cleaned -> CompletionSuggestion in
            let deduped: CompletionSuggestion
            if !logitBiasEntries.isEmpty {
                let trimmed = DecodeBiasPolicy.trimRepeatedContentWord(cleaned.visibleText)
                deduped = trimmed != cleaned.visibleText && !trimmed.trimmingCharacters(in: .whitespaces).isEmpty
                    ? CompletionSuggestion(text: trimmed, maxVisibleWords: productProfile.maximumVisibleWords)
                    : cleaned
            } else {
                deduped = cleaned
            }
            return WordConfidenceTruncator.trim(suggestion: deduped, tokens: streamedTokens)
        }
        var rejectionReason = clean.rejectionReason.map { String(describing: $0) }
        var decisionReason: SuggestionDecisionReason = clean.rejectionReason.map(
            SuggestionDecisionReason.init(cleaner:)
        ) ?? .shown
        if let candidate = suggestion,
           isMidWord,
           candidate.visibleText.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
            suggestion = nil
            rejectionReason = "emptyOutput"
            decisionReason = .emptyOutput
        }
        if let candidate = suggestion {
            if let quietGate = activeQuietGate, quietGate.enabled {
                let phraseAgreement = personalPhraseMatch?.agreement(with: candidate.visibleText)
                let gateDecision = SuggestionQuietGate.evaluate(
                    suggestion: candidate,
                    tokens: streamedTokens,
                    textBeforeCursor: textBeforeCursor,
                    register: register,
                    scene: scene,
                    personalBiasTerms: personalBiasTerms,
                    replyCueAnchoredToCurrentSentence: productProfile.decisionPolicy.replyCueAnchoredToCurrentSentence,
                    configuration: quietGate,
                    personalPhraseAgreement: phraseAgreement?.agreed ?? false,
                    personalPhraseLogSupport: phraseAgreement?.logSupport ?? 0.0
                )
                if !gateDecision.allow {
                    suggestion = nil
                    rejectionReason = "lowConfidence"
                    decisionReason = .lowConfidence
                }
            } else if WordConfidenceTruncator.isFirstWordBelowFloor(
                suggestion: candidate,
                tokens: streamedTokens,
                minimumProbability: productProfile.minimumFirstWordProbability
            ) {
                suggestion = nil
                rejectionReason = "lowConfidence"
                decisionReason = .lowConfidence
            }
        }
        if let candidate = suggestion,
           SceneEchoPolicy.isEcho(candidate.visibleText, in: prepared.sceneEcho) {
            suggestion = nil
            rejectionReason = "replaysScene"
            decisionReason = .sceneEcho
        }
        if let candidate = suggestion,
           FactualGroundingPolicy.containsUnsupportedFact(
               candidate.visibleText,
               in: prepared.grounding
           ) {
            suggestion = nil
            rejectionReason = "unsupportedFact"
            decisionReason = .unsupportedFact
        }

        if suggestion == nil, !content.isEmpty, let reason = rejectionReason {
            diagnostics.record("llama-suggestion-rejected", metadata: [
                "reason": reason,
            ])
        }
        let totalMilliseconds = Self.milliseconds(since: startedAt)
        var timing = [
            "totalMilliseconds": String(totalMilliseconds),
            "cleanedChars": String(suggestion?.visibleText.count ?? 0),
        ]
        if let firstTokenMilliseconds {
            timing["firstTokenMilliseconds"] = String(firstTokenMilliseconds)
        }
        if let firstPartialMilliseconds {
            timing["firstPartialMilliseconds"] = String(firstPartialMilliseconds)
        }
        if let settledMilliseconds {
            timing["settledMilliseconds"] = String(settledMilliseconds)
        }
        if let promptTokens = streamTimings?.promptN {
            timing["promptTokens"] = String(promptTokens)
        }
        if let cachedTokens = streamTimings?.cacheN {
            timing["cachedTokens"] = String(cachedTokens)
        }
        if let predictedTokens = streamTimings?.predictedN {
            timing["predictedTokens"] = String(predictedTokens)
        }
        timing["stoppedAtCap"] = String(stoppedAtCap)
        diagnostics.record("llama-completion-timing", metadata: timing)
        return Decision(
            suggestion: suggestion,
            reason: decisionReason,
            generated: !content.isEmpty,
            generatorMilliseconds: totalMilliseconds,
            firstStableWordMilliseconds: firstPartialMilliseconds
        )
    }

    /// The chat register gets no hint: on the 2026-08-23 synthetic eval the
    /// numeric label line placed before "Continuation:" lowered keyword hit
    /// rate (46% -> 39%) and produced the only empty outputs; the
    /// conversation-aware scaffold carries the intent instead.
    /// Monotonic, and clamped. `Date()` is wall-clock: an NTP correction or a
    /// manual clock change mid-request could produce a negative duration,
    /// which `latency_report.py`'s float parser would accept and fold
    /// straight into the percentile arrays these budgets depend on.
    /// `systemUptime` cannot step backwards, matching what
    /// `GhostInputController.slowKeyTiming` already does.
    private static func milliseconds(since start: TimeInterval) -> Int {
        max(0, Int(((ProcessInfo.processInfo.systemUptime - start) * 1_000).rounded()))
    }

    /// A partial is the cleaned continuation cut back to its last complete
    /// word. It goes through the same cleaner as the final, so anything the
    /// final would reject outright is never shown early either.
    ///
    /// `settled` reports the cleaner's verdict on whether more raw output
    /// could still change the visible text (see `CompletionCleanOutcome`). It
    /// is independent of whether a partial is shown: an echo- or
    /// grounding-rejected prefix still settles once the cap has bitten,
    /// because the final pass judges the same capped text.
    ///
    /// It takes the request's `PreparedCompletionContext` rather than the
    /// context string and the scene: everything all three checks derive from
    /// those is already computed, so a partial cannot re-tokenize the
    /// context or re-normalize the scene no matter how many partials arrive.
    private func stablePartial(
        _ rawOutput: String,
        recipe: RawContinuationPrompt,
        context: PreparedCompletionContext,
        cleaner: CompletionOutputCleaner,
        hasLogitBias: Bool = false,
        isMidWord: Bool = false,
        textBeforeCursor: String = "",
        register: ContinuationRegister = .prose,
        scene: ScreenScene.Scene? = nil,
        personalBiasTerms: [WeightedBiasTerm] = [],
        personalPhraseMatch: PersonalPhraseMatch? = nil,
        streamedTokens: [StreamedTokenProbability] = []
    ) -> (suggestion: CompletionSuggestion?, settled: Bool) {
        let outcome = cleaner.clean(
            recipe.normalizedContinuation(rawOutput),
            in: context.typed
        )
        guard let cleaned = outcome.result.suggestion else {
            return (nil, outcome.visibleTextIsSettled)
        }
        guard !SceneEchoPolicy.isEcho(
            cleaned.visibleText,
            in: context.sceneEcho
        ) else { return (nil, true) }
        guard let prefix = StableStreamPrefix.prefix(of: cleaned.visibleText) else {
            return (nil, outcome.visibleTextIsSettled)
        }
        var candidateText = prefix
        var tailTrimmed = false
        if hasLogitBias {
            let deduped = DecodeBiasPolicy.trimRepeatedContentWord(candidateText)
            if deduped != candidateText {
                tailTrimmed = true
                candidateText = deduped
            }
        }
        let trimmedCandidate = candidateText.trimmingCharacters(in: .whitespaces)
        guard !trimmedCandidate.isEmpty else {
            return (nil, outcome.visibleTextIsSettled || tailTrimmed)
        }
        if isMidWord, trimmedCandidate.count < 2 {
            return (nil, outcome.visibleTextIsSettled || tailTrimmed)
        }
        var suggestion = CompletionSuggestion(
            text: candidateText,
            maxVisibleWords: productProfile.maximumVisibleWords
        )
        if !streamedTokens.isEmpty {
            if let quietGate = activeQuietGate, quietGate.enabled {
                if quietGate.hardFirstWordFloor > 0,
                   WordConfidenceTruncator.isFirstWordBelowFloor(
                       suggestion: suggestion,
                       tokens: streamedTokens,
                       minimumProbability: quietGate.hardFirstWordFloor
                   ) {
                    return (nil, true)
                }
                let phraseAgreement = personalPhraseMatch?.agreement(with: suggestion.visibleText)
                let gateDecision = SuggestionQuietGate.evaluate(
                    suggestion: suggestion,
                    tokens: streamedTokens,
                    textBeforeCursor: textBeforeCursor,
                    register: register,
                    scene: scene,
                    personalBiasTerms: personalBiasTerms,
                    replyCueAnchoredToCurrentSentence: productProfile.decisionPolicy.replyCueAnchoredToCurrentSentence,
                    configuration: quietGate,
                    personalPhraseAgreement: phraseAgreement?.agreed ?? false,
                    personalPhraseLogSupport: phraseAgreement?.logSupport ?? 0.0
                )
                if !gateDecision.allow {
                    // Hold back displaying an unapproved partial without
                    // prematurely cancelling the stream if later words could
                    // lift the score above threshold.
                    return (nil, outcome.visibleTextIsSettled)
                }
            } else if WordConfidenceTruncator.isFirstWordBelowFloor(
                suggestion: suggestion,
                tokens: streamedTokens,
                minimumProbability: productProfile.minimumFirstWordProbability
            ) {
                // Weak first word: stay silent and cancel remaining tail tokens immediately.
                return (nil, true)
            }
            // Mid-stream: only trim truly collapsed words (< 0.04), never
            // short healthy connectors like "to" or "the" that lead into a
            // confident 5-8 word clause. Full E_n trimming runs on final settle.
            let collapseCheck = WordConfidenceTruncator.trimCollapsedTail(
                suggestion: suggestion,
                tokens: streamedTokens
            )
            if collapseCheck.collapsed {
                tailTrimmed = true
                suggestion = collapseCheck.suggestion
            }
        }
        // The partial is what the writer actually sees first, so it must clear
        // the same grounding bar as the final — judged on the revealed prefix,
        // which is the text that would assert the fact.
        guard !FactualGroundingPolicy.containsUnsupportedFact(
            suggestion.visibleText,
            in: context.grounding
        ) else { return (nil, outcome.visibleTextIsSettled || tailTrimmed) }
        // Do NOT run `WordConfidenceTruncator.trim` mid-stream: a short
        // connector like "to" or "the" at word 2 temporarily lowers prefix
        // utility before the rest of a 5-8 word clause arrives, prematurely
        // killing the stream into a 1-word stub. Final trimming runs once the
        // full clause finishes; mid-stream we only cut on true collapse (<0.04)
        // or a completed sentence (2+ words ending in . ! ?).
        let collapsedTail = WordConfidenceTruncator.shouldStopStreamingEarly(tokens: streamedTokens)
        let sentenceEnded = suggestion.visibleText.split(whereSeparator: \.isWhitespace).count >= 2
            && (suggestion.visibleText.trimmingCharacters(in: .whitespaces).last.map { ".!?".contains($0) } == true)
        return (suggestion, outcome.visibleTextIsSettled || tailTrimmed || collapsedTail || sentenceEnded)
    }

    static func promptByAddingIntentFutures(
        to prompt: String,
        register: ContinuationRegister,
        scene: ScreenScene.Scene?,
        textBeforeCursor: String
    ) -> String {
        guard register != .chat else { return prompt }
        let futures = intentFutures(scene: scene, textBeforeCursor: textBeforeCursor)
        let summary = IntentFuturesPlanner.promptHint(for: futures)
        guard !summary.isEmpty,
              let marker = prompt.range(of: "Continuation:", options: .backwards)
        else { return prompt }
        let hint = "Likely response directions: \(summary)\n"
        var result = prompt
        result.insert(contentsOf: hint, at: marker.lowerBound)
        return result
    }

    /// Blends the scene-only prior (what Tilde already believed about this
    /// conversation before the user typed anything this turn) with the
    /// live, text-conditioned read — see `IntentFutureFusion`. This used to
    /// run through `IntentFutureCache`, a process-global lock-guarded cache
    /// keyed on the current scene; but `IntentFuturesPlanner.futures` is a
    /// pure, cheap function of `scene` alone, so recomputing the prior on
    /// every call produces exactly the value the cache would have served —
    /// the cache added a lock and mutable global state for no measurable
    /// benefit, and its "warm prior" was always discarded the moment the
    /// scene changed anyway. Call the planner directly.
    private static func intentFutures(
        scene: ScreenScene.Scene?,
        textBeforeCursor: String
    ) -> [IntentFuture] {
        guard scene != nil else {
            return IntentFuturesPlanner.futures(scene: nil, textBeforeCursor: textBeforeCursor)
        }
        let prior = IntentFuturesPlanner.futures(scene: scene, textBeforeCursor: "")
        let live = IntentFuturesPlanner.futures(scene: scene, textBeforeCursor: textBeforeCursor)
        return IntentFutureFusion.fuse(prior: prior, live: live)
    }
}
