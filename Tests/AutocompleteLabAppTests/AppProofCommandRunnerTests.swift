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
        #expect(plan.executableURL.path == "/usr/bin/env")
        #expect(plan.arguments == ["bash", "script/real_app_smoke.sh", "textedit", "--skip-build"])
        #expect(plan.environmentOverrides["AUTOCOMPLETE_LAB_SCREENSHOT_TRACE"] == "1")
        #expect(plan.environmentOverrides["AUTOCOMPLETE_LAB_REAL_APP_SKIP_BUILD"] == "1")
        #expect(plan.logURL.lastPathComponent == "app-proof-textedit.log")
        #expect(plan.commandText.contains("script/real_app_smoke.sh textedit --skip-build"))
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
