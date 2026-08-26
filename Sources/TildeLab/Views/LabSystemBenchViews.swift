import SwiftUI
import TildeLabKit

struct LabInteractionBenchView: View {
    @Bindable var store: LabWorkspaceStore
    @Environment(\.openWindow) private var openWindow

    private var arm: Binding<LabArmConfiguration> {
        Binding(get: { store.selectedArm }, set: { store.selectedArm = $0 })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                LabBenchHeader(
                    title: "Interaction",
                    subtitle: "Configure real marked-text, timing, cancellation, focus, acceptance, and host-compatibility trials.",
                    systemImage: LabBenchKind.interaction.systemImage
                )
                LabArmBar(store: store)
                foregroundNotice
                Button("Open Instrumented Scene Host", systemImage: "macwindow.on.rectangle") {
                    openWindow(id: "interaction-host")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                Text("Inside the host, Run Probe automatically exercises the native NSTextView path. A separate owner-triggered pass with Tilde selected remains the end-to-end IME acceptance proof.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                LabInteractionTimingEditor(arm: arm)
                LabInteractionEventEditor(arm: arm)
                LabSyntheticAuditCard(store: store, bench: .interaction)
                LabHardGateBanner()
            }
            .padding(24)
            .frame(maxWidth: 1_120, alignment: .leading)
        }
        .navigationTitle("Interaction")
    }

    private var foregroundNotice: some View {
        Label(
            "Real IMKit trials require a visible foreground host and may move focus. The manifest separates these trials from background Reply runs so Tilde Lab never claims a synthetic model call proved marked-text integrity.",
            systemImage: "macwindow.on.rectangle"
        )
        .font(.callout.weight(.medium))
        .foregroundStyle(.secondary)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct LabInteractionTimingEditor: View {
    @Binding var arm: LabArmConfiguration

    var body: some View {
        LabControlSection(
            "Activation and presentation",
            detail: "Inference begins immediately; reveal timing controls when a stable candidate becomes visible in each host family."
        ) {
            LabControlGrid {
                LabControlRow("Typed threshold") {
                    Stepper("\(arm.interaction.minimumTypedCharacters) characters", value: $arm.interaction.minimumTypedCharacters, in: 1...20)
                }
                LabControlRow("Typing boundary") {
                    LabEnumPicker(label: "Boundary", selection: $arm.interaction.boundary)
                }
                LabControlRow("Native reveal") {
                    HStack {
                        Stepper("mid-word \(arm.interaction.nativeMidWordRevealMilliseconds) ms", value: $arm.interaction.nativeMidWordRevealMilliseconds, in: 0...5_000)
                        Stepper("boundary \(arm.interaction.nativeBoundaryRevealMilliseconds) ms", value: $arm.interaction.nativeBoundaryRevealMilliseconds, in: 0...5_000)
                    }
                }
                LabControlRow("Chromium reveal") {
                    HStack {
                        Stepper("mid-word \(arm.interaction.chromiumMidWordRevealMilliseconds) ms", value: $arm.interaction.chromiumMidWordRevealMilliseconds, in: 0...5_000)
                        Stepper("boundary \(arm.interaction.chromiumBoundaryRevealMilliseconds) ms", value: $arm.interaction.chromiumBoundaryRevealMilliseconds, in: 0...5_000)
                    }
                }
                LabControlRow("Typing speed") {
                    LabValueSlider(value: $arm.interaction.typingCharactersPerSecond, range: 0.5...30, step: 0.5, fractionDigits: 1, suffix: " char/s")
                }
                LabControlRow("Pause before request") {
                    Stepper("\(arm.interaction.pauseBeforeInferenceMilliseconds) ms", value: $arm.interaction.pauseBeforeInferenceMilliseconds, in: 0...10_000)
                }
                LabControlRow("Document context") {
                    Stepper("\(arm.interaction.contextCharacterLimit.formatted()) characters", value: $arm.interaction.contextCharacterLimit, in: 80...24_000, step: 100)
                }
                LabControlRow("Trailing context") {
                    Stepper("\(arm.interaction.trailingContextCharacterLimit) characters", value: $arm.interaction.trailingContextCharacterLimit, in: 1...2_000)
                }
                LabControlRow("Socket timeout") {
                    Stepper("\(arm.interaction.socketTimeoutMilliseconds) ms", value: $arm.interaction.socketTimeoutMilliseconds, in: 1...60_000, step: 50)
                }
            }
        }
    }
}

private struct LabInteractionEventEditor: View {
    @Binding var arm: LabArmConfiguration

    var body: some View {
        LabControlSection(
            "Host and event matrix",
            detail: "Every enabled host is crossed with the selected mutation, dismissal, acceptance, and failure events."
        ) {
            Text("Hosts").font(.callout.weight(.semibold))
            LabToggleCloud(selection: $arm.interaction.hosts)
            Divider()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), alignment: .leading) {
                Toggle("Cancel stale request", isOn: $arm.interaction.testsCancellation)
                Toggle("Backspace during inference", isOn: $arm.interaction.testsBackspaceDuringInference)
                Toggle("Move cursor", isOn: $arm.interaction.testsCursorMovement)
                Toggle("Change selection", isOn: $arm.interaction.testsSelectionChanges)
                Toggle("Change focus", isOn: $arm.interaction.testsFocusChanges)
                Toggle("Tab acceptance", isOn: $arm.interaction.testsTabAcceptance)
                Toggle("Escape dismissal", isOn: $arm.interaction.testsEscapeDismissal)
                Toggle("Word acceptance", isOn: $arm.interaction.testsWordAcceptance)
                Toggle("Restart runtime", isOn: $arm.interaction.testsRuntimeRestart)
            }
            .toggleStyle(.checkbox)
        }
    }
}

