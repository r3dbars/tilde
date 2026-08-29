import Foundation

public struct LabModelRequest: Sendable {
    public let prompt: String
    public let generation: LabGenerationConfiguration
    public let timeoutSeconds: Double

    public var temperature: Double { generation.temperature }
    public var predictionTokens: Int { generation.predictionTokens }

    public init(
        prompt: String,
        temperature: Double,
        predictionTokens: Int,
        timeoutSeconds: Double
    ) {
        self.prompt = prompt
        generation = LabGenerationConfiguration(
            temperature: temperature,
            predictionTokens: predictionTokens
        )
        self.timeoutSeconds = timeoutSeconds
    }

    public init(
        prompt: String,
        generation: LabGenerationConfiguration,
        timeoutSeconds: Double
    ) {
        self.prompt = prompt
        self.generation = generation
        self.timeoutSeconds = timeoutSeconds
    }
}

public struct LabModelResponse: Equatable, Sendable {
    public let content: String
    public let latencyMilliseconds: Int
    public let firstTokenMilliseconds: Int?
    public let meanTokenProbability: Double?
    public let tokenIDs: [Int]
    public let tokenLogProbabilities: [Double]
    public let tokenProbabilityMargins: [Double]
    public let tokenEntropies: [Double]
    public let stopReason: String?

    public init(
        content: String,
        latencyMilliseconds: Int,
        firstTokenMilliseconds: Int? = nil,
        meanTokenProbability: Double? = nil,
        tokenIDs: [Int] = [],
        tokenLogProbabilities: [Double] = [],
        tokenProbabilityMargins: [Double] = [],
        tokenEntropies: [Double] = [],
        stopReason: String? = nil
    ) {
        self.content = content
        self.latencyMilliseconds = latencyMilliseconds
        self.firstTokenMilliseconds = firstTokenMilliseconds
        self.meanTokenProbability = meanTokenProbability
        self.tokenIDs = tokenIDs
        self.tokenLogProbabilities = tokenLogProbabilities
        self.tokenProbabilityMargins = tokenProbabilityMargins
        self.tokenEntropies = tokenEntropies
        self.stopReason = stopReason
    }
}

public enum LabCompletionError: Error, LocalizedError, Sendable {
    case nonLoopbackEndpoint
    case timeout
    case protocolFailure

    public var errorDescription: String? {
        switch self {
        case .nonLoopbackEndpoint: "Tilde Lab refuses a non-loopback inference endpoint."
        case .timeout: "The local model request timed out."
        case .protocolFailure: "The local model server returned an invalid response."
        }
    }
}

public protocol LabCompletionClient: Sendable {
    var workerIndex: Int { get }
    func complete(_ request: LabModelRequest) async throws -> LabModelResponse
}

public final class LabHTTPCompletionClient: LabCompletionClient, @unchecked Sendable {
    public let workerIndex: Int

    private let completionURL: URL
    private let session: URLSession
    private let maximumResponseBytes = 1_048_576

    public init(baseURL: URL, workerIndex: Int) throws {
        guard let host = baseURL.host,
              host == "127.0.0.1" || host == "localhost" || host == "::1" else {
            throw LabCompletionError.nonLoopbackEndpoint
        }
        self.workerIndex = workerIndex
        completionURL = baseURL.appendingPathComponent("completion")
        let configuration = URLSessionConfiguration.ephemeral
        configuration.connectionProxyDictionary = [:]
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.waitsForConnectivity = false
        session = URLSession(configuration: configuration)
    }

