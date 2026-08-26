import AppKit
import SwiftUI
import TildeLabKit

@main
struct TildeLabApp: App {
    @NSApplicationDelegateAdaptor(LabAppDelegate.self) private var appDelegate
    @State private var store = LabWorkspaceStore()

    var body: some Scene {
        WindowGroup("Tilde Lab", id: "main") {
            LabContentView(store: store)
                .frame(minWidth: 1_080, minHeight: 700)
        }
        .defaultSize(width: 1_280, height: 820)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Run Experiment") { store.startRun() }
                    .keyboardShortcut("r", modifiers: [.command])
                    .disabled(!store.canStart)
                Button("Cancel Experiment") { store.cancelRun() }
                    .keyboardShortcut(".", modifiers: [.command])
                    .disabled(!store.isRunning)
            }
        }

        Window("Interaction Scene Host", id: "interaction-host") {
            LabInteractionHostView()
        }
        .defaultSize(width: 1_000, height: 720)
    }
}

final class LabAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        LabChildProcessRegistry.shared.terminateAll()
    }
}