struct LabPerformanceBenchView: View {
    @Bindable var store: LabWorkspaceStore

    private var runtime: Binding<LabRuntimeConfiguration> {
        Binding(get: { store.manifest.runtime }, set: { store.manifest.runtime = $0 })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                LabBenchHeader(
                    title: "Performance",
                    subtitle: "Measure capacity, cold/warm startup, cache behavior, batching, Metal/KV choices, and tail latency.",
                    systemImage: LabBenchKind.performance.systemImage
                )
                LabArmBar(store: store)
                LabCapacityEditor(runtime: runtime, store: store)
                LabRuntimeEditor(runtime: runtime, store: store)
                LabAdvancedRuntimeEditor(runtime: runtime)
                LabSyntheticAuditCard(store: store, bench: .performance)
                LabRunActionCard(store: store)
            }
            .padding(24)
            .frame(maxWidth: 1_120, alignment: .leading)
        }
        .navigationTitle("Performance")
    }
}

private struct LabCapacityEditor: View {
    @Binding var runtime: LabRuntimeConfiguration
    @Bindable var store: LabWorkspaceStore

    var body: some View {
        LabControlSection(
            "Parallel capacity",
            detail: "Workers are isolated model processes. Slots share one loaded model through llama.cpp continuous batching. Increase slots before multiplying full model-weight copies."
        ) {
            LabControlGrid {
                LabControlRow("Workers") {
                    Stepper("\(runtime.workerCount)", value: $runtime.workerCount, in: 1...60)
                }
                LabControlRow("Slots per worker") {
                    Stepper("\(runtime.slotsPerWorker)", value: $runtime.slotsPerWorker, in: 1...16)
                }
                LabControlRow("Repetitions") {
                    Stepper("\(runtime.repetitions.formatted())", value: $runtime.repetitions, in: 1...1_000)
                }
                LabControlRow("Effective concurrency") {
                    Text("\(store.effectiveConcurrency) requests")
                        .monospacedDigit()
                }
                LabControlRow("Independent weights") {
                    Text("up to \(store.independentModelFootprint)")
                        .monospacedDigit()
                }
            }
            if let warning = store.pressureWarning {
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }
        }
    }
}

private struct LabRuntimeEditor: View {
    @Binding var runtime: LabRuntimeConfiguration
    @Bindable var store: LabWorkspaceStore

