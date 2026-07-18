import Foundation
import Testing
@testable import AutocompleteLabApp

@MainActor
struct AppLifecycleHostTests {
    @Test
    func startsAndStopsInDeterministicOrder() {
        let recorder = LifecycleRecorder()
        let activity = NSObject()
        let infrastructure = AppLifecycleInfrastructure(
            setAccessoryApplicationPolicy: {
                recorder.events.append("accessory")
            },
            disableAutomaticTermination: {
                recorder.events.append("disable-termination")
            },
            beginAutomaticTerminationActivity: {
                recorder.events.append("begin-activity")
                return activity
            },
            endAutomaticTerminationActivity: { endedActivity in
                #expect(endedActivity === activity)
                recorder.events.append("end-activity")
            },
            scheduleOnMain: { operation in
                recorder.events.append("schedule-residency-check")
                operation()
            }
        )
        let host = AppLifecycleHost(handler: recorder, infrastructure: infrastructure)

        host.start()
        host.stop()

        #expect(recorder.events == [
            "disable-termination",
            "begin-activity",
            "accessory",
            "prepare",
            "proof-observer",
            "status-menu",
            "launch-diagnostics",
            "accessibility",
            "warm-runtime",
            "hot-key",
            "settings",
            "workspace",
            "pipeline",
            "resource-diagnostics",
            "schedule-residency-check",
            "stop",
            "end-activity"
        ])
    }

    @Test
    func doesNotBeginASecondActivityWhenResidentCheckRunsAgain() {
        let recorder = LifecycleRecorder()
        let infrastructure = AppLifecycleInfrastructure(
            setAccessoryApplicationPolicy: {},
            disableAutomaticTermination: {},
            beginAutomaticTerminationActivity: {
                recorder.activityCount += 1
                return NSObject()
            },
            endAutomaticTerminationActivity: { _ in },
            scheduleOnMain: { _ in }
        )
        let host = AppLifecycleHost(handler: recorder, infrastructure: infrastructure)

        host.start()
        host.start()

        #expect(recorder.activityCount == 1)
    }
}

@MainActor
private final class LifecycleRecorder: AppLifecycleHandling {
    var events: [String] = []
    var activityCount = 0

    func prepareForLaunch() { events.append("prepare") }
    func startProofOnlyAcceptCommandObserver() { events.append("proof-observer") }
    func startStatusMenu() { events.append("status-menu") }
    func recordLaunchDiagnostics() { events.append("launch-diagnostics") }
    func requestAccessibilityPermissionIfNeeded() { events.append("accessibility") }
    func warmModelRuntime() { events.append("warm-runtime") }
    func startSuggestionSummonHotKey() { events.append("hot-key") }
    func showSettingsIfNeeded() { events.append("settings") }
    func startWorkspaceObserver() { events.append("workspace") }
    func startSuggestionPipeline() { events.append("pipeline") }
    func startResourceDiagnostics() { events.append("resource-diagnostics") }
    func stopForTermination() { events.append("stop") }
}
