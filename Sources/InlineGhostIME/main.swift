import Cocoa
import InputMethodKit

// The connection name MUST match `InputMethodConnectionName` in Info.plist.
let connectionName = "InlineGhostIME_1_Connection"
let bundleIdentifier = Bundle.main.bundleIdentifier ?? "bar.r3d.inputmethod.InlineGhost"

// Retain the server for the process lifetime; IMK dispatches client sessions to it.
let server = IMKServer(name: connectionName, bundleIdentifier: bundleIdentifier)
_ = server

// System candidate panel (the UI Japanese/Chinese keyboards use) — powers the
// optional "panel" display mode where the user's text stays completely clean.
enum GhostPanel {
    static var candidates: IMKCandidates?
}
GhostPanel.candidates = IMKCandidates(
    server: server,
    panelType: kIMKSingleRowSteppingCandidatePanel
)

NSApplication.shared.run()
