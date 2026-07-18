import Foundation
import Testing
@testable import AutocompleteLabApp

@Suite("App proof command runner")
struct AppProofCommandRunnerTests {
    @Test("Live automatic proof entry point exists and is executable")
    func liveAutomaticProofEntryPointExistsAndIsExecutable() {
        let repositoryRootURL = repositoryRootURL()
        let entryPointURL = AppProofCommandPlan.proofEntryPointURL(sourceRootURL: repositoryRootURL)

        #expect(AppProofCommandPlan.proofEntryPointRelativePath == "script/real_app_smoke.sh")
        #expect(FileManager.default.fileExists(atPath: entryPointURL.path))
        #expect(FileManager.default.isExecutableFile(atPath: entryPointURL.path))
    }

    @Test("Automatic proof entry point preserves parser output and exit contracts")
    func automaticProofEntryPointPreservesParserOutputAndExitContracts() throws {
        let textEdit = try runProofEntryPoint(["textedit", "--skip-build", "--dry-run"])
        #expect(textEdit.status == 0)
        #expect(textEdit.standardOutput == "real_app_smoke: DRY RUN app=textedit fixture=textarea skipBuild=1\n")
        #expect(textEdit.standardError.isEmpty)

        let chrome = try runProofEntryPoint([
            "chrome", "--fixture", "contenteditable", "--skip-build", "--dry-run"
        ])
        #expect(chrome.status == 0)
        #expect(chrome.standardOutput == "real_app_smoke: DRY RUN app=chrome fixture=contenteditable skipBuild=1\n")
        #expect(chrome.standardError.isEmpty)

        let unsupported = try runProofEntryPoint(["chrome", "--fixture", "unsupported", "--dry-run"])
        #expect(unsupported.status == 2)
        #expect(unsupported.standardOutput.isEmpty)
        #expect(unsupported.standardError == "real_app_smoke: unsupported Chrome fixture 'unsupported'\n")

        let missingApp = try runProofEntryPoint([])
        #expect(missingApp.status == 2)
        #expect(missingApp.standardOutput.isEmpty)
        #expect(missingApp.standardError.hasPrefix("Usage: script/real_app_smoke.sh"))
    }

