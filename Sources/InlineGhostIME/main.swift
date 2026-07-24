import Cocoa
import InputMethodKit

// The connection name MUST match `InputMethodConnectionName` in Info.plist.
let connectionName = "InlineGhostIME_1_Connection"
let bundleIdentifier = Bundle.main.bundleIdentifier ?? "bar.r3d.inputmethod.InlineGhost"

// This is the owner's personal build: usage capture ON by default (records
// accept/dismiss/typed-instead, redacted, local only) so real-acceptance ground
// truth is collected. The user can disable it by setting the flag to false.
//
// GhostFastLayerEnabled gates the instant dictionary/doc-vocabulary layer —
// the model-only A/B (usage data: fast 8% vs model 23% accept) flips it live:
//   defaults write bar.r3d.inputmethod.InlineGhost GhostFastLayerEnabled -bool false
UserDefaults.standard.register(defaults: [
    "GhostUsageCaptureEnabled": true,
    "GhostFastLayerEnabled": true,
])

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
