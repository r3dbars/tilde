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
protocol AppProofCommandRunning: AnyObject {
    var isRunning: Bool { get }

    func run(
        plan: AppProofCommandPlan,
        completion: @escaping @MainActor (Bool, Int32) -> Void
    ) throws
}

struct AppProofCommandCompletion: Equatable {
    let plan: AppProofCommandPlan
    let passed: Bool
    let status: Int32

    var decisionText: String {
        passed
            ? "Done: \(plan.proofName) proof passed"
            : "Needs attention: \(plan.proofName) proof failed"
    }

    var endReason: String {
        passed ? "passed" : "failed"
    }
}

enum AppProofCommandStartOutcome: Equatable {
    case unsupported
    case unavailable(bundleIdentifier: String)
    case started(AppProofCommandPlan)
    case alreadyRunning(bundleIdentifier: String)
    case failedToStart(bundleIdentifier: String, logURL: URL?, reason: String)

    var decisionText: String? {
        switch self {
        case .unsupported:
            return nil
        case .unavailable:
            return "Blocked: proof script unavailable"
        case let .started(plan):
            return "Running: \(plan.proofName) proof"
        case .alreadyRunning:
            return "Running: app proof already in progress"
        case .failedToStart:
            return "Blocked: proof command failed to start"
        }
    }
}

@MainActor
final class AppProofCommandCoordinator {
    private let runner: any AppProofCommandRunning
    private let logDirectoryURL: URL
    private let sourceRootResolver: () -> URL?

    init(
        runner: any AppProofCommandRunning = AppProofCommandRunner(),
        logDirectoryURL: URL = AppProofCommandCoordinator.defaultLogDirectoryURL,
        sourceRootResolver: @escaping () -> URL? = { AppProofCommandPlan.sourceRootURL() }
    ) {
        self.runner = runner
        self.logDirectoryURL = logDirectoryURL
        self.sourceRootResolver = sourceRootResolver
    }

    static var defaultLogDirectoryURL: URL {
        FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("AutocompleteLab", isDirectory: true)
    }

    func supportsAutomaticPlan(for bundleIdentifier: String) -> Bool {
        AppProofCommandPlan.supportsAutomaticPlan(for: bundleIdentifier)
    }

    func start(
        for bundleIdentifier: String,
        completion: @escaping @MainActor (AppProofCommandCompletion) -> Void
    ) -> AppProofCommandStartOutcome {
        guard AppProofCommandPlan.supportsAutomaticPlan(for: bundleIdentifier) else {
            return .unsupported
        }

        guard let sourceRootURL = sourceRootResolver(),
              let plan = AppProofCommandPlan.automaticPlan(
                  for: bundleIdentifier,
                  sourceRootURL: sourceRootURL,
                  logDirectoryURL: logDirectoryURL
              ) else {
            return .unavailable(bundleIdentifier: bundleIdentifier)
        }

        do {
            try runner.run(plan: plan) { passed, status in
                completion(
                    AppProofCommandCompletion(
                        plan: plan,
                        passed: passed,
                        status: status
                    )
                )
            }

            return .started(plan)
        } catch AppProofCommandRunnerError.alreadyRunning {
            return .alreadyRunning(bundleIdentifier: bundleIdentifier)
        } catch {
            return .failedToStart(
                bundleIdentifier: bundleIdentifier,
                logURL: plan.logURL,
                reason: error.localizedDescription
            )
        }
    }
}

@MainActor
final class AppProofCommandRunner: AppProofCommandRunning {
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
