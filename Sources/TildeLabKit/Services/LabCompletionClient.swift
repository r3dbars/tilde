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

    public init(
        content: String,
        latencyMilliseconds: Int,
        firstTokenMilliseconds: Int? = nil,
        meanTokenProbability: Double? = nil
    ) {
        self.content = content
        self.latencyMilliseconds = latencyMilliseconds
        self.firstTokenMilliseconds = firstTokenMilliseconds
        self.meanTokenProbability = meanTokenProbability
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

    private func requestBody(_ request: LabModelRequest) -> [String: Any] {
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
            meanTokenProbability: meanTokenProbability(payload["completion_probabilities"])
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
        var recognizedFrame = false
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
            probabilities.append(contentsOf: probabilityValues(payload["completion_probabilities"]))
            if payload["stop"] as? Bool == true { break }
        }
        guard recognizedFrame else { throw LabCompletionError.protocolFailure }
        let mean = probabilities.isEmpty
            ? nil
            : probabilities.reduce(0, +) / Double(probabilities.count)
        return LabModelResponse(
            content: applyingClientStopRule(content, generation: request.generation),
            latencyMilliseconds: milliseconds(since: started),
            firstTokenMilliseconds: firstTokenMilliseconds,
            meanTokenProbability: mean
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

    private func probabilityValues(_ value: Any?) -> [Double] {
        guard let entries = value as? [[String: Any]] else { return [] }
        return entries.compactMap { entry in
            if let probability = entry["prob"] as? Double { return probability }
            guard let alternatives = entry["probs"] as? [[String: Any]] else { return nil }
            return alternatives.first?["prob"] as? Double
        }
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
