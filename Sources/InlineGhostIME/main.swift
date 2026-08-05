import Cocoa
import InputMethodKit

// The connection name MUST match `InputMethodConnectionName` in Info.plist.
let connectionName = "InlineGhostIME_1_Connection"
let bundleIdentifier = Bundle.main.bundleIdentifier ?? "bar.r3d.inputmethod.InlineGhost"

// Usage capture stores raw writing context and may sync it through the owner's
// iCloud Drive. It is always off until the user explicitly enables the clearly
// labeled learning control in Tilde's menu.
//
// GhostFastLayerEnabled gates the instant dictionary/doc-vocabulary layer —
// the model-only A/B (usage data: fast 8% vs model 23% accept) flips it live:
//   defaults write bar.r3d.inputmethod.InlineGhost GhostFastLayerEnabled -bool false
UserDefaults.standard.register(defaults: [
    "GhostUsageCaptureEnabled": false,
    "GhostSoundsEnabled": true,
    "GhostFastLayerEnabled": true,
    "GhostPersonalWordsEnabled": true,
    "GhostPersonalPhrasesEnabled": false,
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
