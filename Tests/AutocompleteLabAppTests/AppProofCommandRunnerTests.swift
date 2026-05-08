import Foundation
import Testing
@testable import AutocompleteLabApp

@Suite("App proof command runner")
struct AppProofCommandRunnerTests {
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

    @Test("Chrome proof plan runs every safe fixture without rebuilding")
    func chromeProofPlanRunsEverySafeFixtureWithoutRebuilding() throws {
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
            "script/real_app_smoke.sh",
            "chrome",
            "--fixture",
            "all",
            "--include-default-real-editor-proof",
            "--skip-build"
        ])
        #expect(plan.environmentOverrides["AUTOCOMPLETE_LAB_SCREENSHOT_TRACE"] == "1")
        #expect(plan.environmentOverrides["AUTOCOMPLETE_LAB_REAL_APP_SKIP_BUILD"] == "1")
        #expect(plan.logURL.lastPathComponent == "app-proof-chrome.log")
        #expect(
            plan.commandText.contains(
                "script/real_app_smoke.sh chrome --fixture all --include-default-real-editor-proof --skip-build"
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

    @Test("Source root resolver finds the smoke script from an app bundle path")
    func sourceRootResolverFindsTheSmokeScriptFromAnAppBundlePath() throws {
        let tempRootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("autocomplete-lab-proof-root-\(UUID().uuidString)", isDirectory: true)
        let sourceRootURL = tempRootURL.appendingPathComponent("repo", isDirectory: true)
        let scriptDirectoryURL = sourceRootURL.appendingPathComponent("script", isDirectory: true)
        let scriptURL = scriptDirectoryURL.appendingPathComponent("real_app_smoke.sh")
        defer {
            try? FileManager.default.removeItem(at: tempRootURL)
        }

        try FileManager.default.createDirectory(at: scriptDirectoryURL, withIntermediateDirectories: true)
        try "#!/usr/bin/env bash\n".write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        let bundleURL = sourceRootURL
            .appendingPathComponent("dist", isDirectory: true)
            .appendingPathComponent("AutocompleteLab.app", isDirectory: true)
        let resolvedURL = AppProofCommandPlan.sourceRootURL(
            environment: [:],
            bundleURL: bundleURL,
            currentDirectoryPath: tempRootURL.path
        )

        #expect(resolvedURL?.standardizedFileURL == sourceRootURL.standardizedFileURL)
    }
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
