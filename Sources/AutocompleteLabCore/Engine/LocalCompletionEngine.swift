import Foundation

public struct LocalCompletionRuntimeConfiguration: Equatable, Sendable {
    public let model: LocalModelID
    public let maxGeneratedTokens: Int
    public let maxVisibleWords: Int
    public let reasoningEnabled: Bool

    public init(policy: CompletionModelPolicy = .mvp) {
        self.model = policy.model
        self.maxGeneratedTokens = min(max(8, policy.maxGeneratedTokens), 16)
        self.maxVisibleWords = min(max(2, policy.maxVisibleWords), 8)
        self.reasoningEnabled = policy.reasoningEnabled
    }
}

public protocol LocalCompletionRuntimeRunner: Sendable {
    func complete(
        prompt: CompletionPrompt,
        configuration: LocalCompletionRuntimeConfiguration
    ) async throws -> String
}

public enum LocalCompletionRuntimeError: Error, Equatable, Sendable {
    case executableMissing
    case launchFailed
    case failed(exitCode: Int32, stderr: String)
    case invalidOutput
}

public final class ProcessCompletionRuntimeRunner: LocalCompletionRuntimeRunner, @unchecked Sendable {
    private let executableURL: URL
    private let extraArguments: [String]
    private let environment: [String: String]

    public init(
        executableURL: URL,
        extraArguments: [String] = [],
        environment: [String: String] = [:]
    ) {
        self.executableURL = executableURL
        self.extraArguments = extraArguments
        self.environment = environment
    }

    public func complete(
        prompt: CompletionPrompt,
        configuration: LocalCompletionRuntimeConfiguration
    ) async throws -> String {
        guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            throw LocalCompletionRuntimeError.executableMissing
        }

        return try await Task.detached(priority: .userInitiated) { [executableURL, extraArguments, environment] in
            let process = Process()
            let stdin = Pipe()
            let stdout = Pipe()
            let stderr = Pipe()

            process.executableURL = executableURL
            process.arguments = extraArguments + [
                "--model", configuration.model.rawValue,
                "--max-tokens", "\(configuration.maxGeneratedTokens)",
                "--max-words", "\(configuration.maxVisibleWords)",
                "--reasoning", configuration.reasoningEnabled ? "on" : "off"
            ]
            process.standardInput = stdin
            process.standardOutput = stdout
            process.standardError = stderr
            process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, newValue in
                newValue
            }

            do {
                try process.run()
            } catch {
                throw LocalCompletionRuntimeError.launchFailed
            }

            let payload = RuntimePromptPayload(system: prompt.system, user: prompt.user)
            try stdin.fileHandleForWriting.write(contentsOf: JSONEncoder().encode(payload))
            try stdin.fileHandleForWriting.close()

            let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
            let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                let message = String(data: errorData, encoding: .utf8) ?? ""
                throw LocalCompletionRuntimeError.failed(
                    exitCode: process.terminationStatus,
                    stderr: message
                )
            }

            guard let output = String(data: outputData, encoding: .utf8) else {
                throw LocalCompletionRuntimeError.invalidOutput
            }

            return output
        }.value
    }
}

public final class LocalCompletionEngine: CompletionEngine, @unchecked Sendable {
    private let runner: any LocalCompletionRuntimeRunner
    private let fallback: any CompletionEngine
    private let promptBuilder: CompletionPromptBuilder
    private let configuration: LocalCompletionRuntimeConfiguration

    public init(
        runner: any LocalCompletionRuntimeRunner,
        fallback: any CompletionEngine = MockCompletionEngine(),
        promptBuilder: CompletionPromptBuilder = CompletionPromptBuilder(),
        configuration: LocalCompletionRuntimeConfiguration = LocalCompletionRuntimeConfiguration()
    ) {
        self.runner = runner
        self.fallback = fallback
        self.promptBuilder = promptBuilder
        self.configuration = configuration
    }

    public func suggestion(for request: CompletionRequest) async throws -> CompletionSuggestion? {
        do {
            let prompt = promptBuilder.prompt(for: request)
            let rawOutput = try await runner.complete(prompt: prompt, configuration: configuration)
            if let cleaned = clean(rawOutput, request: request) {
                return cleaned
            }
        } catch {
            return try await fallback.suggestion(for: request)
        }

        return try await fallback.suggestion(for: request)
    }

    private func clean(_ rawOutput: String, request: CompletionRequest) -> CompletionSuggestion? {
        let cleaner = CompletionOutputCleaner(maxVisibleWords: request.maxVisibleWords)
        return cleaner.cleanBestCandidate(
            rawOutput,
            after: request.textBeforeCursor,
            mode: request.mode,
            behaviorProfileID: request.behaviorProfile.id
        ).suggestion
    }
}

public enum CompletionEngineSelection: Equatable, Sendable {
    case localGemma4E2B
    case mockFallback
}

public struct CompletionEngineFactory: Sendable {
    public let runtimeExecutableURL: URL?
    public let runtimeEnvironment: [String: String]

    public init(runtimeExecutableURL: URL?, runtimeEnvironment: [String: String] = [:]) {
        self.runtimeExecutableURL = runtimeExecutableURL
        self.runtimeEnvironment = runtimeEnvironment
    }

    public func selection() -> CompletionEngineSelection {
        guard let runtimeExecutableURL,
              FileManager.default.isExecutableFile(atPath: runtimeExecutableURL.path) else {
            return .mockFallback
        }

        return .localGemma4E2B
    }

    public func makeEngine() -> any CompletionEngine {
        guard let runtimeExecutableURL,
              FileManager.default.isExecutableFile(atPath: runtimeExecutableURL.path) else {
            return MockCompletionEngine()
        }

        return LocalCompletionEngine(
            runner: ProcessCompletionRuntimeRunner(
                executableURL: runtimeExecutableURL,
                environment: runtimeEnvironment
            )
        )
    }
}

private struct RuntimePromptPayload: Encodable {
    let system: String
    let user: String
}
