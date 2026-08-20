import Testing
@testable import AutocompleteLabApp

@Suite("Tilde setup state")
struct TildeSetupStateTests {
    @Test("Setup follows the next real system requirement")
    func progression() {
        #expect(resolve(install: nil) == .installingKeyboard)
        #expect(resolve(input: .missing) == .needsKeyboard)
        #expect(resolve(input: .available, permission: false) == .needsScreenRecording)
        #expect(resolve(input: .selected, runtime: .starting) == .preparing)
        #expect(resolve(input: .selected) == .ready)
    }

    @Test("Installation, runtime, and socket failures are recoverable")
    func failures() {
        #expect(resolve(install: .failed) == .recoverableError)
        #expect(resolve(install: .unavailableInDevelopment, input: .missing) == .recoverableError)
        #expect(resolve(input: .selected, runtime: .failed(.assetsMissing)) == .recoverableError)
        #expect(resolve(input: .selected, socket: false) == .recoverableError)
    }

    private func resolve(
        install: GhostKeyboardInstallerHost.KeyboardInstallResult? = .alreadyInstalled,
        input: GhostKeyboardInstallerHost.TildeInputSourceStatus = .selected,
        permission: Bool = true,
        runtime: LlamaRuntimeSnapshot = .ready,
        socket: Bool = true
    ) -> TildeSetupState {
        TildeSetupState.resolve(
            keyboardInstallResult: install,
            inputSourceStatus: input,
            screenRecordingGranted: permission,
            runtime: runtime,
            socketAvailable: socket
        )
    }
}
