import Foundation

struct AppProofCommandPlan: Equatable {
    let bundleIdentifier: String
    let proofName: String
    let sourceRootURL: URL
    let logURL: URL
    let executableURL: URL
    let arguments: [String]
    let environmentOverrides: [String: String]

    var commandText: String {
        let envPrefix = environmentOverrides
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        let command = arguments.joined(separator: " ")
        return envPrefix.isEmpty ? command : "\(envPrefix) \(command)"
    }

    static func supportsAutomaticPlan(for bundleIdentifier: String) -> Bool {
        switch bundleIdentifier {
        case "com.apple.TextEdit", "com.google.Chrome":
            return true
        default:
            return false
        }
    }

    static func automaticPlan(
        for bundleIdentifier: String,
        sourceRootURL: URL,
        logDirectoryURL: URL
    ) -> AppProofCommandPlan? {
        switch bundleIdentifier {
        case "com.apple.TextEdit":
            return AppProofCommandPlan(
                bundleIdentifier: bundleIdentifier,
                proofName: "TextEdit",
                sourceRootURL: sourceRootURL,
                logURL: logDirectoryURL.appendingPathComponent("app-proof-textedit.log"),
                executableURL: URL(fileURLWithPath: "/usr/bin/env"),
                arguments: [
                    "bash",
                    "script/real_app_smoke.sh",
                    "textedit",
                    "--skip-build"
                ],
                environmentOverrides: proofEnvironment
            )
        case "com.google.Chrome":
            return AppProofCommandPlan(
                bundleIdentifier: bundleIdentifier,
                proofName: "Chrome",
                sourceRootURL: sourceRootURL,
                logURL: logDirectoryURL.appendingPathComponent("app-proof-chrome.log"),
                executableURL: URL(fileURLWithPath: "/usr/bin/env"),
                arguments: [
                    "bash",
                    "script/real_app_smoke.sh",
                    "chrome",
                    "--fixture",
                    "all",
                    "--skip-build"
                ],
                environmentOverrides: proofEnvironment
            )
        default:
            return nil
        }
    }

    private static var proofEnvironment: [String: String] {
        [
            "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE": "1",
            "AUTOCOMPLETE_LAB_REAL_APP_SKIP_BUILD": "1"
        ]
    }

    static func sourceRootURL(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        bundleURL: URL = Bundle.main.bundleURL,
        currentDirectoryPath: String = FileManager.default.currentDirectoryPath,
        fileManager: FileManager = .default
    ) -> URL? {
        var candidates: [URL] = []
        if let override = environment["AUTOCOMPLETE_LAB_SOURCE_ROOT"], !override.isEmpty {
            candidates.append(URL(fileURLWithPath: override, isDirectory: true))
        }
        candidates.append(URL(fileURLWithPath: currentDirectoryPath, isDirectory: true))
        candidates.append(bundleURL.deletingLastPathComponent())
        candidates.append(bundleURL.deletingLastPathComponent().deletingLastPathComponent())

        var seen: Set<String> = []
        for candidate in candidates {
            var current = candidate.standardizedFileURL
            for _ in 0..<8 {
                let key = current.path
                if seen.insert(key).inserted,
                   fileManager.isExecutableFile(
                       atPath: current
                           .appendingPathComponent("script")
                           .appendingPathComponent("real_app_smoke.sh")
                           .path
                   ) {
                    return current
                }

                let parent = current.deletingLastPathComponent()
                if parent.path == current.path {
                    break
                }
                current = parent
            }
        }

        return nil
    }
}

enum AppProofCommandRunnerError: Error, Equatable {
    case alreadyRunning
}

@MainActor
final class AppProofCommandRunner {
    private var process: Process?

    var isRunning: Bool {
        process?.isRunning == true
    }

    func run(
        plan: AppProofCommandPlan,
        completion: @escaping @MainActor (Bool, Int32) -> Void
    ) throws {
        guard !isRunning else {
            throw AppProofCommandRunnerError.alreadyRunning
        }

        try FileManager.default.createDirectory(
            at: plan.logURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if !FileManager.default.fileExists(atPath: plan.logURL.path) {
            _ = FileManager.default.createFile(atPath: plan.logURL.path, contents: nil)
        }

        let outputHandle = try FileHandle(forWritingTo: plan.logURL)
        outputHandle.seekToEndOfFile()

        let process = Process()
        process.currentDirectoryURL = plan.sourceRootURL
        process.executableURL = plan.executableURL
        process.arguments = plan.arguments
        var environment = ProcessInfo.processInfo.environment
        for (key, value) in plan.environmentOverrides {
            environment[key] = value
        }
        process.environment = environment
        process.standardOutput = outputHandle
        process.standardError = outputHandle
        process.terminationHandler = { [weak self, outputHandle] process in
            outputHandle.closeFile()
            Task { @MainActor in
                self?.process = nil
                completion(process.terminationStatus == 0, process.terminationStatus)
            }
        }

        try process.run()
        self.process = process
    }
}
