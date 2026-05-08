import Testing
@testable import AutocompleteLabCore

@Suite("Runtime resource pressure policy")
struct RuntimeResourcePressurePolicyTests {
    @Test("Fair thermal and memory warning reduce work without unloading")
    func warningPressureReducesWork() {
        let policy = RuntimeResourcePressurePolicy()

        let thermal = policy.decision(for: .thermalFair)
        #expect(thermal.action == .reduceWork)
        #expect(thermal.reason == "thermal-fair")
        #expect(thermal.shouldSuspendSuggestions)
        #expect(!thermal.shouldUnloadRuntime)

        let memory = policy.decision(for: .memoryWarning)
        #expect(memory.action == .reduceWork)
        #expect(memory.reason == "memory-warning")
        #expect(memory.shouldSuspendSuggestions)
        #expect(!memory.shouldUnloadRuntime)
    }

    @Test("Serious thermal and critical memory unload the runtime")
    func criticalPressureUnloadsRuntime() {
        let policy = RuntimeResourcePressurePolicy()

        for event in [RuntimeResourcePressureEvent.thermalSerious, .thermalCritical, .memoryCritical] {
            let decision = policy.decision(for: event)

            #expect(decision.action == .unloadAndSuspend)
            #expect(decision.shouldSuspendSuggestions)
            #expect(decision.shouldUnloadRuntime)
        }
    }
}
