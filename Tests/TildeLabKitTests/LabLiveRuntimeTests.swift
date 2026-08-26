import Foundation
import Testing
@testable import TildeLabKit

@Suite("Tilde Lab live runtime")
struct LabLiveRuntimeTests {
    @Test("One pinned local worker completes an aggregate-only reply run")
    func pinnedWorker() async throws {
        guard ProcessInfo.processInfo.environment["TILDE_LAB_LIVE"] == "1" else { return }
        let helper = URL(fileURLWithPath: "/Applications/Tilde.app/Contents/Helpers/llama-server")
        let model = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Tilde/Models")
            .appendingPathComponent("gemma-4-e2b-q4km/model.gguf")
        guard FileManager.default.isExecutableFile(atPath: helper.path),
              FileManager.default.fileExists(atPath: model.path) else { return }

        let scenario = LabScenario(
            id: "reply.live.confirm",
            category: "reply.confirm",
            appBundleIdentifier: "com.apple.MobileSMS",
            typedContext: "Yes, ",
            scene: LabScene(
                mode: .replying,
                turns: [
                    LabSceneTurn(
                        speaker: .other,
                        text: "Does Thursday at three work for the synthetic review?"
                    )
                ]
            ),
            expectation: LabExpectation(
                shouldSuggest: true,
                goldenContinuation: "Thursday at three works for me.",
                acceptablePrefixes: ["Thursday at three", "that works"]
            )
        )
        let runner = LabExperimentRunner()
        let completedReports = CompletedReportIDs()
        let report = try await runner.run(
            suite: LabScenarioSuite(name: "Live smoke", scenarios: [scenario]),
            arm: LabArmConfiguration(id: "live-smoke"),
            execution: LabExecutionConfiguration(
                serverExecutable: helper,
                modelFile: model,
                workerCount: 1,
                slotsPerWorker: 1,
                repetitions: 1,
                timeoutSeconds: 30
            ),
            reportCompleted: { report in await completedReports.append(report.id) }
        )

        #expect(report.metrics.totalCases == 1)
        #expect(report.metrics.errors == 0)
        #expect(report.metrics.timeouts == 0)
        #expect(report.assets.modelSHA256.count == 64)
        #expect(report.assets.helperSHA256.count == 64)
        #expect(report.privacy.rawModelOutput == false)
        #expect(await completedReports.values == [report.id])
    }
}

private actor CompletedReportIDs {
    private(set) var values: [UUID] = []

    func append(_ id: UUID) { values.append(id) }
}
