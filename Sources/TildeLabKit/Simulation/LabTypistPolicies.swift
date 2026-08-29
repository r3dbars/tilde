import Foundation

/// Frozen rules, no randomness, no state. The same feature object always
/// produces the same decision, so a simulated run is reproducible and any
/// difference between two runs belongs to the stack under test, not the
/// simulated writer.
public struct DeterministicHeuristicTypist: TypistDecisionPolicy {
    public static let identifier = "deterministic-heuristic-v1"

    public var identifier: String { Self.identifier }

    public init() {}

    public func decide(_ features: LabTypistMomentFeatures) throws -> LabTypistDecision {
        // A writer who has already cleared two ghosts stops reading them.
        if features.dismissalsSoFar >= 2 {
            return LabTypistDecision(action: .dismiss, wouldRetain: false)
        }
        // Nothing they meant to write: cost with no benefit.
        if features.prefixMatch == .divergent {
            return LabTypistDecision(
                action: features.personaInterruptionTolerance == .low ? .dismiss : .continueTyping,
                wouldRetain: false
            )
        }
        // A ghost that arrives after the writer has already typed past it is
        // noise regardless of quality.
        if features.millisecondsSinceDisplay > 700 {
            return LabTypistDecision(action: .continueTyping, wouldRetain: false)
        }
        // Mid-word ghosts break the writer's line of thought.
        if features.boundary == .midWord, features.personaInterruptionTolerance != .high {
            return LabTypistDecision(action: .continueTyping, wouldRetain: false)
        }
        if features.prefixMatch == .partial {
            return LabTypistDecision(
                action: features.matchedPrefixCharacters >= 3 ? .acceptWord : .continueTyping,
                wouldRetain: features.matchedPrefixCharacters >= 3
            )
        }
        // Exact match. Long candidates still need a second read, and a
        // low-tolerance writer would rather keep typing than verify.
        switch features.candidateLengthBucket {
        case .oneWord, .twoToThree:
            return LabTypistDecision(action: .accept, wouldRetain: true)
        case .fourToSeven:
            return LabTypistDecision(
                action: features.personaInterruptionTolerance == .low ? .acceptWord : .accept,
                wouldRetain: true
            )
        case .eightPlus:
            return LabTypistDecision(
                action: features.personaInterruptionTolerance == .high ? .accept : .acceptWord,
                wouldRetain: features.meanTokenProbabilityBucket != .low
            )
        case .unknown:
            return LabTypistDecision(action: .continueTyping, wouldRetain: false)
        }
    }
}

/// The socket for a cheap frontier model. The command receives one text-free
/// feature object on stdin and answers with one text-free decision object on
/// stdout. No model, endpoint, or credential lives in this repository: the
/// owner supplies the command, and the schema on both sides guarantees that no
/// scenario text, prompt, or candidate can reach it.
public struct ExternalCommandTypist: TypistDecisionPolicy {
    public let identifier: String

    private let executableURL: URL
    private let arguments: [String]
    private let timeoutSeconds: Double

    public init(
        command: String,
        arguments: [String] = [],
        timeoutSeconds: Double = 20,
        identifier: String = "external-command-v1"
    ) throws {
        let path = (command as NSString).expandingTildeInPath
        guard path.hasPrefix("/") else {
            throw LabTypistPolicyError.decisionCommandUnavailable(command)
        }
        let url = URL(fileURLWithPath: path).standardizedFileURL
        let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values?.isRegularFile == true,
              values?.isSymbolicLink != true,
              FileManager.default.isExecutableFile(atPath: url.path) else {
            throw LabTypistPolicyError.decisionCommandUnavailable(url.path)
        }
        executableURL = url
        self.arguments = arguments
        self.timeoutSeconds = timeoutSeconds
        self.identifier = identifier
    }

    /// Off-thread read buffer; the semaphore orders the write before the read.
    private final class ResponseBox: @unchecked Sendable {
        var data = Data()
    }

    public func decide(_ features: LabTypistMomentFeatures) throws -> LabTypistDecision {
        let payload = try features.encodedJSON()
        let process = Process()
        let input = Pipe()
        let output = Pipe()
        process.executableURL = executableURL
        process.arguments = arguments
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        // A decision command never needs the environment, and an inherited one
        // is a path for credentials or local paths to leak into it.
        process.environment = ["PATH": "/usr/bin:/bin"]
        try process.run()

        input.fileHandleForWriting.write(payload)
        try? input.fileHandleForWriting.close()

        // The read happens off-thread so the deadline still fires against a
        // command that hangs without ever closing stdout; terminating the
        // process closes the pipe and unblocks the reader.
        let response = ResponseBox()
        let readFinished = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .utility).async {
            response.data = output.fileHandleForReading.readDataToEndOfFile()
            readFinished.signal()
        }
        if readFinished.wait(timeout: .now() + timeoutSeconds) == .timedOut {
            process.terminate()
            _ = readFinished.wait(timeout: .now() + 1)
            throw LabTypistPolicyError.decisionCommandFailed(-1)
        }
        let data = response.data
        // Brief grace for the gap between stdout closing and process exit.
        let exitDeadline = Date().addingTimeInterval(1)
        while process.isRunning, Date() < exitDeadline {
            usleep(2_000)
        }
        if process.isRunning {
            process.terminate()
            throw LabTypistPolicyError.decisionCommandFailed(-1)
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw LabTypistPolicyError.decisionCommandFailed(process.terminationStatus)
        }
        // Bound the response before parsing; a policy answer is a few dozen bytes.
        guard data.count <= 4_096 else { throw LabTypistPolicyError.invalidDecisionPayload }
        return try LabTypistDecision.decode(data)
    }
}
