import Foundation
import Testing
@testable import TildeApp

@Suite("Tilde setup state")
struct TildeSetupStateTests {
    @Test("Setup follows the next real system requirement")
    func progression() {
        #expect(resolve(install: nil) == .installingKeyboard)
        #expect(resolve(input: .missing) == .needsKeyboard)
        #expect(resolve(input: .available, permission: false) == .needsScreenRecording)
        #expect(resolve(input: .selected, model: .missing) == .downloadingModel(
            receivedBytes: 0,
            totalBytes: TildeSetupState.gemma4E2BApproximateBytes
        ))
        #expect(resolve(input: .selected, model: .downloading(
            receivedBytes: 640_000_000,
            totalBytes: 3_430_000_000
        )) == .downloadingModel(
            receivedBytes: 640_000_000,
            totalBytes: 3_430_000_000
        ))
        #expect(resolve(input: .selected, model: .verifying) == .verifyingModel)
        #expect(resolve(input: .selected, runtime: .starting) == .startingRuntime)
        #expect(resolve(input: .available) == .needsInputSourceSelection)
        #expect(resolve(input: .selected) == .ready)
    }

    @Test("Missing-model setup reports the selected model's exact size")
    func selectedModelSize() {
        #expect(resolve(
            input: .selected,
            model: .missing,
            selectedModelBytes: 5_629_109_312
        ) == .downloadingModel(
            receivedBytes: 0,
            totalBytes: 5_629_109_312
        ))
    }

    @Test("Installation, runtime, and socket failures are recoverable")
    func failures() {
        #expect(resolve(install: .failed) == .recoverableError(.keyboard))
        #expect(resolve(install: .unavailableInDevelopment, input: .missing) == .recoverableError(.keyboard))
        #expect(resolve(input: .selected, model: .failed(.checksumMismatch)) == .recoverableError(.model(.checksumMismatch)))
        #expect(resolve(input: .selected, runtime: .failed(.assetsMissing)) == .recoverableError(.runtime))
        #expect(resolve(input: .selected, socket: false) == .recoverableError(.runtime))
    }

    @Test("First-run setup waits for Tilde to be selected, but later checks can skip that gate")
    func inputSourceSelectionGate() {
        #expect(resolve(input: .available) == .needsInputSourceSelection)
        #expect(resolve(input: .available, requireInitialSelection: false) == .ready)
    }

    private func resolve(
        install: GhostKeyboardInstallerHost.KeyboardInstallResult? = .alreadyInstalled,
        input: GhostKeyboardInstallerHost.TildeInputSourceStatus = .selected,
        permission: Bool = true,
        runtime: LlamaRuntimeSnapshot = .ready,
        socket: Bool = true,
        model: ModelState = .ready(URL(fileURLWithPath: "/tmp/gemma-4-e2b.gguf")),
        requireInitialSelection: Bool = true,
        selectedModelBytes: Int64 = TildeSetupState.gemma4E2BApproximateBytes
    ) -> TildeSetupState {
        TildeSetupState.resolve(
            keyboardInstallResult: install,
            inputSourceStatus: input,
            screenRecordingGranted: permission,
            runtime: runtime,
            socketAvailable: socket,
            model: model,
            requireInitialInputSourceSelection: requireInitialSelection,
            selectedModelBytes: selectedModelBytes
        )
    }
}
