import AppKit
import SwiftUI

@MainActor
final class TildeSetupWindowController: NSWindowController, NSWindowDelegate {
    private let model: TildeSetupViewModel

    init(appDelegate: AppDelegate) {
        model = TildeSetupViewModel(appDelegate: appDelegate)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 430),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Set Up Tilde"
        window.contentViewController = NSHostingController(rootView: TildeSetupView(model: model))
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    func show() {
        model.start()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func refresh() { model.refresh() }

    func windowWillClose(_ notification: Notification) { model.stop() }
}

@MainActor
private final class TildeSetupViewModel: ObservableObject {
    @Published private(set) var state: TildeSetupState = .installingKeyboard
    @Published private(set) var modelState: ModelState = .checking
    @Published private(set) var finishingSetup = false
    @Published private(set) var showInputSourceFallback = false

    private weak var appDelegate: AppDelegate?
    private var timer: Timer?
    private var previousPermissionGranted: Bool
    private var attemptedInputSourceSelection = false

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        previousPermissionGranted = ScreenRecordingPermission.isGranted()
        refresh()
    }

    var screenRecordingWasRequested: Bool { TildeSettings().screenRecordingRequested }

    var modelDescription: String {
        appDelegate?.modelDescription() ?? "Gemma 4 E2B · about 3.43 GB"
    }

    var isBusy: Bool {
        switch state {
        case .installingKeyboard, .downloadingModel, .verifyingModel, .startingRuntime:
            return true
        case .needsKeyboard, .needsScreenRecording, .needsInputSourceSelection, .ready,
             .recoverableError:
            return false
        }
    }

    var modelProgress: TildeModelProgress? {
        switch modelState {
        case .checking, .missing:
            return TildeModelProgress(
                title: "Preparing download",
                detail: "3.43 GB · one time only",
                fraction: nil
            )
        case let .downloading(receivedBytes, totalBytes):
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useMB, .useGB]
            formatter.countStyle = .file
            let received = formatter.string(fromByteCount: max(0, receivedBytes))
            let total = formatter.string(fromByteCount: max(0, totalBytes))
            let fraction = totalBytes > 0
                ? min(1, max(0, Double(receivedBytes) / Double(totalBytes)))
                : nil
            return TildeModelProgress(
                title: "Downloading model",
                detail: "\(received) of \(total)",
                fraction: fraction
            )
        case .verifying:
            return TildeModelProgress(
                title: "Checking model",
                detail: "Almost done",
                fraction: nil
            )
        case .ready, .failed:
            return nil
        }
    }

    func start() {
        refresh()
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        guard !finishingSetup else { return }
        let permissionGranted = ScreenRecordingPermission.isGranted()
        modelState = appDelegate?.modelState() ?? .missing
        state = appDelegate?.setupState() ?? .recoverableError(.runtime(nil))
        let canSelectInputSource = state == .needsInputSourceSelection
        if canSelectInputSource, !attemptedInputSourceSelection {
            attemptedInputSourceSelection = true
            showInputSourceFallback = appDelegate?.selectInputSourceIfAvailable() != true
            state = appDelegate?.setupState() ?? .recoverableError(.runtime(nil))
        }
        if state != .needsInputSourceSelection {
            showInputSourceFallback = false
        }
        if showInputSourceFallback, appDelegate?.inputSourceIsSelected() == true {
            showInputSourceFallback = false
        }
        if !previousPermissionGranted, permissionGranted, screenRecordingWasRequested {
            finishingSetup = true
            state = .startingRuntime
            stop()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                guard let self else { return }
                if self.appDelegate?.relaunchAfterScreenRecordingGrant() != true {
                    self.finishingSetup = false
                    self.refresh()
                    self.start()
                }
            }
        }
        previousPermissionGranted = permissionGranted
    }

    func performPrimaryAction() {
        guard let appDelegate else { return }
        switch state {
        case .needsKeyboard:
            appDelegate.openKeyboardSettings()
        case .needsScreenRecording:
            if screenRecordingWasRequested {
                appDelegate.openScreenRecordingSettings()
            } else {
                appDelegate.requestScreenRecordingAccess()
                refresh()
            }
        case .needsInputSourceSelection:
            attemptedInputSourceSelection = true
            showInputSourceFallback = !appDelegate.selectInputSourceIfAvailable()
            refresh()
        case .ready:
            appDelegate.completeSetup()
        case let .recoverableError(target):
            if case let .keyboard(failure) = target, !(failure?.isRetryable ?? true) {
                // A retry cannot fix a signing problem; send people to the
                // manual path and re-check in case they added the keyboard.
                appDelegate.openKeyboardSettings()
            }
            appDelegate.retrySetup()
            refresh()
        case .installingKeyboard, .downloadingModel, .verifyingModel, .startingRuntime:
            break
        }
    }
}

private struct TildeModelProgress {
    let title: String
    let detail: String
    let fraction: Double?
}

