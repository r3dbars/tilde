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
        state = appDelegate?.setupState() ?? .recoverableError
        let canSelectInputSource = state == .needsScreenRecording
            || state == .preparing
            || state == .ready
        if canSelectInputSource, !attemptedInputSourceSelection {
            attemptedInputSourceSelection = true
            showInputSourceFallback = appDelegate?.selectInputSourceIfAvailable() != true
            state = appDelegate?.setupState() ?? .recoverableError
        }
        if showInputSourceFallback, appDelegate?.inputSourceIsSelected() == true {
            showInputSourceFallback = false
        }
        if !previousPermissionGranted, permissionGranted, screenRecordingWasRequested {
            finishingSetup = true
            state = .preparing
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
        case .ready:
            appDelegate.completeSetup()
        case .recoverableError:
            appDelegate.retrySetup()
        case .installingKeyboard, .preparing:
            break
        }
    }
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

            Spacer(minLength: 22)

            Button(primaryTitle) { model.performPrimaryAction() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(model.state == .installingKeyboard || model.state == .preparing)
                .keyboardShortcut(.defaultAction)

            Label("Everything stays on this Mac.", systemImage: "lock.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 16)
                .padding(.bottom, 24)
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
        case .preparing: "Getting Tilde ready…"
        case .ready: "Tilde is ready"
        case .recoverableError: "Tilde needs a quick retry"
        }
    }

    private var explanation: String {
        if model.finishingSetup { return "Tilde will reopen automatically." }
        return switch model.state {
        case .installingKeyboard: "This only takes a moment."
        case .needsKeyboard: "macOS needs you to approve it once."
        case .needsScreenRecording:
            "macOS calls this Screen Recording. Tilde uses visible text to understand what you’re replying to. Nothing leaves this Mac."
        case .preparing: "The local model is starting."
        case .ready: "Start typing anywhere. Press Tab to accept a suggestion."
        case .recoverableError: "Tilde couldn’t finish setup. Try once more; if it still fails, reinstall the app."
        }
    }

    private var primaryTitle: String {
        switch model.state {
        case .installingKeyboard: "Installing…"
        case .needsKeyboard: "Open Keyboard Settings"
        case .needsScreenRecording:
            model.screenRecordingWasRequested ? "Open Privacy Settings" : "Allow Screen Access"
        case .preparing: model.finishingSetup ? "Reopening…" : "Starting…"
        case .ready: "Start Typing"
        case .recoverableError: "Try Again"
        }
    }
}