    var body: some View {
        LabControlSection(
            "Local runtime",
            detail: "Production mode verifies the immutable E2B byte count and SHA-256. Experimental mode is Lab-only and records the selected GGUF identity and exact hash in every report."
        ) {
            LabControlGrid {
                LabControlRow("llama-server") {
                    TextField("Executable path", text: $store.serverPath)
                        .textFieldStyle(.roundedBorder)
                }
                LabControlRow("Model mode") {
                    LabEnumPicker(label: "Model mode", selection: $store.modelVerificationMode)
                }
                LabControlRow("Local GGUF") {
                    HStack {
                        TextField("Model path", text: $store.modelPath)
                            .textFieldStyle(.roundedBorder)
                        if store.modelVerificationMode == .experimentalLocal {
                            Button("Choose…") { store.chooseExperimentalModel() }
                        }
                    }
                }
                if store.modelVerificationMode == .experimentalLocal {
                    LabControlRow("Model identity") {
                        HStack {
                            TextField("organization/model", text: $store.experimentalModelIdentifier)
                                .textFieldStyle(.roundedBorder)
                            TextField("revision", text: $store.experimentalModelRevision)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 180)
                        }
                    }
                }
                LabControlRow("Context per slot") {
                    Stepper("\(runtime.contextSizePerSlot.formatted()) tokens", value: $runtime.contextSizePerSlot, in: 1_024...32_768, step: 1_024)
                }
                LabControlRow("Prompt cache reuse") {
                    Stepper("\(runtime.cacheReuseTokens) tokens", value: $runtime.cacheReuseTokens, in: 0...4_096, step: 64)
                }
                LabControlRow("Request timeout") {
                    Stepper("\(Int(runtime.timeoutSeconds)) seconds", value: $runtime.timeoutSeconds, in: 1...120, step: 1)
                }
                LabControlRow("Work-order seed") {
                    TextField("Seed", value: $runtime.seed, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 220)
                }
                LabControlRow("Server behavior") {
                    HStack(spacing: 18) {
                        Toggle("Continuous batching", isOn: $runtime.continuousBatching)
                        Toggle("Warmup", isOn: $runtime.warmup)
                        Toggle("Prompt caching", isOn: $runtime.promptCaching)
                        Toggle("Full SWA", isOn: $runtime.fullSWA)
                    }
                    .toggleStyle(.checkbox)
                }
            }
        }
    }
}

private struct LabAdvancedRuntimeEditor: View {
    @Binding var runtime: LabRuntimeConfiguration

    var body: some View {
        LabControlSection(
            "Advanced llama runtime",
            detail: "These controls affect speed and memory, not writing quality. Every value is persisted in the run manifest."
        ) {
            LabControlGrid {
                LabControlRow("Generation threads") {
                    Stepper("\(runtime.generationThreads)", value: $runtime.generationThreads, in: -1...256)
                }
                LabControlRow("Batch threads") {
                    Stepper("\(runtime.batchThreads)", value: $runtime.batchThreads, in: -1...256)
                }
                LabControlRow("HTTP threads") {
                    Stepper("\(runtime.HTTPThreads)", value: $runtime.HTTPThreads, in: -1...256)
                }
                LabControlRow("Batch size") {
                    Stepper("\(runtime.batchSize)", value: $runtime.batchSize, in: 32...8_192, step: 32)
                }
                LabControlRow("Micro-batch size") {
                    Stepper("\(runtime.microBatchSize)", value: $runtime.microBatchSize, in: 32...8_192, step: 32)
                }
                LabControlRow("Flash Attention") {
                    LabEnumPicker(label: "Flash Attention", selection: $runtime.flashAttention)
                }
                LabControlRow("KV cache types") {
                    HStack {
                        Text("K")
                        LabEnumPicker(label: "K cache", selection: $runtime.keyCacheType)
                        Text("V")
                        LabEnumPicker(label: "V cache", selection: $runtime.valueCacheType)
                    }
                }
                LabControlRow("KV offload") {
                    Toggle("Offload KV cache", isOn: $runtime.KVOffload)
                        .toggleStyle(.checkbox)
                }
                LabControlRow("GPU layers") {
                    TextField("auto, all, none, or count", text: $runtime.GPUlayers)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 260)
                }
                LabControlRow("Load mode") {
                    LabEnumPicker(label: "Load mode", selection: $runtime.loadMode)
                }
                LabControlRow("Slot similarity") {
                    LabValueSlider(value: $runtime.slotPromptSimilarity, range: 0...1, step: 0.01)
                }
            }
        }
    }
}