private struct TildeSetupView: View {
    @ObservedObject var model: TildeSetupViewModel

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .accessibilityHidden(true)
                Text("Tilde finishes what you’re typing.")
                    .font(.title2.weight(.semibold))
                Text("Private, local autocomplete across your Mac.")
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 30)

            Spacer(minLength: 24)

            if model.modelProgress == nil {
                VStack(spacing: 12) {
                    Text(headline)
                        .font(.headline)
                    Text(explanation)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 390)
                    if model.state == .needsKeyboard {
                        Text("Text Input → Edit → + → search “Tilde” → Add")
                            .font(.callout.monospaced())
                            .foregroundStyle(.secondary)
                    } else if model.showInputSourceFallback {
                        Text("Choose Tilde from the keyboard menu.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 22)

            if !model.isBusy {
                Button(primaryTitle) { model.performPrimaryAction() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
            }

            if let progress = model.modelProgress {
                VStack(spacing: 5) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle")
                            .foregroundStyle(.secondary)
                        Text(progress.title)
                            .font(.headline)
                        Spacer()
                    }
                    if let fraction = progress.fraction {
                        ProgressView(value: fraction)
                            .progressViewStyle(.linear)
                    } else {
                        ProgressView()
                            .progressViewStyle(.linear)
                    }
                    Text(progress.detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: 390)
                .padding(.top, 12)
            }

            Label(
                "Everything stays on this Mac.",
                systemImage: "lock.fill"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .padding(.horizontal, 24)
        .frame(width: 500, height: 430)
    }

    private var headline: String {
        if model.finishingSetup { return "Finishing setup…" }
        return switch model.state {
        case .installingKeyboard: "Installing Tilde…"
        case .needsKeyboard: "Add the Tilde keyboard"
        case .needsScreenRecording: "Allow screen access"
        case .downloadingModel: "Downloading model…"
        case .verifyingModel: "Checking model…"
        case .startingRuntime: "Starting Tilde…"
        case .needsInputSourceSelection: "Select Tilde as your keyboard"
        case .ready: "Tilde is ready"
        case let .recoverableError(target): recoveryHeadline(for: target)
        }
    }

    private var explanation: String {
        if model.finishingSetup { return "Tilde will reopen automatically." }
        return switch model.state {
        case .installingKeyboard: "This only takes a moment."
        case .needsKeyboard: "macOS needs you to approve it once."
        case .needsScreenRecording:
            "macOS calls this Screen Recording. Tilde uses visible text to understand what you’re replying to. Your screen and writing never leave this Mac."
        case .downloadingModel: "One-time download."
        case .verifyingModel: "Making sure the download is ready."
        case .startingRuntime: "Almost done."
        case .needsInputSourceSelection:
            model.showInputSourceFallback
                ? "Choose Tilde from the keyboard menu, then return here."
                : "Tilde needs to be selected once before setup is complete."
        case .ready: "Start typing anywhere. Press Tab to accept a suggestion."
        case let .recoverableError(target): recoveryExplanation(for: target)
        }
    }

    private var primaryTitle: String {
        switch model.state {
        case .installingKeyboard: "Installing…"
        case .needsKeyboard: "Open Keyboard Settings"
        case .needsScreenRecording:
            model.screenRecordingWasRequested ? "Open Privacy Settings" : "Allow Screen Access"
        case .downloadingModel: "Downloading…"
        case .verifyingModel: "Checking…"
        case .startingRuntime: model.finishingSetup ? "Reopening…" : "Starting…"
        case .needsInputSourceSelection: "Select Tilde"
        case .ready: "Start Typing"
        case let .recoverableError(target): recoveryButtonTitle(for: target)
        }
    }

    private func recoveryHeadline(for target: TildeSetupRepairTarget) -> String {
        switch target {
        case let .keyboard(failure) where failure?.isRetryable == false:
            return "This build can’t install its keyboard"
        case .runtime(.assetsMissing):
            return "This build has no local engine"
        default:
            return "Tilde needs a quick retry"
        }
    }

    private func recoveryButtonTitle(for target: TildeSetupRepairTarget) -> String {
        switch target {
        case let .keyboard(failure) where failure?.isRetryable == false:
            return "Open Keyboard Settings"
        case .runtime(.assetsMissing):
            return "Check Again"
        default:
            return "Try Again"
        }
    }

    private func recoveryExplanation(for target: TildeSetupRepairTarget) -> String {
        switch target {
        case .keyboard(nil):
            return "This Tilde build doesn’t include its keyboard. Rebuild with script/build_and_run.sh, or open Keyboard Settings and add an installed Tilde keyboard."
        case .keyboard(.appNotTeamSigned):
            return "Tilde isn’t signed with an Apple Development certificate, so macOS won’t trust its keyboard. Retrying can’t help: rebuild with a signing identity, or add the keyboard manually in Keyboard Settings."
        case .keyboard(.bundledKeyboardUntrusted):
            return "The keyboard inside this Tilde build isn’t signed by the same team as Tilde. Rebuild both with the same signing identity."
        case .keyboard(.copyFailed):
            return "Tilde couldn’t copy its keyboard into ~/Library/Input Methods. Check disk space and folder permissions, then try again."
        case .keyboard(.registrationRefused):
            return "macOS didn’t register the Tilde keyboard. Try again; if it still fails, open Keyboard Settings and add Tilde."
        case .runtime(.assetsMissing):
            return "Tilde’s llama-server engine isn’t inside this app bundle, so retrying can’t help. Rebuild with script/build_and_run.sh --llama-server PATH, or reinstall a release build."
        case .runtime(.portInUse):
            return "Another program is using Tilde’s local port. Quit it or wait a moment, then try again."
        case .runtime:
            return "Tilde couldn’t start its local engine. Try again; your downloaded model will be checked before it runs."
        case let .model(failure):
            return modelFailureExplanation(failure)
        }
    }

    private func modelFailureExplanation(_ failure: ModelFailure) -> String {
        switch failure {
        case .offline:
            return "Tilde couldn’t reach the model host. Check your connection and try again."
        case .insufficientDiskSpace:
            return "Tilde needs about 3.43 GB of free space for Gemma 4 E2B. Free space, then try again."
        case .serverRejectedRequest:
            return "The model host rejected the download. Try again in a moment."
        case .checksumMismatch:
            return "The downloaded model failed its integrity check. Tilde will download it again."
        case .invalidModel:
            return "The downloaded model was not valid. Tilde will download it again."
        case .installationFailed:
            return "Tilde could not install the model. Check available disk space and try again."
        }
    }
}
