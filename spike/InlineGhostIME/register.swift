// Registers the installed input method with the Text Input system — the official
// API (TISRegisterInputSource), which takes effect without logout — then enables it
// so it appears in the menu-bar input picker.
import Carbon
import Foundation

let path = NSString(string: "~/Library/Input Methods/InlineGhostIME.app").expandingTildeInPath
let url = URL(fileURLWithPath: path)

let registerStatus = TISRegisterInputSource(url as CFURL)
print("TISRegisterInputSource: \(registerStatus == noErr ? "OK" : "error \(registerStatus)")")

// Find it in the full list (including not-yet-enabled sources).
guard let list = TISCreateInputSourceList(nil, true)?.takeRetainedValue() as? [TISInputSource] else {
    print("could not list input sources"); exit(1)
}
var found: TISInputSource?
for source in list {
    if let ptr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) {
        let id = Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
        if id.lowercased().contains("ghost") { found = source; print("found: \(id)") }
    }
}
guard let source = found else {
    print("NOT REGISTERED ❌ — still not visible to Text Input Services"); exit(1)
}

let enableStatus = TISEnableInputSource(source)
print("TISEnableInputSource: \(enableStatus == noErr ? "OK ✅ — check the input menu in the menu bar" : "error \(enableStatus)")")
