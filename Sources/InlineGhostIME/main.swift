import Cocoa
import InputMethodKit

// The connection name MUST match `InputMethodConnectionName` in Info.plist.
let connectionName = "InlineGhostIME_1_Connection"
let bundleIdentifier = Bundle.main.bundleIdentifier ?? "bar.r3d.inputmethod.InlineGhost"

// Retain the server for the process lifetime; IMK dispatches client sessions to it.
let server = IMKServer(name: connectionName, bundleIdentifier: bundleIdentifier)
_ = server

NSApplication.shared.run()