    public func complete(_ request: LabModelRequest) async throws -> LabModelResponse {
        let body = requestBody(request)
        var urlRequest = URLRequest(url: completionURL)
        urlRequest.httpMethod = "POST"
        urlRequest.cachePolicy = .reloadIgnoringLocalCacheData
        urlRequest.timeoutInterval = request.timeoutSeconds
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let started = ContinuousClock.now
        do {
            switch request.generation.requestMode {
            case .finalResponse:
                return try await completeFinal(urlRequest, request: request, started: started)
            case .productionStreaming:
                return try await completeStreaming(urlRequest, request: request, started: started)
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as LabCompletionError {
            throw error
        } catch let error as URLError where error.code == .timedOut {
            throw LabCompletionError.timeout
        } catch {
            throw LabCompletionError.protocolFailure
        }
    }

    func requestBody(_ request: LabModelRequest) -> [String: Any] {
        let generation = request.generation
        var body: [String: Any] = [
            "prompt": request.prompt,
            "n_predict": generation.predictionTokens,
            "temperature": generation.temperature,
            "top_k": generation.topK,
            "top_p": generation.topP,
            "min_p": generation.minP,
            "typical_p": generation.typicalP,
            "repeat_last_n": generation.repeatLastTokens,
            "repeat_penalty": generation.repeatPenalty,
            "presence_penalty": generation.presencePenalty,
            "frequency_penalty": generation.frequencyPenalty,
            "seed": generation.seed,
            "cache_prompt": generation.cachePrompt,
            "stream": generation.requestMode == .productionStreaming,
            "samplers": generation.advanced.parsedSamplerOrder,
            "top_n_sigma": generation.advanced.topNSigma,
            "xtc_probability": generation.advanced.xtcProbability,
            "xtc_threshold": generation.advanced.xtcThreshold,
            "dry_multiplier": generation.advanced.dryMultiplier,
            "dry_base": generation.advanced.dryBase,
            "dry_allowed_length": generation.advanced.dryAllowedLength,
            "dynatemp_range": generation.advanced.dynamicTemperatureRange,
            "dynatemp_exponent": generation.advanced.dynamicTemperatureExponent,
            "mirostat": generation.advanced.mirostatMode,
            "mirostat_tau": generation.advanced.mirostatTau,
            "mirostat_eta": generation.advanced.mirostatEta,
            "ignore_eos": generation.advanced.ignoreEndOfSequence,
        ]
        // llama-server's CLI uses -1 for its DRY history default, while the
        // completion JSON schema accepts only non-negative explicit values.
        // Omitting the field preserves that server default.
        if generation.advanced.dryPenaltyLastN >= 0 {
            body["dry_penalty_last_n"] = generation.advanced.dryPenaltyLastN
        }
        if generation.stopRule == .newline { body["stop"] = ["\n"] }
        if generation.probabilityCount > 0 { body["n_probs"] = generation.probabilityCount }
        if generation.advanced.grammarMode == .json {
            body["json_schema"] = ["type": "object"]
        }
        if !generation.advanced.logitBiasRules.isEmpty,
           let data = generation.advanced.logitBiasRules.data(using: .utf8),
           let value = try? JSONSerialization.jsonObject(with: data) {
            body["logit_bias"] = value
        }
        return body
    }

    private func completeFinal(
        _ urlRequest: URLRequest,
        request: LabModelRequest,
        started: ContinuousClock.Instant
    ) async throws -> LabModelResponse {
        let (data, response) = try await session.data(for: urlRequest)
        guard !Task.isCancelled else { throw CancellationError() }
        guard data.count <= maximumResponseBytes,
              let http = response as? HTTPURLResponse,
              http.statusCode == 200,
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rawContent = payload["content"] as? String else {
            throw LabCompletionError.protocolFailure
        }
        return LabModelResponse(
            content: applyingClientStopRule(rawContent, generation: request.generation),
            latencyMilliseconds: milliseconds(since: started),
            meanTokenProbability: meanTokenProbability(payload["completion_probabilities"]),
            tokenIDs: tokenIDs(payload["completion_probabilities"]),
            tokenLogProbabilities: tokenLogProbabilities(payload["completion_probabilities"]),
            tokenProbabilityMargins: tokenProbabilityMargins(
                payload["completion_probabilities"]
            ),
            tokenEntropies: tokenEntropies(payload["completion_probabilities"]),
            stopReason: payload["stop_type"] as? String
        )
    }

    private func completeStreaming(
        _ urlRequest: URLRequest,
        request: LabModelRequest,
        started: ContinuousClock.Instant
    ) async throws -> LabModelResponse {
        let (bytes, response) = try await session.bytes(for: urlRequest)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw LabCompletionError.protocolFailure
        }
        var content = ""
        var firstTokenMilliseconds: Int?
        var probabilities: [Double] = []
        var logProbabilities: [Double] = []
        var tokenIDs: [Int] = []
        var margins: [Double] = []
        var entropies: [Double] = []
        var stopReason: String?
        var recognizedFrame = false
        var incompleteProbabilityEvidence = false
        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard line.hasPrefix("data:") else { continue }
            let json = line.dropFirst("data:".count).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !json.isEmpty, json != "[DONE]" else { continue }
            guard let data = json.data(using: .utf8),
                  let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw LabCompletionError.protocolFailure
            }
            recognizedFrame = true
            if let piece = payload["content"] as? String, !piece.isEmpty {
                if firstTokenMilliseconds == nil { firstTokenMilliseconds = milliseconds(since: started) }
                content += piece
                guard content.utf8.count <= maximumResponseBytes else {
                    throw LabCompletionError.protocolFailure
                }
            }
            let frameProbabilities = probabilityValues(payload["completion_probabilities"])
            if let rows = payload["completion_probabilities"] as? [[String: Any]],
               rows.count != frameProbabilities.count {
                incompleteProbabilityEvidence = true
            }
            probabilities.append(contentsOf: frameProbabilities)
            logProbabilities.append(contentsOf: tokenLogProbabilities(payload["completion_probabilities"]))
            tokenIDs.append(contentsOf: self.tokenIDs(payload["completion_probabilities"]))
            margins.append(contentsOf: tokenProbabilityMargins(
                payload["completion_probabilities"]
            ))
            entropies.append(contentsOf: tokenEntropies(payload["completion_probabilities"]))
            if let value = payload["stop_type"] as? String { stopReason = value }
            if payload["stop"] as? Bool == true { break }
        }
        guard recognizedFrame else { throw LabCompletionError.protocolFailure }
        let mean = probabilities.isEmpty || incompleteProbabilityEvidence
            ? nil
            : probabilities.reduce(0, +) / Double(probabilities.count)
        return LabModelResponse(
            content: applyingClientStopRule(content, generation: request.generation),
            latencyMilliseconds: milliseconds(since: started),
            firstTokenMilliseconds: firstTokenMilliseconds,
            meanTokenProbability: mean,
            tokenIDs: tokenIDs,
            tokenLogProbabilities: incompleteProbabilityEvidence ? [] : logProbabilities,
            tokenProbabilityMargins: margins,
            tokenEntropies: entropies,
            stopReason: stopReason
        )
    }

    private func applyingClientStopRule(
        _ content: String,
        generation: LabGenerationConfiguration
    ) -> String {
        switch generation.stopRule {
        case .newline, .natural:
            return content
        case .characterLimit:
            return String(content.prefix(generation.stopCharacterLimit))
        case .sentence:
            guard let boundary = content.firstIndex(where: { ".!?".contains($0) }) else { return content }
            return String(content[...boundary])
        }
    }

    private func meanTokenProbability(_ value: Any?) -> Double? {
        let values = probabilityValues(value)
        return values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }

    func probabilityValues(_ value: Any?) -> [Double] {
        guard let entries = value as? [[String: Any]] else { return [] }
        let values = entries.compactMap { selectedProbabilityEntry($0).flatMap(probability) }
        // A partial mean would overstate the available confidence evidence.
        return values.count == entries.count ? values : []
    }

    private func tokenIDs(_ value: Any?) -> [Int] {
        guard let entries = value as? [[String: Any]] else { return [] }
        return entries.compactMap { entry in
            if let id = entry["id"] as? Int { return id }
            if let id = entry["token_id"] as? Int { return id }
            guard let selected = selectedProbabilityEntry(entry) else { return nil }
            return selected["id"] as? Int ?? selected["token_id"] as? Int
        }
    }

    func tokenLogProbabilities(_ value: Any?) -> [Double] {
        guard let entries = value as? [[String: Any]],
              probabilityValues(value).count == entries.count else { return [] }
        return entries.compactMap { entry in
            guard let selected = selectedProbabilityEntry(entry),
                  let value = probability(selected) else { return nil }
            // Preserve native log probabilities, including values whose exp
            // underflows, rather than fabricating a less-negative confidence.
            if let logProbability = selected["logprob"] as? Double {
                return logProbability
            }
            return log(max(value, .leastNonzeroMagnitude))
        }
    }

    func tokenProbabilityMargins(_ value: Any?) -> [Double] {
        alternativeProbabilityRows(value).map { values in
            let sorted = values.sorted(by: >)
            return max(0, min(1, sorted[0] - (sorted.count > 1 ? sorted[1] : 0)))
        }
    }

    func tokenEntropies(_ value: Any?) -> [Double] {
        alternativeProbabilityRows(value).map { values in
            let bounded = values.map { min(1, max(0, $0)) }
            let remainder = max(0, 1 - bounded.reduce(0, +))
            return (bounded + (remainder > 0 ? [remainder] : [])).reduce(0) {
                $1 > 0 ? $0 - $1 * log($1) : $0
            }
        }
    }

    private func alternativeProbabilityRows(_ value: Any?) -> [[Double]] {
        guard let entries = value as? [[String: Any]] else { return [] }
        return entries.compactMap { entry in
            // Current helpers use top_logprobs (default) or top_probs;
            // older helpers used probs. These are alternatives, not the
            // selected token's probability.
            for key in ["top_logprobs", "top_probs", "probs"] {
                if let alternatives = entry[key] as? [[String: Any]] {
                    let values = alternatives.compactMap(probability)
                    return !values.isEmpty && values.count == alternatives.count ? values : nil
                }
            }
            if let value = probability(entry) {
                return [value]
            }
            return nil
        }
    }

    private func probability(_ entry: [String: Any]) -> Double? {
        if entry["prob"] != nil {
            guard let value = entry["prob"] as? Double,
                  value.isFinite, (0...1).contains(value) else { return nil }
            return value
        }
        guard let value = entry["logprob"] as? Double,
              value.isFinite, value <= 0 else { return nil }
        return exp(value)
    }

    private func selectedProbabilityEntry(_ entry: [String: Any]) -> [String: Any]? {
        if entry["prob"] != nil || entry["logprob"] != nil { return entry }
        // Legacy rows name the emitted token with content. Never substitute
        // the highest-probability alternative when the emitted token differs.
        guard let content = entry["content"] as? String,
              let alternatives = entry["probs"] as? [[String: Any]] else { return nil }
        return alternatives.first { ($0["tok_str"] as? String) == content }
    }

    private func milliseconds(since started: ContinuousClock.Instant) -> Int {
        let components = started.duration(to: .now).components
        return max(
            0,
            Int(components.seconds * 1_000)
                + Int(components.attoseconds / 1_000_000_000_000_000)
        )
    }
}