    @Test("TextEdit cleanup bounds a hanging osascript without signaling unrelated work")
    func textEditCleanupBoundsHangingOsaScriptWithoutSignalingUnrelatedWork() throws {
        let scriptURL = AppProofCommandPlan.proofEntryPointURL(sourceRootURL: repositoryRootURL())
        let script = try String(contentsOf: scriptURL, encoding: .utf8)
        let cleanupStart = try #require(script.range(of: "cleanup() {")?.lowerBound)
        let cleanupEnd = try #require(
            script.range(of: "\ntrap cleanup", range: cleanupStart..<script.endIndex)?.lowerBound
        )
        let cleanupFunction = String(script[cleanupStart..<cleanupEnd])
        #expect(
            cleanupFunction.contains(
                "osascript - \"$TEXTEDIT_WINDOW_TITLE\" <<'APPLESCRIPT' >/dev/null 2>&1 &"
            )
        )

        let fixture = """
        set -euo pipefail
        osascript() { sleep 5; }
        TEXTEDIT_WINDOW_TITLE="steadytype-cleanup-fixture"
        CHROME_PID=""
        TEMP_DIR=""
        LOCK_DIR=""
        LOCK_HELD=0
        \(cleanupFunction)
        sleep 20 &
        unrelated_pid=$!
        started_at=$SECONDS
        cleanup
        elapsed=$((SECONDS - started_at))
        kill -0 "$unrelated_pid"
        kill "$unrelated_pid"
        wait "$unrelated_pid" >/dev/null 2>&1 || true
        ((elapsed <= 4))
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", fixture]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        #expect(process.terminationStatus == 0)
    }

    @Test("TextEdit proof plan runs the safe skip-build smoke lane")
    func textEditProofPlanRunsTheSafeSkipBuildSmokeLane() throws {
        let sourceRootURL = URL(fileURLWithPath: "/tmp/autocomplete-lab", isDirectory: true)
        let logDirectoryURL = URL(fileURLWithPath: "/tmp/autocomplete-lab-logs", isDirectory: true)
        let plan = try #require(
            AppProofCommandPlan.automaticPlan(
                for: "com.apple.TextEdit",
                sourceRootURL: sourceRootURL,
                logDirectoryURL: logDirectoryURL
            )
        )

        #expect(plan.proofName == "TextEdit")
        #expect(AppProofCommandPlan.supportsAutomaticPlan(for: "com.apple.TextEdit"))
        #expect(plan.executableURL.path == "/usr/bin/env")
        #expect(plan.arguments == ["bash", "script/real_app_smoke.sh", "textedit", "--skip-build"])
        #expect(plan.environmentOverrides["AUTOCOMPLETE_LAB_SCREENSHOT_TRACE"] == "1")
        #expect(plan.environmentOverrides["AUTOCOMPLETE_LAB_REAL_APP_SKIP_BUILD"] == "1")
        #expect(plan.logURL.lastPathComponent == "app-proof-textedit.log")
        #expect(plan.commandText.contains("script/real_app_smoke.sh textedit --skip-build"))
    }

    @Test("Chrome proof plan runs the local textarea and contenteditable fixtures without rebuilding")
    func chromeProofPlanRunsLocalTextareaAndContenteditableFixturesWithoutRebuilding() throws {
        let sourceRootURL = URL(fileURLWithPath: "/tmp/autocomplete-lab", isDirectory: true)
        let logDirectoryURL = URL(fileURLWithPath: "/tmp/autocomplete-lab-logs", isDirectory: true)
        let plan = try #require(
            AppProofCommandPlan.automaticPlan(
                for: "com.google.Chrome",
                sourceRootURL: sourceRootURL,
                logDirectoryURL: logDirectoryURL
            )
        )

        #expect(plan.proofName == "Chrome")
        #expect(AppProofCommandPlan.supportsAutomaticPlan(for: "com.google.Chrome"))
        #expect(plan.executableURL.path == "/usr/bin/env")
        #expect(plan.arguments == [
            "bash",
            "-lc",
            "script/real_app_smoke.sh chrome --fixture textarea --skip-build && script/real_app_smoke.sh chrome --fixture contenteditable --skip-build"
        ])
        #expect(plan.environmentOverrides["AUTOCOMPLETE_LAB_SCREENSHOT_TRACE"] == "1")
        #expect(plan.environmentOverrides["AUTOCOMPLETE_LAB_REAL_APP_SKIP_BUILD"] == "1")
        #expect(plan.logURL.lastPathComponent == "app-proof-chrome.log")
        #expect(
            plan.commandText.contains(
                "script/real_app_smoke.sh chrome --fixture textarea --skip-build"
            )
        )
        #expect(
            plan.commandText.contains(
                "script/real_app_smoke.sh chrome --fixture contenteditable --skip-build"
            )
        )
    }

    @Test("Prompt apps do not get automatic proof commands")
    func promptAppsDoNotGetAutomaticProofCommands() {
        let sourceRootURL = URL(fileURLWithPath: "/tmp/autocomplete-lab", isDirectory: true)
        let logDirectoryURL = URL(fileURLWithPath: "/tmp/autocomplete-lab-logs", isDirectory: true)

        #expect(
            AppProofCommandPlan.automaticPlan(
                for: "com.openai.codex",
                sourceRootURL: sourceRootURL,
                logDirectoryURL: logDirectoryURL
            ) == nil
        )
        #expect(!AppProofCommandPlan.supportsAutomaticPlan(for: "com.openai.codex"))
    }

    @Test("Coordinator starts supported app proof and reports completion")
    @MainActor
    func coordinatorStartsSupportedAppProofAndReportsCompletion() throws {
        let runner = FakeAppProofCommandRunner()
        let sourceRootURL = URL(fileURLWithPath: "/tmp/autocomplete-lab", isDirectory: true)
        let logDirectoryURL = URL(fileURLWithPath: "/tmp/autocomplete-lab-logs", isDirectory: true)
        let coordinator = AppProofCommandCoordinator(
            runner: runner,
            logDirectoryURL: logDirectoryURL,
            sourceRootResolver: { sourceRootURL }
        )
        var completion: AppProofCommandCompletion?

        let outcome = coordinator.start(for: "com.google.Chrome") { result in
            completion = result
        }

        guard case let .started(plan) = outcome else {
            Issue.record("Expected Chrome proof to start")
            return
        }

        #expect(plan.proofName == "Chrome")
        #expect(plan.logURL.lastPathComponent == "app-proof-chrome.log")
        #expect(runner.startedPlans == [plan])

        runner.complete(passed: true, status: 0)

        #expect(completion?.plan == plan)
        #expect(completion?.passed == true)
        #expect(completion?.status == 0)
        #expect(completion?.decisionText == "Done: Chrome proof passed")
        #expect(completion?.endReason == "passed")
    }

    @Test("Coordinator keeps prompt apps and missing source roots from launching")
    @MainActor
    func coordinatorKeepsPromptAppsAndMissingSourceRootsFromLaunching() {
        let runner = FakeAppProofCommandRunner()
        let sourceRootURL = URL(fileURLWithPath: "/tmp/autocomplete-lab", isDirectory: true)
        let logDirectoryURL = URL(fileURLWithPath: "/tmp/autocomplete-lab-logs", isDirectory: true)
        let coordinator = AppProofCommandCoordinator(
            runner: runner,
            logDirectoryURL: logDirectoryURL,
            sourceRootResolver: { sourceRootURL }
        )

        #expect(!coordinator.supportsAutomaticPlan(for: "com.openai.codex"))
        #expect(coordinator.start(for: "com.openai.codex") { _ in } == .unsupported)

        let unavailable = AppProofCommandCoordinator(
            runner: runner,
            logDirectoryURL: logDirectoryURL,
            sourceRootResolver: { nil }
        )

        #expect(
            unavailable.start(for: "com.apple.TextEdit") { _ in }
                == .unavailable(bundleIdentifier: "com.apple.TextEdit")
        )
        #expect(runner.startedPlans.isEmpty)
    }

    @Test("Failed automatic proof starts request proof mode cleanup")
    func failedAutomaticProofStartsRequestProofModeCleanup() {
        let logURL = URL(fileURLWithPath: "/tmp/autocomplete-lab-logs/app-proof-textedit.log")

        #expect(
            AppProofCommandStartOutcome
                .unavailable(bundleIdentifier: "com.apple.TextEdit")
                .proofModeEndReasonAfterStartAttempt == "command-unavailable"
        )
        #expect(
            AppProofCommandStartOutcome
                .failedToStart(bundleIdentifier: "com.apple.TextEdit", logURL: logURL, reason: "boom")
                .proofModeEndReasonAfterStartAttempt == "command-failed"
        )
        #expect(AppProofCommandStartOutcome.unsupported.proofModeEndReasonAfterStartAttempt == nil)

        let sourceRootURL = URL(fileURLWithPath: "/tmp/autocomplete-lab", isDirectory: true)
        let logDirectoryURL = URL(fileURLWithPath: "/tmp/autocomplete-lab-logs", isDirectory: true)
        let plan = AppProofCommandPlan(
            bundleIdentifier: "com.apple.TextEdit",
            proofName: "TextEdit",
            sourceRootURL: sourceRootURL,
            logURL: logDirectoryURL.appendingPathComponent("app-proof-textedit.log"),
            executableURL: URL(fileURLWithPath: "/usr/bin/env"),
            arguments: ["true"],
            environmentOverrides: [:]
        )
        #expect(AppProofCommandStartOutcome.started(plan).proofModeEndReasonAfterStartAttempt == nil)
        #expect(
            AppProofCommandStartOutcome
                .alreadyRunning(bundleIdentifier: "com.apple.TextEdit")
                .proofModeEndReasonAfterStartAttempt == nil
        )
    }

    @Test("Source root resolver requires an executable proof entry point")
    func sourceRootResolverRequiresAnExecutableProofEntryPoint() throws {
        let tempRootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("autocomplete-lab-proof-root-\(UUID().uuidString)", isDirectory: true)
        let sourceRootURL = tempRootURL.appendingPathComponent("repo", isDirectory: true)
        let scriptDirectoryURL = sourceRootURL.appendingPathComponent("script", isDirectory: true)
        let scriptURL = scriptDirectoryURL.appendingPathComponent("real_app_smoke.sh")
        defer {
            try? FileManager.default.removeItem(at: tempRootURL)
        }

        try FileManager.default.createDirectory(at: scriptDirectoryURL, withIntermediateDirectories: true)
        let bundleURL = sourceRootURL
            .appendingPathComponent("dist", isDirectory: true)
            .appendingPathComponent("SteadyType.app", isDirectory: true)

        #expect(
            AppProofCommandPlan.sourceRootURL(
                environment: [:],
                bundleURL: bundleURL,
                currentDirectoryPath: tempRootURL.path
            ) == nil
        )

        try "#!/usr/bin/env bash\n".write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: scriptURL.path)
        #expect(
            AppProofCommandPlan.sourceRootURL(
                environment: [:],
                bundleURL: bundleURL,
                currentDirectoryPath: tempRootURL.path
            ) == nil
        )

        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
        let resolvedURL = AppProofCommandPlan.sourceRootURL(
            environment: [:],
            bundleURL: bundleURL,
            currentDirectoryPath: tempRootURL.path
        )

        #expect(resolvedURL?.standardizedFileURL == sourceRootURL.standardizedFileURL)
    }

    private func repositoryRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func runProofEntryPoint(_ arguments: [String]) throws -> ProofEntryPointResult {
        let process = Process()
        let standardOutput = Pipe()
        let standardError = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "bash",
            AppProofCommandPlan.proofEntryPointURL(sourceRootURL: repositoryRootURL()).path
        ] + arguments
        process.standardOutput = standardOutput
        process.standardError = standardError

        try process.run()
        process.waitUntilExit()

        return ProofEntryPointResult(
            status: process.terminationStatus,
            standardOutput: String(
                data: standardOutput.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            ) ?? "",
            standardError: String(
                data: standardError.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            ) ?? ""
        )
    }
}

private struct ProofEntryPointResult {
    let status: Int32
    let standardOutput: String
    let standardError: String
}

@MainActor
private final class FakeAppProofCommandRunner: AppProofCommandRunning {
    var startedPlans: [AppProofCommandPlan] = []
    private var completion: (@MainActor (Bool, Int32) -> Void)?

    var isRunning: Bool {
        completion != nil
    }

    func run(
        plan: AppProofCommandPlan,
        completion: @escaping @MainActor (Bool, Int32) -> Void
    ) throws {
        startedPlans.append(plan)
        self.completion = completion
    }

    func complete(passed: Bool, status: Int32) {
        let completion = completion
        self.completion = nil
        completion?(passed, status)
    }
}
