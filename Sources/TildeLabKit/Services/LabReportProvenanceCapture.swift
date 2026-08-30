import CryptoKit
import Foundation

public enum LabReportProvenanceCaptureError: Error, LocalizedError, Sendable {
    case decisionGradeUnavailable([LabEvidenceIneligibilityReason])

    public var errorDescription: String? {
        switch self {
        case let .decisionGradeUnavailable(reasons):
            let values = reasons.map(\.rawValue).sorted().joined(separator: ", ")
            return "Decision-grade run-start provenance is unavailable: \(values)."
        }
    }
}

/// Captures a privacy-safe run-start envelope before model work begins.
///
/// Git status output, executable paths, and the raw argv are inspected locally
/// but never retained. Only stable hashes and coarse machine state enter the
/// report.
public enum LabReportProvenanceCapture {
    public static func capture(
        experiment: LabExperimentRegistration?,
        arguments: [String] = CommandLine.arguments,
        executableURL: URL? = Bundle.main.executableURL,
        currentDirectoryURL: URL = URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath,
            isDirectory: true
        ),
        capturedAt: Date = Date()
    ) throws -> LabReportProvenance {
        let executable = resolvedExecutableURL(
            explicit: executableURL,
            arguments: arguments,
            currentDirectoryURL: currentDirectoryURL
        )
        let commit = commandOutput(
            "/usr/bin/git",
            ["rev-parse", "HEAD"],
            currentDirectoryURL: currentDirectoryURL
        )
        let status = commandOutput(
            "/usr/bin/git",
            ["status", "--porcelain", "--untracked-files=normal"],
            currentDirectoryURL: currentDirectoryURL
        )
        let usableCommit = commit?.isLowercaseHexDigest(count: 40) == true ? commit : nil
        let treeState: LabSourceTreeState
        if usableCommit == nil || status == nil {
            treeState = .unavailable
        } else {
            treeState = status!.isEmpty ? .clean : .dirty
        }
        let provenance = LabReportProvenance(
            capturedAt: capturedAt,
            source: LabReportSourceProvenance(
                gitCommitSHA: treeState == .unavailable ? nil : usableCommit,
                treeState: treeState,
                runnerSHA256: try? digestFile(executable)
            ),
            environment: LabReportEnvironmentProvenance(
                operatingSystemVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                operatingSystemBuild: commandOutput(
                    "/usr/bin/sw_vers",
                    ["-buildVersion"],
                    currentDirectoryURL: currentDirectoryURL
                ),
                hardwareClass: commandOutput(
                    "/usr/sbin/sysctl",
                    ["-n", "hw.model"],
                    currentDirectoryURL: currentDirectoryURL
                ),
                machine: LabResearchMachinePreflight.inspect()
            ),
            invocation: LabReportInvocationProvenance(
                digestSHA256: LabReportInvocationProvenance.canonicalDigest(arguments: arguments)
            ),
            experiment: experiment
        )
        return try provenance.validated()
    }

    /// Protected runs fail before inference unless every provenance field is
    /// present, the source tree is clean, and the hypothesis is registered.
    public static func captureDecisionGrade(
        experiment: LabExperimentRegistration,
        arguments: [String] = CommandLine.arguments,
        executableURL: URL? = Bundle.main.executableURL,
        currentDirectoryURL: URL = URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath,
            isDirectory: true
        ),
        capturedAt: Date = Date()
    ) throws -> LabReportProvenance {
        let provenance = try capture(
            experiment: experiment,
            arguments: arguments,
            executableURL: executableURL,
            currentDirectoryURL: currentDirectoryURL,
            capturedAt: capturedAt
        )
        let reasons = provenance.ineligibilityReasons
        guard reasons.isEmpty else {
            throw LabReportProvenanceCaptureError.decisionGradeUnavailable(reasons)
        }
        return provenance
    }

    private static func resolvedExecutableURL(
        explicit: URL?,
        arguments: [String],
        currentDirectoryURL: URL
    ) -> URL {
        if let explicit { return explicit.resolvingSymlinksInPath() }
        let argument = arguments.first ?? ""
        return URL(fileURLWithPath: argument, relativeTo: currentDirectoryURL)
            .standardizedFileURL
            .resolvingSymlinksInPath()
    }

    private static func commandOutput(
        _ executable: String,
        _ arguments: [String],
        currentDirectoryURL: URL
    ) -> String? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectoryURL
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            return String(decoding: data, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    private static func digestFile(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            let data = try handle.read(upToCount: 1_048_576) ?? Data()
            if data.isEmpty { break }
            hasher.update(data: data)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

private extension String {
    func isLowercaseHexDigest(count: Int) -> Bool {
        self.count == count
            && range(of: "^[a-f0-9]{\(count)}$", options: .regularExpression)
                == startIndex..<endIndex
    }
}
